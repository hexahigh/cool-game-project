extends Control

## Main menu: the game world behind a dark overlay, an animated logo, and
## Play / Credits buttons.

const GAME_SCENE := "res://scenes/main.tscn"
const CREDITS_SCENE := "res://scenes/credits.tscn"

const START_TEXTURE := preload("res://assets/start.png")
const CREDITS_TEXTURE := preload("res://assets/credits.png")

const OVERLAY_COLOR := Color(0.02, 0.02, 0.03, 0.68)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioManager.play_menu_music()
	_add_game_background()
	_build_ui()


## Show the real game world behind the menu UI.
func _add_game_background() -> void:
	var preview: Node = load(GAME_SCENE).instantiate()
	preview.name = "GamePreview"
	preview.set_meta("menu_preview", true)
	add_child(preview)
	move_child(preview, 0)


func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "MenuUI"
	ui_layer.layer = 100
	add_child(ui_layer)

	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = OVERLAY_COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := VBoxContainer.new()
	center.name = "Center"
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -260.0
	center.offset_right = 260.0
	center.offset_top = -270.0
	center.offset_bottom = 270.0
	ui_layer.add_child(center)

	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.custom_minimum_size = Vector2(520, 120)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.texture = LogoTexture.create()
	center.add_child(logo)

	var play_button := _make_image_button(START_TEXTURE)
	play_button.name = "Play"
	play_button.pressed.connect(_on_play_pressed)
	center.add_child(play_button)

	var credits_button := _make_image_button(CREDITS_TEXTURE)
	credits_button.name = "Credits"
	credits_button.pressed.connect(_on_credits_pressed)
	center.add_child(credits_button)

	play_button.grab_focus()


func _make_image_button(texture: Texture2D) -> TextureButton:
	var image := texture.get_image()
	var used := image.get_used_rect()

	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = used

	var button := TextureButton.new()
	button.texture_normal = atlas
	button.ignore_texture_size = true
	var width := 420.0
	var height := width * float(used.size.y) / float(used.size.x)
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_entered.connect(AudioManager.play_select)
	return button


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file(CREDITS_SCENE)
