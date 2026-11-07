extends Node2D

## Performance platform where a collected band plays its muffled background set.

const STAGE_RECT := Rect2(-120, 185, 600, 97)
const SLOT_CENTER := Vector2(180, 235)
const SLOT_SPACING := 68.0
const ROW_Y := [212.0, 260.0]


func _ready() -> void:
	queue_redraw()
	var label := Label.new()
	label.name = "StageLabel"
	label.text = "STAGE"
	label.position = Vector2(-108, 192)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0, 0.8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)


func _draw() -> void:
	draw_rect(STAGE_RECT, Color(0.10, 0.09, 0.14, 0.95))
	draw_rect(STAGE_RECT, Color(0.55, 0.45, 0.85, 0.85), false, 4.0)
	draw_rect(Rect2(STAGE_RECT.position.x, STAGE_RECT.end.y - 8, STAGE_RECT.size.x, 8), Color(0.35, 0.28, 0.5, 0.9))


## Evenly spaced performance slot for a band of `total` members.
func get_slot(index: int, total: int, row: int = 0) -> Vector2:
	var start := SLOT_CENTER.x - (float(total - 1) * SLOT_SPACING * 0.5)
	var y: float = ROW_Y[clampi(row, 0, ROW_Y.size() - 1)]
	return Vector2(start + float(index) * SLOT_SPACING, y)


func get_stage_rect() -> Rect2:
	return STAGE_RECT
