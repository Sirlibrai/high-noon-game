shader_type canvas_item;
// Heat haze over the splash's street: what is already drawn underneath ripples sideways,
// strongest in the middle of the band (the far street at noon) and fading out at its edges.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength = 2.2;  // the largest shift, in screen pixels

void fragment() {
	float band = smoothstep(0.0, 0.45, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float w = sin(UV.y * 110.0 + TIME * 3.1) * 0.6 + sin(UV.x * 37.0 - TIME * 1.9 + UV.y * 41.0) * 0.4;
	vec2 shift = vec2(w, w * 0.25) * strength * band * SCREEN_PIXEL_SIZE;
	COLOR = texture(screen, SCREEN_UV + shift);
}
