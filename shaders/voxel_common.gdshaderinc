// Shared terrain lighting. Terrain is unshaded; light is computed here so it stays cheap on
// mobile GPUs. Sun + ambient (constant per face) are evaluated per vertex; only the helmet
// lamp and placed lamps are evaluated per fragment.
uniform sampler2DArray tiles : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 ambient_color : source_color = vec3(0.35, 0.33, 0.45);
uniform vec3 lamp_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float lamp_range = 10.0;
uniform vec4 lights_pos[8];
uniform vec4 lights_col[8];
uniform int light_count = 0;
uniform float emissive_boost = 1.25;
uniform float time_s = 0.0;
uniform float wind = 1.0;

varying vec3 wpos;
varying vec3 vlight;
varying float vfacing;
varying flat float layer;
varying flat float noclamp;

void vertex() {
	layer = UV2.x;
	noclamp = UV2.y;
	// Plants: sway the top vertices in the wind.
	if (noclamp > 0.5 && UV.y < 0.5) {
		vec3 wp0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float ph = wp0.x * 0.7 + wp0.z * 0.5;
		VERTEX.x += sin(time_s * 1.7 + ph) * 0.07 * wind;
		VERTEX.z += cos(time_s * 1.3 + ph * 1.3) * 0.05 * wind;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = NORMAL;
	float facing = n.y > 0.5 ? 1.0 : (n.y < -0.5 ? 0.5 : (abs(n.x) > 0.5 ? 0.78 : 0.66));
	if (noclamp > 0.5) {
		facing = 0.92;
		n = normalize(sun_dir);
	}
	float sky = COLOR.g;
	float ndl = max(dot(n, normalize(sun_dir)), 0.0);
	vlight = (ambient_color * facing * sky + sun_color * ndl * sky * sky * 0.85) * COLOR.r;
	vfacing = facing;
}

vec4 sample_tile(vec2 uv_in) {
	vec2 uv = noclamp > 0.5 ? clamp(uv_in, vec2(0.002), vec2(0.998)) : fract(uv_in);
	return textureGrad(tiles, vec3(uv, layer), dFdx(uv_in), dFdy(uv_in));
}

vec3 terrain_light(float ao) {
	vec3 L = vlight;
	vec3 d = wpos - lamp_pos;
	float lf = clamp(1.0 - dot(d, d) / (lamp_range * lamp_range), 0.0, 1.0);
	L += lamp_color * lf * lf * (0.55 + 0.45 * vfacing) * ao;
	for (int i = 0; i < 8; i++) {
		if (i >= light_count) { break; }
		vec3 dl = wpos - lights_pos[i].xyz;
		float f = clamp(1.0 - dot(dl, dl) / (lights_pos[i].w * lights_pos[i].w), 0.0, 1.0);
		L += lights_col[i].rgb * f * f * ao;
	}
	return max(L, vec3(0.025) * ao);
}
