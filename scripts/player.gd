extends CharacterBody2D

## Basic top-down player controller.
##
## Move with WASD or the arrow keys. move_and_slide() resolves collisions
## against the room's StaticBody2D walls, so the player slides along them.

@export var move_speed: float = 260.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
## Minimum interval between left/right flips.
@export var flip_rate_limit: float = 0.18
@export var flip_deadzone: float = 20.0
## 1.1 makes the character 10% larger than the source art.
@export var visual_scale: float = 1.1

@onready var _visual: Node2D = $Visual
@onready var _anim: AnimationPlayer = $Visual/Entity/AnimationPlayer

var _facing := 1
var _last_flip_time := -100.0


func _ready() -> void:
	_visual.scale = Vector2(visual_scale, visual_scale)
	_anim.play("idle")


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_facing()
	_update_animation()


func _update_facing() -> void:
	var vx := velocity.x
	if absf(vx) <= flip_deadzone:
		return

	var want := 1 if vx < 0.0 else -1
	if want == _facing:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_flip_time < flip_rate_limit:
		return

	_facing = want
	_last_flip_time = now
	_visual.scale.x = float(_facing) * visual_scale


func _update_animation() -> void:
	var wanted := "walking_2" if velocity.length() > 10.0 else "idle"
	if _anim.current_animation != wanted:
		_anim.play(wanted)
