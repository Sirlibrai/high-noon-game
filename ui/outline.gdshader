shader_type canvas_item;
// Characters and shootable props: a dark brown outline round the sprite (not black), and on shootable
// props a soft glint now and then. The quad is grown by the outline's width so it isn't clipped at the
// texture's edge. flip_x is -1 for a sprite drawn mirrored (its UVs run the other way).

uniform vec4 outline_colour : source_color = vec4(0.227, 0.133, 0.078, 1.0);
uniform float width = 2.0;     // texels
uniform float flip_x = 1.0;
uniform float glint = -1.0;    // the sweep's position across the sprite (0..1), off outside
uniform float glint_strength = 0.45;
uniform float flash = 0.0;     // a hit: the sprite flashes white (FeedbackDirector)

varying vec4 tint;  // the sprite's modulate (in fragment(), COLOR already includes the texture)

void vertex() {
	tint = COLOR;
	vec2 dir = UV * 2.0 - 1.0;
	VERTEX += vec2(dir.x * flip_x, dir.y) * width;
	UV += dir * width * TEXTURE_PIXEL_SIZE;
}

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	vec4 base = alpha_at(TEXTURE, UV) > 0.0 ? texture(TEXTURE, UV) : vec4(0.0);
	float a = 0.0;
	if (width > 0.0) {
		vec2 s = TEXTURE_PIXEL_SIZE * width;
		for (int i = 0; i < 12; i++) {
			float t = float(i) * 0.5235988;  // twelve directions
			vec2 d = vec2(cos(t), sin(t)) * s;
			a = max(a, max(alpha_at(TEXTURE, UV + d), alpha_at(TEXTURE, UV + d * 0.5)));  // two rings: a smooth edge
		}
		a = smoothstep(0.25, 0.6, a);  // round solid shapes only, not the faint halo some cut-outs keep at their edges
	}
	float out_a = base.a + a * outline_colour.a * (1.0 - base.a);
	vec3 rgb = out_a > 0.0 ? (base.rgb * base.a + outline_colour.rgb * a * outline_colour.a * (1.0 - base.a)) / out_a : base.rgb;
	if (glint >= 0.0) {
		float band = 1.0 - smoothstep(0.0, 0.12, abs((UV.x + UV.y) * 0.5 - glint));
		rgb += vec3(1.0, 0.95, 0.8) * band * glint_strength * base.a;
	}
	rgb = mix(rgb, vec3(1.0), flash * base.a);
	COLOR = vec4(rgb, out_a) * tint;
}
