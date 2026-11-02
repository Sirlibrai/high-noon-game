shader_type canvas_item;
// Debug view: the whole screen in greyscale, to check targets still stand out without colour.

uniform sampler2D screen : hint_screen_texture, filter_linear;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(vec3(dot(c, vec3(0.299, 0.587, 0.114))), 1.0);
}
