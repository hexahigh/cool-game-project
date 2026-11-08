extends Node2D

## The drop-off zone in the bottom-left of the room.
## Following characters that enter it are parked (correct band) or ejected
## (wrong band). No counts are displayed.

signal band_complete

const AREA_RECT := Rect2(-500, 60, 350, 225)
const PARK_RECT := Rect2(-362, 90, 200, 185)
const EJECT_POINT := Vector2(-50, 30)

var active_band_id := ""
var band_size := 0
var correct := 0
var wrong := 0
var locked := false

var _slots: Array[Vector2] = []
var _free_slots: Array[int] = []


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(AREA_RECT, Color(0.07, 0.12, 0.10, 0.95))
	draw_rect(AREA_RECT, Color(0.35, 0.9, 0.55, 0.9), false, 4.0)
	draw_rect(PARK_RECT, Color(0.14, 0.32, 0.21, 0.45))


func start_round(band_id: String, _band_name: String, size: int) -> void:
	active_band_id = band_id
	band_size = size
	correct = 0
	wrong = 0
	locked = false
	_build_slots()


func _build_slots() -> void:
	_slots.clear()
	_free_slots.clear()
	if band_size <= 0:
		return

	var cols := 3 if band_size > 4 else 2
	var rows := int(ceil(float(band_size) / float(cols)))
	for i in band_size:
		var col := i % cols
		var row := int(float(i) / float(cols))
		var x := PARK_RECT.position.x + (float(col) + 0.5) * PARK_RECT.size.x / float(cols)
		var y := PARK_RECT.position.y + (float(row) + 0.5) * PARK_RECT.size.y / float(rows)
		_slots.append(Vector2(x, y))
		_free_slots.append(i)


func _process(_delta: float) -> void:
	if locked or active_band_id.is_empty():
		return

	for member in get_tree().get_nodes_in_group("band_members"):
		if not member.is_following():
			continue
		if not AREA_RECT.has_point(member.global_position):
			continue

		if member.band_id == active_band_id:
			if correct < band_size and not _free_slots.is_empty():
				var slot_index: int = _free_slots.pop_front()
				member.collect(_slots[slot_index])
				correct += 1
				if correct >= band_size:
					locked = true
					band_complete.emit()
		else:
			wrong += 1
			Global.time_left -= 30.0
			member.eject(EJECT_POINT)


func get_area_rect() -> Rect2:
	return AREA_RECT
