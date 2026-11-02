shader_type canvas_item;
// The player is hit: a red glow at the screen's edges, clear in the middle (amount 0..1).

uniform float amount = 0.0;
uniform vec3 colour : source_color = vec3(0.78, 0.08, 0.05);

void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = smoothstep(0.55, 1.0, max(d.x * 0.9, d.y));
	COLOR = vec4(colour, edge * amount);
}
