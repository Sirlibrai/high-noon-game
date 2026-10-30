shader_type canvas_item;
// Turns a sprite white for the hit flash, whatever its art. CutoutRig animates `flash` from 1 to 0.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
