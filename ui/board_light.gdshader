shader_type canvas_item;
// The Bounty board's lighting: a lantern overhead throws a warm pool of light on the middle of the
// screen, and the edges fall away into a soft dark vignette. The pool flickers a little.

uniform vec2 centre = vec2(0.5, 0.42);   // the pool's middle, as a fraction of the screen
uniform float reach = 0.62;              // how far the light reaches before the dark takes over
uniform float dark = 0.66;               // how dark the far corners get
uniform float warmth = 0.10;             // the warm glow at the pool's heart

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 d = (SCREEN_UV - centre) * aspect * vec2(0.62, 1.0);  // a wide pool: the poster row is wide
	float r = length(d) / reach;
	float flicker = 1.0 + 0.035 * sin(TIME * 7.3) + 0.025 * sin(TIME * 12.9 + 1.7) + 0.02 * sin(TIME * 3.1);
	float light = clamp((1.0 - smoothstep(0.18, 1.0, r)) * flicker, 0.0, 1.0);
	vec4 shade = vec4(0.06, 0.03, 0.015, dark * (1.0 - light));
	vec4 glow = vec4(1.0, 0.78, 0.42, warmth * light * flicker);
	COLOR = mix(shade, glow, light);
}
