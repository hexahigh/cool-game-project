extends CharacterBody2D

const MOUTH_SCENE := preload("res://entities/mouth.tscn")

## A musician character: plays one or more stems, follows the player when
## clicked, parks in the collection area, leaves for the stage, and flips when
## it moves horizontally under its own power (never from being pushed).

## Isolation low-pass: open when this member is the one being listened to,
## slightly filtered when it is ducked behind the isolated member.
const ISOLATION_OPEN_HZ := 20500.0
const ISOLATION_DUCKED_HZ := 2500.0
const STAGE_ANIMATIONS := ["dancing_1", "dancing_2", "backflip"]
const STAGE_ANIMATION_WEIGHTS := [0.4, 0.4, 0.2] # relative chance of each stage dance
const IDLE_ANIMATION_WEIGHTS := [0.45, 0.45, 0.1] # relative chance of each idle dance

enum State {IDLE, FOLLOWING, PARKED, EJECTING, TO_STAGE, ON_STAGE}

@export var follow_speed: float = 320.0
@export var follow_stiffness: float = 6.0
@export var follow_damping: float = 12.0
## Distance the follower holds from the player.
@export var follow_distance: float = 90.0
@export var separation_radius: float = 64.0
@export var separation_strength: float = 1000.0
@export var hearing_radius: float = 460.0
@export var stage_volume_db: float = -8.0
## How quickly isolation ducking fades in/out.
@export var isolation_smoothing: float = 10.0
## Minimum interval between left/right flips.
@export var flip_rate_limit: float = 0.18
@export var flip_deadzone: float = 20.0
## Random delay range between idle dances for a member standing in the room.
@export var idle_dance_min_delay: float = 4.0
@export var idle_dance_max_delay: float = 10.0

var band_id := ""
var band_name := ""
var instrument := ""
var look_name := ""

var state: int = State.IDLE

@onready var _visual: Node2D = $Visual
@onready var _body: Sprite2D = $Visual/body
@onready var _eyes: Sprite2D = $Visual/body/eyes
@onready var _accessory: Sprite2D = $Visual/body/accessory
@onready var _anim: AnimationPlayer = $Visual/AnimationPlayer
@onready var _audio: AudioStreamPlayer2D = $Audio

var _audios: Array[AudioStreamPlayer2D] = []
var _mouth_anim: AnimationPlayer
var _player: Node2D
var _target_position := Vector2.ZERO
var _has_target := false
var _mix_gain := 1.0
var _isolation_gain := 1.0
var _isolation_target := 1.0
var _isolation_bus := ""
var _isolation_bus_index := -1
## 0 while performing in the room, 1 once fully settled into the stage mix.
var _stage_blend := 0.0
var _stage_blend_speed := 0.0
var _stage_transitioning := false
var _stage_start_volume := 0.0
var _stage_anim := ""
var _idle_dance_anim := ""
var _idle_dance_time_left := 0.0
var _idle_dance_delay := 0.0
var _on_stage := false
var _facing := 1
var _last_flip_time := -100.0
var _self_velocity := Vector2.ZERO


func _ready() -> void:
	add_to_group("band_members")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player = get_tree().get_first_node_in_group("player")
	_audios = [_audio]
	_audio.attenuation = 0.0
	_audio.panning_strength = 10.0
	_anim.play("idle")
	_idle_dance_delay = randf_range(idle_dance_min_delay, idle_dance_max_delay)

	# Mouth is a separate animated scene; attach it to the face.
	var mouth := MOUTH_SCENE.instantiate()
	mouth.name = "Mouth"
	mouth.position = Vector2(244.44, -220)
	_body.add_child(mouth)
	_mouth_anim = mouth.get_node("AnimationPlayer")
	_mouth_anim.play("idle")

	# The incoming dancing/singing clips are one-shots; keep them looping.
	var singing := _mouth_anim.get_animation("singing")
	if singing != null:
		singing.loop_mode = Animation.LOOP_LINEAR
	var dance := _anim.get_animation("dancing_1")
	if dance != null:
		dance.loop_mode = Animation.LOOP_LINEAR


func configure(data: Dictionary) -> void:
	band_id = data.band_id
	band_name = data.band_name
	instrument = data.instrument
	look_name = data.look_name
	state = State.IDLE
	_isolation_bus = data.get("isolation_bus", "")
	_isolation_bus_index = AudioServer.get_bus_index(_isolation_bus)

	_body.texture = data.body
	_eyes.texture = data.eyes
	if data.accessory != null:
		_accessory.texture = data.accessory
		_accessory.visible = true
	else:
		_accessory.visible = false

	# One character can play several stems (e.g. kick + snare).
	for i in range(1, _audios.size()):
		_audios[i].queue_free()
	_audios = [_audio]

	var streams: Array = data.stems
	for i in streams.size():
		var player: AudioStreamPlayer2D
		if i == 0:
			player = _audio
		else:
			player = AudioStreamPlayer2D.new()
			player.name = "Audio%d" % (i + 1)
			add_child(player)
			_audios.append(player)

		player.stream = streams[i]
		player.volume_db = -80.0
		player.attenuation = 0.0
		player.panning_strength = 3.0
		if _isolation_bus_index != -1:
			player.bus = _isolation_bus
		else:
			player.bus = data.get("stage_bus", "Master")

	_anim.play("idle")


func start_audio() -> void:
	for player in _audios:
		if player.stream != null and not player.playing:
			player.play()


func stop_audio() -> void:
	for player in _audios:
		player.stop()


func is_collectible() -> bool:
	return state == State.IDLE or state == State.FOLLOWING


func is_following() -> bool:
	return state == State.FOLLOWING


func is_isolatable() -> bool:
	for player in _audios:
		if player.playing:
			return true
	return false


func toggle_follow() -> void:
	if not is_collectible():
		return
	state = State.FOLLOWING if state == State.IDLE else State.IDLE


## Correct delivery: walk into the collection area and hold this slot.
func collect(parking_position: Vector2) -> void:
	state = State.PARKED
	_target_position = parking_position
	_has_target = true
	velocity = Vector2.ZERO


## Wrong delivery: leave the collection area and go back to idling.
func eject(exit_position: Vector2) -> void:
	state = State.EJECTING
	_target_position = exit_position
	_has_target = true


## Leave the collection area for the stage. The stage mix (volume + muffling)
## eases in over `transition_seconds` instead of snapping on arrival.
func go_to_stage(stage_position: Vector2, transition_seconds: float = 0.0) -> void:
	state = State.TO_STAGE
	_target_position = stage_position
	_has_target = true
	_stage_start_volume = _live_volume()
	if transition_seconds > 0.0:
		_stage_transitioning = true
		_stage_blend_speed = 1.0 / transition_seconds
	else:
		_stage_transitioning = false
		_stage_blend_speed = 0.0
		_stage_blend = 1.0


func set_mix_gain(gain: float) -> void:
	_mix_gain = gain


func set_isolation_gain(gain: float) -> void:
	_isolation_target = clampf(gain, 0.0, 1.0)


func get_hover_rect() -> Rect2:
	return Rect2(global_position - Vector2(45, 75), Vector2(90, 105))


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	var desired := Vector2.ZERO

	match state:
		State.FOLLOWING:
			desired = _seek(_player.global_position, follow_distance, follow_speed, follow_stiffness)
		State.PARKED, State.EJECTING, State.TO_STAGE:
			if _has_target:
				desired = _seek(_target_position, 0.0, follow_speed, follow_stiffness)
				if global_position.distance_to(_target_position) < 8.0:
					_on_reached_target()
		State.IDLE, State.ON_STAGE:
			desired = Vector2.ZERO

	# Face only by self-driven movement, never by separation pushes.
	_self_velocity = desired

	# Roaming/following characters keep each other apart; slots are fixed.
	if state == State.IDLE or state == State.FOLLOWING:
		desired += _separation_velocity()

	velocity = velocity.lerp(desired, 1.0 - exp(-follow_damping * delta))
	move_and_slide()

	_isolation_gain = lerpf(_isolation_gain, _isolation_target, 1.0 - exp(-isolation_smoothing * delta))
	if _stage_blend < 1.0:
		_stage_blend = minf(_stage_blend + _stage_blend_speed * delta, 1.0)
	_update_isolation_filter()
	_update_volume()
	_update_facing()
	_update_idle_dance(delta)
	_update_animation()


func _seek(target: Vector2, stop_distance: float, max_speed: float, stiffness: float) -> Vector2:
	var to_target := target - global_position
	var distance := to_target.length()
	if distance <= 0.001:
		return Vector2.ZERO
	var direction := to_target / distance
	return (direction * (distance - stop_distance) * stiffness).limit_length(max_speed)


func _on_reached_target() -> void:
	match state:
		State.PARKED:
			_has_target = false
			velocity = Vector2.ZERO
		State.EJECTING:
			_has_target = false
			velocity = Vector2.ZERO
			state = State.IDLE
		State.TO_STAGE:
			_has_target = false
			velocity = Vector2.ZERO
			_on_stage = true
			state = State.ON_STAGE


func _separation_velocity() -> Vector2:
	var push := Vector2.ZERO

	for other in get_tree().get_nodes_in_group("band_members"):
		if other == self:
			continue

		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()

		if distance < 0.001:
			var angle := float(get_instance_id() % 360) * PI / 180.0
			push += Vector2.RIGHT.rotated(angle)
			continue

		if distance < separation_radius:
			var closeness := 1.0 - distance / separation_radius
			push += (offset / distance) * (closeness + closeness * closeness * 2.0)

	return push * separation_strength


func _update_isolation_filter() -> void:
	if _isolation_bus_index == -1 or AudioServer.get_bus_effect_count(_isolation_bus_index) == 0:
		return

	var filter := AudioServer.get_bus_effect(_isolation_bus_index, 0) as AudioEffectLowPassFilter
	if filter == null:
		return

	# 0 = fully audible, 1 = fully ducked behind the isolated member.
	var amount := clampf(1.0 - _isolation_gain, 0.0, 1.0)
	filter.cutoff_hz = ISOLATION_OPEN_HZ * pow(ISOLATION_DUCKED_HZ / ISOLATION_OPEN_HZ, amount)


func _update_volume() -> void:
	var isolation_db := linear_to_db(maxf(_isolation_gain, 0.0001))
	var stage_volume := stage_volume_db + isolation_db
	var blend := smoothstep(0.0, 1.0, _stage_blend)

	# Crossfade from the room mix heard when the band set off into the muffled
	# stage mix, so neither the volume change nor the filtering snaps in.
	var start_volume := _stage_start_volume if _stage_transitioning else _live_volume()
	var volume := lerpf(start_volume, stage_volume, blend)

	for player in _audios:
		player.volume_db = volume


func _live_volume() -> float:
	if _player == null:
		return stage_volume_db

	var distance := global_position.distance_to(_player.global_position)
	var closeness := clampf(1.0 - distance / hearing_radius, 0.0, 1.0)
	var proximity_db := linear_to_db(maxf(closeness * closeness, 0.0001))
	var mix_db := linear_to_db(maxf(_mix_gain, 0.0001))
	var isolation_db := linear_to_db(maxf(_isolation_gain, 0.0001))
	return clampf(proximity_db + mix_db + isolation_db, -80.0, 6.0)


func _update_facing() -> void:
	var vx := _self_velocity.x
	if absf(vx) <= flip_deadzone:
		return

	var want := 1 if vx > 0.0 else -1
	if want == _facing:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_flip_time < flip_rate_limit:
		return

	_facing = want
	_last_flip_time = now
	_visual.scale.x = float(_facing)


## Occasionally break the idle pose with a short dance while waiting in the room.
func _update_idle_dance(delta: float) -> void:
	if state != State.IDLE:
		_cancel_idle_dance()
		return

	if _idle_dance_time_left > 0.0:
		_idle_dance_time_left -= delta
		if _idle_dance_time_left <= 0.0:
			_cancel_idle_dance()
		return

	_idle_dance_delay -= delta
	if _idle_dance_delay > 0.0:
		return

	var rng = RandomNumberGenerator.new()
	rnd.Randomize()

	_idle_dance_anim = STAGE_ANIMATIONS[rng.rand_weighted(weights)]
	var animation := _anim.get_animation(_idle_dance_anim)
	_idle_dance_time_left = animation.length if animation != null else 1.0


func _cancel_idle_dance() -> void:
	if _idle_dance_anim.is_empty():
		return

	_idle_dance_anim = ""
	_idle_dance_time_left = 0.0
	_idle_dance_delay = randf_range(idle_dance_min_delay, idle_dance_max_delay)

	# Idle and walking don't animate the visual root, so clear anything the
	# dance left behind before those clips take over.
	_visual.position = Vector2.ZERO
	_visual.rotation = 0.0
	_visual.scale = Vector2(float(_facing), 1.0)


func _update_animation() -> void:
	var moving := _self_velocity.length() > 12.0
	var wanted := "idle"
	if _on_stage:
		# Pick once so the dance does not change on every physics frame.
		if _stage_anim.is_empty():
			_stage_anim = STAGE_ANIMATIONS.pick_random()
		wanted = _stage_anim
	elif not _idle_dance_anim.is_empty():
		wanted = _idle_dance_anim
	elif moving:
		wanted = "walking"
	if _anim.current_animation != wanted:
		_anim.play(wanted)

	if _mouth_anim != null:
		var mouth_wanted := "singing" if _on_stage else "idle"
		if _mouth_anim.current_animation != mouth_wanted:
			_mouth_anim.play(mouth_wanted)
