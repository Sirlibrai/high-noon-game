shader_type canvas_item;
// The sheriff's office light (brief v2 §10): the room is softly dim, and the chosen object
// lights up warmly for a moment before its screen opens. Drawn over the painting, under the plates.

uniform vec4 spot = vec4(0.0);  // the chosen object: x, y, width, height in screen pixels
uniform float lit = 0.0;        // 0 quiet, 1 fully lit
uniform float dim = 0.2;        // how dim the room is

varying vec2 px;

void vertex() {
	px = VERTEX;  // the rect covers the screen from (0, 0), so this is the screen pixel
}

void fragment() {
	vec2 q = abs(px - (spot.xy + spot.zw * 0.5)) - spot.zw * 0.5;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	float inside = (1.0 - smoothstep(-8.0, 24.0, d)) * lit;
	vec4 shade = vec4(0.0, 0.0, 0.0, dim * (1.0 - inside));
	vec4 warm = vec4(1.0, 0.85, 0.55, 0.28);
	COLOR = mix(shade, warm, inside);
}
