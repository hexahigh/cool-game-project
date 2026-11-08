extends Node

## Runs the band-delivery loop: roster, placement, countdown, collection
## success/failure, focus playback and the muffled stage background.

const CHARACTER_SCENE := preload("res://scenes/band_member.tscn")

const BANDS := [
	{
		"id": "no_messing",
		"name": "No Messing",
		"genre": "Brass",
		"stems": [
			{"instrument": "Drums", "paths": ["res://songs/no-messing/mono/drums.mp3"]},
			{"instrument": "Bass", "paths": ["res://songs/no-messing/mono/bass.mp3"]},
			{"instrument": "Guitar", "paths": ["res://songs/no-messing/mono/guitar.mp3"]},
			{"instrument": "Piano", "paths": ["res://songs/no-messing/mono/piano.mp3"]},
			{"instrument": "Organ & Horns", "paths": ["res://songs/no-messing/mono/organ.mp3", "res://songs/no-messing/mono/horns.mp3"]},
		],
	},
	{
		"id": "tangy_tangerine",
		"name": "Tangy Tangerine",
		"genre": "Country",
		"stems": [
			{"instrument": "Drums", "paths": ["res://songs/tangy-tangerine/mono/kick.mp3", "res://songs/tangy-tangerine/mono/snare.mp3"]},
			{"instrument": "Guitars", "paths": ["res://songs/tangy-tangerine/mono/lead_guitar.mp3", "res://songs/tangy-tangerine/mono/rhythm_guitar.mp3"]},
			{"instrument": "Bass", "paths": ["res://songs/tangy-tangerine/mono/bass_guitar.mp3"]},
			{"instrument": "Mandolin", "paths": ["res://songs/tangy-tangerine/mono/mandolin.mp3"]},
		],
	},
	{
		"id": "avenged_apples",
		"name": "Avenged Apples",
		"genre": "Hard Punk Rock",
		"stems": [
			{"instrument": "Drums", "paths": ["res://songs/goblings/mono/drum.ogg", "res://songs/goblings/mono/rack.ogg"]},
			{"instrument": "Bass", "paths": ["res://songs/goblings/mono/guitar_bass.ogg"]},
			{"instrument": "Guitar", "paths": ["res://songs/goblings/mono/guitar_1.ogg", "res://songs/goblings/mono/guitar_2.ogg"]},
			{"instrument": "Vocals", "paths": ["res://songs/goblings/mono/vocal_kor.ogg", "res://songs/goblings/mono/vocal_edvin.ogg", "res://songs/goblings/mono/vocal_will.ogg", "res://songs/goblings/mono/keys.ogg"]},
		],
	},
	{
		"id": "ballsy_bananas",
		"name": "Ballsy Bananas",
		"genre": "Classical",
		"stems": [
			{"instrument": "Bass", "paths": ["res://songs/enlightenment/mono/bass.ogg"]},
			{"instrument": "Melody", "paths": ["res://songs/enlightenment/mono/melody.ogg"]},
			{"instrument": "Instruments", "paths": ["res://songs/enlightenment/mono/instruments.ogg"]},
		],
	},
	{
		"id": "orangji_jusu",
		"name": "Oranji Jyuusu",
		"genre": "J-rock",
		"stems": [
			{"instrument": "Drums", "paths": ["res://songs/samurai-punk/mono/drums.ogg"]},
			{"instrument": "Bass", "paths": ["res://songs/samurai-punk/mono/bass.ogg"]},
			{"instrument": "Melody", "paths": ["res://songs/samurai-punk/mono/melody.ogg"]},
			{"instrument": "Instruments", "paths": ["res://songs/samurai-punk/mono/instruments.ogg"]},
		]
	}
]

const BODY_PATHS := [
	"res://assets/sprites/bodies/fotball.png",
	"res://assets/sprites/bodies/green_pepper.png",
	"res://assets/sprites/bodies/lemon.png",
	"res://assets/sprites/bodies/red_pepper.png",
	"res://assets/sprites/bodies/yellow_pepper.png",
	"res://assets/sprites/bodies/apricot.png",
	"res://assets/sprites/bodies/carrot.png",
]
const ACCESSORY_PATHS := [
	"res://assets/sprites/accessories/top_hat.png",
	"res://assets/sprites/accessories/bow.png",
	"res://assets/sprites/accessories/candle.png",
	"res://assets/sprites/accessories/sunshine_and_rainbows.png",
]
const EYE_PATHS := [
	"res://assets/sprites/eyes/default_eyes.png",
]
const FEET_PATHS := [
	"res://assets/sprites/feet/blue_foot.png",
	"res://assets/sprites/feet/brown_foot.png",
	"res://assets/sprites/feet/green_foot.png",
	"res://assets/sprites/feet/pink_foot.png",
	"res://assets/sprites/feet/yellow_foot.png",
]

enum State {INTRO, PLAYING, FOCUS, TRANSITION, GAME_OVER, VICTORY}

@export var round_seconds: float = 300.0
@export var focus_seconds: float = 4.0
@export var walk_seconds: float = 1.6
## How long the stage volume drop and low-pass sweep take while a band walks on.
@export var stage_audio_fade_seconds: float = 1.6
## Menu music fades out and the band mix fades in over this long at game start.
@export var band_fade_in_seconds: float = 2.0
@export var min_character_distance: float = 130.0
@export var isolate_radius: float = 45.0
@export var duck_gain: float = 0.22

## Low-pass cutoff when a band is fully part of the muffled stage background.
const MUFFLE_CLOSED_HZ := 900.0
## Cutoff that leaves a band's stage bus effectively unfiltered while it plays
## in the room.
const MUFFLE_OPEN_HZ := 20500.0
const MUFFLE_BUS_PREFIX := "Muffled_"
const ISOLATION_BUS_PREFIX := "Isolated_"

var state: int = State.INTRO

var _characters: Array = []
var _band_order: Array = []
var _round_index := 0
var _active_band: Dictionary = {}
var _last_shown_second := -1
var _stage_band_members: Array = []
var _stage_row := 0
var _band_fade := 1.0
var _band_fading := false

var _player: Node2D
var _area: Node
var _hud: Node
var _stage: Node
var _characters_root: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	var menu_preview := get_parent().has_meta("menu_preview")

	_player = get_tree().get_first_node_in_group("player")
	_area = get_parent().get_node("CollectionArea")
	_hud = get_parent().get_node("HUD")
	_stage = get_parent().get_node("Stage")
	_characters_root = get_parent().get_node("Characters")

	_ensure_muffle_buses()
	AudioManager.play_menu_music()
	_hud.start_pressed.connect(_on_start)
	_hud.restart_pressed.connect(_on_restart)
	_area.band_complete.connect(_on_band_complete)

	_build_roster()

	if menu_preview:
		_enter_menu_preview()
		return

	_hud.show_intro()
	get_tree().paused = true


## Keep the world idle and silent behind the main menu / credits screen.
func _enter_menu_preview() -> void:
	_hud.visible = false

	var ui := get_parent().get_node_or_null("UI")
	if ui != null:
		ui.visible = false
		ui.process_mode = Node.PROCESS_MODE_DISABLED

	if _player != null:
		_player.set_physics_process(false)


func _process(delta: float) -> void:
	_update_band_fade_in(delta)

	if state != State.PLAYING:
		return

	_update_isolation()
	Global.time_left -= delta
	var shown := maxi(int(ceil(Global.time_left)), 0)
	if shown != _last_shown_second:
		_last_shown_second = shown
		_hud.set_timer(float(shown))

	if Global.time_left <= 0.0:
		_game_over()


func _update_band_fade_in(delta: float) -> void:
	if not _band_fading:
		return

	_band_fade = minf(_band_fade + delta / maxf(band_fade_in_seconds, 0.01), 1.0)
	for character in _characters:
		character.set_start_fade(_band_fade)

	if _band_fade >= 1.0:
		_band_fading = false


## Keep the character nearest the player audible while every other
## character ducks, so a single stem can be isolated by walking up to it.
func _update_isolation() -> void:
	if _player == null:
		return

	var nearest = null
	var nearest_distance := isolate_radius
	for character in _characters:
		if not character.is_isolatable():
			continue
		var distance: float = character.global_position.distance_to(_player.global_position)
		if distance <= nearest_distance:
			nearest = character
			nearest_distance = distance

	for character in _characters:
		if nearest == null:
			character.set_isolation_gain(1.0)
		else:
			character.set_isolation_gain(1.0 if character == nearest else duck_gain)


func _ensure_muffle_buses() -> void:
	# One bus per band lets a band fade into the stage treatment while the
	# previous band is still sitting there fully muffled.
	for band in BANDS:
		var stage_bus := _muffle_bus_name(band.id)
		_ensure_low_pass_bus(stage_bus, "Master", MUFFLE_OPEN_HZ, 0.6)

		# Each member then gets its own bus feeding the band bus, so the
		# isolation filter can duck individual stems independently.
		for stem in band.stems:
			_ensure_low_pass_bus(
				_isolation_bus_name(band.id, stem.instrument),
				stage_bus,
				MUFFLE_OPEN_HZ,
				0.5
			)


func _ensure_low_pass_bus(bus_name: String, send: String, cutoff_hz: float, resonance: float) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		# Scene reloads keep the AudioServer: reopen a bus left filtered by a
		# previous run.
		var existing := AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
		if existing == null:
			existing = AudioEffectLowPassFilter.new()
			existing.resonance = resonance
			AudioServer.add_bus_effect(index, existing)
		existing.cutoff_hz = cutoff_hz
		return index

	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)

	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = cutoff_hz
	filter.resonance = resonance
	AudioServer.add_bus_effect(index, filter)
	return index


func _muffle_bus_name(band_id: String) -> String:
	return MUFFLE_BUS_PREFIX + band_id


func _isolation_bus_name(band_id: String, instrument: String) -> String:
	return "%s%s_%s" % [ISOLATION_BUS_PREFIX, band_id, instrument.to_lower()]


func _fade_band_onto_stage(band_id: String, duration: float) -> void:
	var index := AudioServer.get_bus_index(_muffle_bus_name(band_id))
	if index == -1:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_muffle.bind(index), 0.0, 1.0, maxf(duration, 0.01))


func _apply_muffle(amount: float, index: int) -> void:
	_set_muffle_amount(index, amount)


## `amount` 0 keeps the bus open, 1 applies the full stage low-pass.
func _set_muffle_amount(index: int, amount: float) -> void:
	if AudioServer.get_bus_effect_count(index) == 0:
		return
	var filter := AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
	if filter != null:
		filter.cutoff_hz = MUFFLE_OPEN_HZ * pow(MUFFLE_CLOSED_HZ / MUFFLE_OPEN_HZ, amount)


func _build_roster() -> void:
	_band_order = BANDS.duplicate(true)
	_band_order.shuffle()

	var slots: Array = []
	for band in BANDS:
		for stem in band.stems:
			slots.append({
				"band_id": band.id,
				"band_name": band.name,
				"instrument": stem.instrument,
				"stem_paths": stem.paths,
			})

	var combos := _build_look_combos()
	combos.shuffle()
	if combos.size() < slots.size():
		push_warning("Not enough unique looks (%d) for %d characters." % [combos.size(), slots.size()])

	for i in slots.size():
		var slot: Dictionary = slots[i]
		var combo: Dictionary = combos[i % combos.size()]
		var eyes: Texture2D = load(EYE_PATHS[randi() % EYE_PATHS.size()])
		var feet: Texture2D = load(FEET_PATHS[randi() % FEET_PATHS.size()])
		var hands: Texture2D = load((feet.resource_path.replace("feet", "hands")).replace("foot", "hand"))
		var streams: Array = []
		for path in slot.stem_paths:
			streams.append(load(path))

		var member := CHARACTER_SCENE.instantiate()
		member.name = "%s_%s" % [slot.band_id, str(slot.instrument).to_lower()]
		_characters_root.add_child(member)
		member.configure({
			"band_id": slot.band_id,
			"band_name": slot.band_name,
			"instrument": slot.instrument,
			"look_name": combo.look_name,
			"body": combo.body,
			"accessory": combo.accessory,
			"eyes": eyes,
			"feet": feet,
			"hands": hands,
			"stems": streams,
			"stage_bus": _muffle_bus_name(slot.band_id),
			"isolation_bus": _isolation_bus_name(slot.band_id, slot.instrument),
		})
		_characters.append(member)

	_place_characters()


func _build_look_combos() -> Array:
	var bodies: Array = []
	for path in BODY_PATHS:
		bodies.append(load(path))

	var accessories: Array = [null]
	for path in ACCESSORY_PATHS:
		accessories.append(load(path))

	var combos: Array = []
	for body in bodies:
		for accessory in accessories:
			var look_name: String = body.resource_path.get_file().get_basename()
			if accessory != null:
				look_name += " + " + accessory.resource_path.get_file().get_basename()
			combos.append({"body": body, "accessory": accessory, "look_name": look_name})
	return combos


func _place_characters() -> void:
	var blocked: Array[Rect2] = []
	for crate_name in ["CrateA", "CrateB"]:
		var crate := _crate_rect(crate_name)
		if crate.size != Vector2.ZERO:
			blocked.append(crate)
	blocked.append(_area.get_area_rect().grow(35))
	blocked.append(_stage.get_stage_rect().grow(20))

	var placed: Array[Vector2] = []
	for member in _characters:
		var pos := _find_spawn(placed, blocked)
		member.global_position = pos
		placed.append(pos)


func _find_spawn(placed: Array[Vector2], blocked: Array[Rect2]) -> Vector2:
	var bounds := Rect2(-470, -245, 940, 490)

	for relax in 10:
		var needed := maxf(min_character_distance - float(relax) * 10.0, 70.0)
		for attempt in 300:
			var pos := Vector2(
				randf_range(bounds.position.x, bounds.end.x),
				randf_range(bounds.position.y, bounds.end.y)
			)
			if pos.distance_to(_player.global_position) < 150.0:
				continue

			var ok := true
			for area in blocked:
				if area.has_point(pos):
					ok = false
					break
			if not ok:
				continue

			for other in placed:
				if other.distance_to(pos) < needed:
					ok = false
					break
			if ok:
				return pos

	return Vector2(randf_range(-400, 400), randf_range(-200, 200))


func _crate_rect(crate_name: String) -> Rect2:
	var body := get_parent().get_node_or_null("Room/" + crate_name)
	if body == null:
		return Rect2()
	var shape_node = body.get_node_or_null("Shape")
	if shape_node == null or shape_node.shape == null:
		return Rect2()
	var size: Vector2 = shape_node.shape.size
	return Rect2(body.global_position - size * 0.5, size).grow(45)


func _on_start() -> void:
	get_tree().paused = false
	_hud.hide_overlays()
	for character in _characters:
		character.set_start_fade(0.0)
		character.start_audio()
	_band_fade = 0.0
	_band_fading = true
	AudioManager.fade_out_menu_music(band_fade_in_seconds)
	_round_index = 0
	_start_round()


func _start_round() -> void:
	_active_band = _band_order[_round_index]
	Global.time_left = round_seconds
	_last_shown_second = -1

	_area.start_round(_active_band.id, _active_band.name, _active_band.stems.size())
	for character in _characters:
		character.set_mix_gain(1.0)
		character.set_isolation_gain(1.0)

	_hud.set_band(_active_band.name, _active_band.genre, _active_band.stems.size())
	_hud.set_timer(Global.time_left)
	state = State.PLAYING


func _on_band_complete() -> void:
	if state != State.PLAYING:
		return

	state = State.FOCUS
	for character in _characters:
		character.set_isolation_gain(1.0)
		character.set_mix_gain(2.5 if character.band_id == _active_band.id else 0.15)

	await get_tree().create_timer(focus_seconds).timeout
	if state != State.FOCUS:
		return
	_send_band_to_stage()


func _send_band_to_stage() -> void:
	state = State.TRANSITION

	var members: Array = []
	for character in _characters:
		if character.band_id == _active_band.id:
			members.append(character)

	var new_row := 0 if _stage_band_members.is_empty() else 1 - _stage_row
	_fade_band_onto_stage(_active_band.id, stage_audio_fade_seconds)
	for i in members.size():
		members[i].go_to_stage(_stage.get_slot(i, members.size(), new_row), stage_audio_fade_seconds)

	await get_tree().create_timer(walk_seconds).timeout

	# The new band has walked onto the stage; retire the previous one.
	_clear_stage_band()
	_stage_band_members = members
	_stage_row = new_row

	_round_index += 1
	if _round_index >= _band_order.size():
		_victory()
	else:
		_start_round()


func _clear_stage_band() -> void:
	for character in _stage_band_members:
		_characters.erase(character)
		if is_instance_valid(character):
			character.stop_audio()
			character.queue_free()
	_stage_band_members = []


func _game_over() -> void:
	state = State.GAME_OVER
	for character in _characters:
		character.stop_audio()
	_hud.show_game_over()
	get_tree().paused = true


func _victory() -> void:
	state = State.VICTORY
	for character in _characters:
		character.stop_audio()
	_hud.show_victory()
	get_tree().paused = true


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
