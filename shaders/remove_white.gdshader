shader_type canvas_item;

// Keys out the plain white background of the drink sprite.
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.r > 0.98 && color.g > 0.98 && color.b > 0.98) {
		color.a = 0.0;
	}
	COLOR = color;
}
