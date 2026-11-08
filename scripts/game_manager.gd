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
			{"instrument": "Organ", "paths": ["res://songs/no-messing/mono/organ.mp3"]},
			{"instrument": "Horns", "paths": ["res://songs/no-messing/mono/horns.mp3"]},
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
]

const BODY_PATHS := [
	"res://assets/sprites/bodies/fotball.png",
	"res://assets/sprites/bodies/green_pepper.png",
	"res://assets/sprites/bodies/lemon.png",
	"res://assets/sprites/bodies/red_pepper.png",
	"res://assets/sprites/bodies/yellow_pepper.png",
]
const ACCESSORY_PATHS := [
	"res://assets/sprites/accessories/top_hat.png",
	"res://assets/sprites/accessories/bow.png",
	"res://assets/sprites/accessories/candle.png",
	"res://assets/sprites/accessories/sunshine_and_rainbows.png",
]
const EYE_PATHS := [
	"res://assets/sprites/eyes/closed_eyes.png",
	"res://assets/sprites/eyes/default_eyes.png",
]
const FOOT_PATH := "res://assets/sprites/foot.png"

enum State {INTRO, PLAYING, FOCUS, TRANSITION, GAME_OVER, VICTORY}

@export var round_seconds: float = 300.0
@export var focus_seconds: float = 4.0
@export var walk_seconds: float = 1.6
@export var min_character_distance: float = 130.0
@export var isolate_radius: float = 45.0
@export var duck_gain: float = 0.22

var state: int = State.INTRO

var _characters: Array = []
var _band_order: Array = []
var _round_index := 0
var _active_band: Dictionary = {}
var _last_shown_second := -1
var _stage_band_members: Array = []
var _stage_row := 0

var _player: Node2D
var _area: Node
var _hud: Node
var _stage: Node
var _characters_root: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	_player = get_tree().get_first_node_in_group("player")
	_area = get_parent().get_node("CollectionArea")
	_hud = get_parent().get_node("HUD")
	_stage = get_parent().get_node("Stage")
	_characters_root = get_parent().get_node("Characters")

	_ensure_muffled_bus()
	_hud.start_pressed.connect(_on_start)
	_hud.restart_pressed.connect(_on_restart)
	_area.band_complete.connect(_on_band_complete)

	_build_roster()
	_hud.show_intro()
	get_tree().paused = true


func _process(delta: float) -> void:
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


func _ensure_muffled_bus() -> void:
	if AudioServer.get_bus_index("Muffled") != -1:
		return

	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, "Muffled")
	AudioServer.set_bus_send(index, "Master")

	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = 900.0
	filter.resonance = 0.6
	AudioServer.add_bus_effect(index, filter)


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

	var foot: Texture2D = load(FOOT_PATH)
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var combo: Dictionary = combos[i % combos.size()]
		var eyes: Texture2D = load(EYE_PATHS[randi() % EYE_PATHS.size()])
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
			"foot": foot,
			"stems": streams,
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
		character.start_audio()
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
	for i in members.size():
		members[i].go_to_stage(_stage.get_slot(i, members.size(), new_row))

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
