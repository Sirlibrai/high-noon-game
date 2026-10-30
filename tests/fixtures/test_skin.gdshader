shader_type canvas_item;
// Test-only skin shader: warms the finished screen, to prove a skin's shader reaches the final layer.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	COLOR = vec4(c.r, c.g * 0.9, c.b * 0.7, 1.0);
}
