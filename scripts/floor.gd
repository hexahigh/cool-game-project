extends ColorRect

## Paints a checkerboard across this rect instead of a flat colour.

@export var light_color: Color = Color("#383737")
@export var dark_color: Color = Color("#525253")
@export var square_size: float = 32.0


func _ready() -> void:
	# The rect only defines the area; the checkerboard is drawn manually.
	color = Color.TRANSPARENT
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if square_size <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return

	var columns := ceili(size.x / square_size)
	var rows := ceili(size.y / square_size)
	for row in rows:
		for column in columns:
			var x := float(column) * square_size
			var y := float(row) * square_size
			var cell := Rect2(
				x,
				y,
				minf(square_size, size.x - x),
				minf(square_size, size.y - y)
			)
			var is_light := (column + row) % 2 == 0
			draw_rect(cell, light_color if is_light else dark_color)
