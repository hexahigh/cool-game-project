extends CanvasLayer

## Hover and click handling for the stem cubes.
##
## When the player is close to a cube and the mouse hovers it, a tooltip
## follows the cursor. Clicking toggles whether the cube follows the player.

@export var interact_radius: float = 150.0

@onready var _tooltip: Label = $Tooltip

var _player: Node2D
var _hovered = null
var _mouse_position := Vector2.ZERO


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_mouse_position = get_viewport().get_mouse_position()
	_tooltip.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_position = event.position


func _process(_delta: float) -> void:
	_hovered = _find_hovered(_mouse_position)

	if _hovered == null:
		_tooltip.visible = false
		return

	_tooltip.text = "Stop following" if _hovered.is_following() else "Follow me"
	_place_tooltip(_mouse_position)
	_tooltip.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var target = _find_hovered(event.position)
	if target == null:
		return

	target.toggle_follow()
	_hovered = target
	_tooltip.text = "Stop following" if target.is_following() else "Follow me"
	_place_tooltip(event.position)
	_tooltip.visible = true
	get_viewport().set_input_as_handled()


## Center the tooltip horizontally under the cursor.
func _place_tooltip(mouse_position: Vector2) -> void:
	var width := _tooltip.get_combined_minimum_size().x
	if width <= 0.0:
		var font := _tooltip.get_theme_font("font")
		var font_size := _tooltip.get_theme_font_size("font_size")
		width = font.get_string_size(_tooltip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	_tooltip.position = Vector2(mouse_position.x - width * 0.5, mouse_position.y + 18.0)


## Returns the nearest interactable cube under the mouse, or null.
func _find_hovered(mouse_position: Vector2):
	if _player == null:
		return null

	var mouse_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * mouse_position
	for emitter in get_tree().get_nodes_in_group("stem_emitters"):
		if emitter.global_position.distance_to(_player.global_position) > interact_radius:
			continue
		if emitter.get_hover_rect().has_point(mouse_world):
			return emitter
	return null
