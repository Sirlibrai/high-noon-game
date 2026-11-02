shader_type canvas_item;
// J.R.'s silhouette poster laid over his revealed one (identical but for the portrait). As `lift` goes
// from 0 to 1 the shadow lifts away: its lower edge rises up through the portrait, softly, and fades.

uniform float lift = 0.0;
uniform float top = 0.225;     // the portrait window's top and bottom, as fractions of the poster's height
uniform float bottom = 0.695;
const float SOFT = 0.06;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float line = mix(bottom + SOFT, top, lift);
	float keep = 1.0 - smoothstep(line - SOFT, line, UV.y);
	COLOR = vec4(c.rgb, c.a * COLOR.a * keep * (1.0 - 0.5 * lift));
}
