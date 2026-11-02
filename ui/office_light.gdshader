shader_type canvas_item;
// The sheriff's office light, drawn over the painting, under the tags. The painting is already dim and
// lamp-lit, so this only adds a light vignette at the screen's edges, and a warm glow on the chosen
// object for a moment before its screen opens. The room itself is never darkened.

uniform vec4 spot = vec4(0.0);  // the chosen object: x, y, width, height in screen pixels
uniform float lit = 0.0;        // 0 quiet, 1 fully lit
uniform vec2 screen = vec2(1280.0, 720.0);
uniform float vignette = 0.28;  // how dark the far corners get

varying vec2 px;

void vertex() {
	px = VERTEX;  // the rect covers the screen from (0, 0), so this is the screen pixel
}

void fragment() {
	vec2 uv = px / screen - 0.5;
	float edge = smoothstep(0.42, 0.78, length(uv * vec2(1.0, screen.y / screen.x * 1.6)));
	vec2 q = abs(px - (spot.xy + spot.zw * 0.5)) - spot.zw * 0.5;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	float glow = (1.0 - smoothstep(-6.0, 22.0, d)) * lit;
	vec4 shade = vec4(0.05, 0.02, 0.01, vignette * edge * (1.0 - glow));
	vec4 warm = vec4(1.0, 0.82, 0.5, 0.24);
	COLOR = mix(shade, warm, glow);
}
