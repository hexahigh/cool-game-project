extends CharacterBody2D

## A small colored cube that plays one song stem on a loop.
## Its volume rises as the player gets closer, and it can follow the player.
## Followers simply seek the player until they reach a minimum distance,
## then hold that distance. Nearby cubes gently repel each other.

@export var stem: AudioStream
@export var cube_color: Color = Color.WHITE
@export var hearing_radius: float = 460.0
## Maximum follow speed in pixels per second.
@export var follow_speed: float = 320.0
## Spring stiffness: higher values make followers catch up faster.
@export var follow_stiffness: float = 6.0
## Velocity damping: higher values reduce bobbing and overshoot.
@export var follow_damping: float = 12.0
## Distance the follower holds from the player.
@export var follow_distance: float = 44.0
## Distance at which cubes start pushing each other apart.
@export var separation_radius: float = 30.0
## Strength of the soft separation steering.
@export var separation_strength: float = 1000.0

@onready var _visual: ColorRect = $Visual
@onready var _audio: AudioStreamPlayer2D = $Audio

var _player: Node2D
var _following := false


func _ready() -> void:
	add_to_group("stem_emitters")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.color = cube_color
	if stem != null:
		_audio.stream = stem
	_player = get_tree().get_first_node_in_group("player")
	if _audio.stream != null:
		if _player != null:
			_audio.volume_db = _volume_db_for(global_position.distance_to(_player.global_position))
		_audio.play()


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	_audio.volume_db = _volume_db_for(global_position.distance_to(_player.global_position))

	var desired_velocity := Vector2.ZERO
	if _following:
		var to_player := _player.global_position - global_position
		var distance := to_player.length()
		if distance > 0.001:
			# Positive when too far (seek in), negative when too close (back off).
			var direction := to_player / distance
			desired_velocity = (direction * (distance - follow_distance) * follow_stiffness).limit_length(follow_speed)

	# Softly push away from nearby cubes so they never sit on top of each other.
	desired_velocity += _separation_velocity()

	velocity = velocity.lerp(desired_velocity, 1.0 - exp(-follow_damping * delta))
	move_and_slide()


func _separation_velocity() -> Vector2:
	var push := Vector2.ZERO

	for other in get_tree().get_nodes_in_group("stem_emitters"):
		if other == self:
			continue

		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()

		if distance < 0.001:
			# Perfectly stacked: pick a deterministic direction from the instance id.
			var angle := float(get_instance_id() % 360) * PI / 180.0
			push += Vector2.RIGHT.rotated(angle)
			continue

		if distance < separation_radius:
			var closeness := 1.0 - distance / separation_radius
			push += (offset / distance) * (closeness + closeness * closeness * 2.0)

	return push * separation_strength


func _volume_db_for(distance: float) -> float:
	var closeness := clampf(1.0 - distance / hearing_radius, 0.0, 1.0)
	return linear_to_db(maxf(closeness * closeness, 0.0001))


## World-space rectangle used for mouse hover detection.
func get_hover_rect() -> Rect2:
	return _visual.get_global_rect()


func is_following() -> bool:
	return _following


func toggle_follow() -> void:
	_following = not _following
