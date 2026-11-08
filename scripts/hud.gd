extends CanvasLayer

## Screen-space HUD: band announcement and countdown at the top, plus the
## intro / game-over / victory overlays.

signal start_pressed
signal restart_pressed

const TIMER_COLOR := Color(1.0, 0.88, 0.35)

var _top_bar: ColorRect
var _band_label: Label
var _timer_label: Label
var _intro: Control
var _end: Control
var _end_title: Label
var _end_message: Label
var _start_button: Button
var _restart_button: Button
var _timer_flash_tween: Tween


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_top_bar = ColorRect.new()
	_top_bar.name = "TopBar"
	_top_bar.color = Color(0.02, 0.02, 0.03, 0.72)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_bar)
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_bottom = 76

	_band_label = _label("", 22, Color.WHITE)
	_band_label.name = "BandLabel"
	_top_bar.add_child(_band_label)
	_band_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_band_label.offset_top = 6
	_band_label.offset_bottom = 40
	_band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_band_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_timer_label = _label("05:00", 30, TIMER_COLOR)
	_timer_label.name = "TimerLabel"
	_top_bar.add_child(_timer_label)
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_timer_label.offset_top = 38
	_timer_label.offset_bottom = 74
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_intro = _build_overlay(
		"Intro",
		"Fyttikatta Wallahiiii",
		"Yoooo, lever alle de riktige medlemmene i bandet broderrr",
		"Start",
		true
	)
	_start_button = _intro.get_node("Panel/Action")

	_end = _build_overlay("End", "TIME'S UP", "", "Restart", false)
	_end.visible = false
	_end_title = _end.get_node("Panel/Title")
	_end_message = _end.get_node("Panel/Message")
	_restart_button = _end.get_node("Panel/Action")


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _build_overlay(node_name: String, title_text: String, body_text: String, button_text: String, is_start: bool) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.color = Color(0.08, 0.09, 0.13, 0.98)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -230
	panel.offset_bottom = 230

	var title := _label(title_text, 36, Color.WHITE)
	title.name = "Title"
	title.position = Vector2(0, 28)
	title.size = Vector2(720, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var message := _label(body_text, 18, Color(0.85, 0.90, 1.0))
	message.name = "Message"
	message.position = Vector2(50, 100)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size = Vector2(620, 240)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(message)

	var button := Button.new()
	button.name = "Action"
	button.text = button_text
	button.position = Vector2(250, 392)
	button.size = Vector2(220, 54)
	button.add_theme_font_size_override("font_size", 22)
	button.mouse_entered.connect(AudioManager.play_select)
	panel.add_child(button)

	if is_start:
		button.pressed.connect(func() -> void: start_pressed.emit())
	else:
		button.pressed.connect(func() -> void: restart_pressed.emit())

	return overlay


func show_intro() -> void:
	_top_bar.visible = false
	_intro.visible = true
	_end.visible = false
	_start_button.grab_focus()


func hide_overlays() -> void:
	_intro.visible = false
	_end.visible = false
	_top_bar.visible = true


func set_band(band_name: String, genre: String, member_count: int) -> void:
	_band_label.text = "Neste band: %s (%s) - %d medlemmer" % [band_name, genre, member_count]


func set_timer(seconds: float) -> void:
	var total := maxi(int(ceil(seconds)), 0)
	var minutes := int(total / 60.0)
	var secs := total % 60
	_timer_label.text = "%02d:%02d" % [minutes, secs]


## Red-flash the countdown and float the lost seconds down from it.
func show_time_penalty(seconds: float) -> void:
	_flash_timer()
	_spawn_time_penalty_text(seconds)


func _flash_timer() -> void:
	if is_instance_valid(_timer_flash_tween):
		_timer_flash_tween.kill()

	_timer_label.modulate = Color.WHITE
	var flash_color := Color(1.0, 0.16, 0.12)
	_set_timer_color(flash_color)
	_timer_flash_tween = create_tween()
	_timer_flash_tween.tween_method(_set_timer_color, flash_color, TIMER_COLOR, 0.6) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _set_timer_color(color: Color) -> void:
	_timer_label.add_theme_color_override("font_color", color)


func _spawn_time_penalty_text(seconds: float) -> void:
	var text := _label("-%d" % int(seconds), 28, Color(1.0, 0.2, 0.15))
	text.name = "TimePenalty"
	text.size = Vector2(90.0, 40.0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(text)

	var timer_rect := _timer_label.get_global_rect()
	text.position = Vector2(
		timer_rect.get_center().x - text.size.x * 0.5,
		timer_rect.end.y + 2.0
	)

	var move_tween := create_tween()
	move_tween.tween_property(text, "position:y", text.position.y + 64.0, 1.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	move_tween.tween_callback(text.queue_free)

	var fade_tween := create_tween()
	fade_tween.tween_property(text, "modulate:a", 0.0, 0.9) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)


func show_game_over() -> void:
	_end_title.text = "TIDEN ER UTE"
	_end_message.text = "Bandet ble ikke klare i tide."
	_intro.visible = false
	_end.visible = true
	_top_bar.visible = false
	_restart_button.grab_focus()


func show_victory() -> void:
	_end_title.text = "ALLE BAND BLE SAMLET"
	_end_message.text = "Alle bandene kom seg på scenen. Bra jobba!"
	_intro.visible = false
	_end.visible = true
	_top_bar.visible = false
	_restart_button.grab_focus()
