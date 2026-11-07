extends CharacterBody2D

## Basic top-down player controller.
##
## Move with WASD or the arrow keys. move_and_slide() resolves collisions
## against the room's StaticBody2D walls, so the player slides along them.

@export var move_speed: float = 260.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
