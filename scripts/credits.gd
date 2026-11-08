extends Control

## Credits screen: the game world behind a dark overlay, an animated logo, a
## text block to fill in later, and a Back button.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

const OVERLAY_COLOR := Color(0.02, 0.02, 0.03, 0.68)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioManager.play_menu_music()
	_add_game_background()
	_build_ui()


## Show the real game world behind the credits UI.
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

	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.offset_left = -360.0
	logo.offset_right = 360.0
	logo.offset_top = 24.0
	logo.offset_bottom = 124.0
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.texture = LogoTexture.create()
	ui_layer.add_child(logo)

	# No ScrollContainer: the text gets the whole area between the logo and
	# the Back button.
	var credits := RichTextLabel.new()
	credits.name = "CreditsText"
	credits.anchor_left = 0.08
	credits.anchor_right = 0.92
	credits.anchor_top = 0.0
	credits.anchor_bottom = 1.0
	credits.offset_top = 140.0
	credits.offset_bottom = -96.0
	credits.bbcode_enabled = true
	credits.fit_content = false
	credits.scroll_active = false
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.text = """
Utviklet for Gamejam UNG 2026 av:
[ul]
Simon Bråten
itsneruta
Alisa Volik Fimland
Oliver Andreas Thunæs
[/ul]

Og en spesiell takk til:
[ul]
Aksel Bråten
LEIK
KRED
E6 medieverksted
Blålange
[/ul]
	"""
	ui_layer.add_child(credits)

	var back_button := _make_button("Tilbake")
	back_button.name = "Back"
	back_button.custom_minimum_size = Vector2(240, 56)
	back_button.anchor_left = 0.5
	back_button.anchor_right = 0.5
	back_button.anchor_top = 1.0
	back_button.anchor_bottom = 1.0
	back_button.offset_left = -120.0
	back_button.offset_right = 120.0
	back_button.offset_top = -84.0
	back_button.offset_bottom = -28.0
	back_button.pressed.connect(_on_back_pressed)
	ui_layer.add_child(back_button)

	back_button.grab_focus()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520, 64)
	button.add_theme_font_size_override("font_size", 26)
	button.mouse_entered.connect(AudioManager.play_select)
	return button


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
