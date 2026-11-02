shader_type canvas_item;
// A coming-soon wanted poster: the painting washed out towards old sepia paper, as if it has hung in
// the sun a long while, so the live bounties stand out beside it.

uniform float fade = 0.55;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 sepia = vec3(0.86, 0.74, 0.57) * (0.35 + 0.75 * g);
	COLOR = vec4(mix(c.rgb, sepia, fade) * 0.9, c.a * COLOR.a);
}
