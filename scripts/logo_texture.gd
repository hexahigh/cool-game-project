class_name LogoTexture
extends RefCounted

## Godot's image importer only reads the first frame of a GIF, so the logo GIF
## was baked into a horizontal 3-frame sprite sheet. This rebuilds it as an
## animated texture for the menus.

const SHEET: Texture2D = preload("res://assets/logo-text-thing-sheet.png")
const FRAME_WIDTH := 923
const FRAME_COUNT := 3
const FRAME_SECONDS := 0.15


static func create() -> AnimatedTexture:
	var texture := AnimatedTexture.new()
	texture.frames = FRAME_COUNT

	# Crop from the sheet instead of using AtlasTextures: AnimatedTexture does
	# not crop AtlasTexture frames when rendering.
	var sheet_image := SHEET.get_image()
	var frame_height := sheet_image.get_height()
	for i in FRAME_COUNT:
		var region := Rect2i(i * FRAME_WIDTH, 0, FRAME_WIDTH, frame_height)
		var frame := ImageTexture.create_from_image(sheet_image.get_region(region))
		texture.set_frame_texture(i, frame)
		texture.set_frame_duration(i, FRAME_SECONDS)

	return texture
