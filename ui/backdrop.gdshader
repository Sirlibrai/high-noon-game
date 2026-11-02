shader_type canvas_item;
// The street painting behind the gameplay (Level's background layer only): desaturated, hazed and
// dimmed a little, so characters and props, drawn at full colour, stand out. Inside the level's quiet
// zones (up to four rects, in canvas pixels) it is softened further: blurred and hazed, with a soft edge.

uniform float desaturate = 0.25;
uniform float haze = 0.1;
uniform vec3 haze_colour : source_color = vec3(0.93, 0.78, 0.62);
uniform float dim = 0.05;
uniform vec4 quiet[4];
uniform int quiet_n = 0;
uniform float quiet_blur = 2.5;         // texels
uniform float quiet_desaturate = 0.35;
uniform float quiet_haze = 0.15;
uniform float feather = 12.0;           // canvas pixels

varying vec2 world;
varying vec4 tint;  // the sprite's modulate (in fragment(), COLOR already includes the texture)

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

float quietness(vec2 p) {
	float q = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= quiet_n) {
			break;
		}
		vec4 r = quiet[i];
		vec2 d = max(r.xy - p, p - (r.xy + r.zw));
		float out_d = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);  // rounded: no straight edges to catch the eye
		q = max(q, 1.0 - smoothstep(-feather * 0.25, feather, out_d));
	}
	return q;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float q = quietness(world);
	if (q > 0.0) {
		vec2 o = TEXTURE_PIXEL_SIZE * quiet_blur * q;
		vec4 sum = c * 4.0;
		sum += texture(TEXTURE, UV + vec2(o.x, 0.0)) + texture(TEXTURE, UV - vec2(o.x, 0.0));
		sum += texture(TEXTURE, UV + vec2(0.0, o.y)) + texture(TEXTURE, UV - vec2(0.0, o.y));
		sum += texture(TEXTURE, UV + o) + texture(TEXTURE, UV - o);
		sum += texture(TEXTURE, UV + vec2(o.x, -o.y)) + texture(TEXTURE, UV + vec2(-o.x, o.y));
		c = sum / 12.0;
	}
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(grey), clamp(desaturate + quiet_desaturate * q, 0.0, 1.0));
	c.rgb = mix(c.rgb, haze_colour, clamp(haze + quiet_haze * q, 0.0, 1.0));
	c.rgb *= 1.0 - dim;
	COLOR = c * tint;
}
