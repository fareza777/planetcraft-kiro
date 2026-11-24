// Shared terrain lighting. Terrain is unshaded; light is computed here so it stays cheap on
// mobile GPUs. Sky light and block light (lamps, crystals, magma) are flood-filled by the
// mesher and arrive as smooth per-vertex values: COLOR.r = AO, COLOR.g = sky light,
// COLOR.b = emissive flag, COLOR.a = block light. Only the helmet lamp is per fragment.
uniform sampler2DArray tiles : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 ambient_color : source_color = vec3(0.35, 0.33, 0.45);
uniform vec3 lamp_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float lamp_range = 10.0;
uniform vec3 block_light_color : source_color = vec3(1.0, 0.78, 0.5);
uniform float emissive_boost = 1.25;
uniform float time_s = 0.0;
uniform float wind = 1.0;
// per-planet colour grading (data/planets.json "grade")
uniform vec3 grade_tint : source_color = vec3(1.0);
uniform float grade_sat = 1.0;
uniform float grade_contrast = 1.0;
// scanner pulse (player ability): ring radius around scan_origin, 0 = off
uniform vec3 scan_origin = vec3(0.0, -1000.0, 0.0);
uniform float scan_radius = 0.0;
uniform float scan_fade = 0.0;

varying vec3 wpos;
varying vec3 vlight;
varying vec3 vnorm;
varying float vfacing;
varying flat float layer;
varying flat float noclamp;
varying flat float vkind;

void vertex() {
	layer = UV2.x;
	// UV2.y: 0 = solid face, 1 = cross plant (clamped UV), 2 = foliage that sways
	float kind = UV2.y;
	vkind = kind;
	noclamp = (kind > 0.5 && kind < 1.5) ? 1.0 : 0.0;
	vec3 wp0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = wp0.x * 0.7 + wp0.z * 0.5;
	if (noclamp > 0.5 && UV.y < 0.5) {
		VERTEX.x += sin(time_s * 1.7 + ph) * 0.08 * wind;
		VERTEX.z += cos(time_s * 1.3 + ph * 1.3) * 0.06 * wind;
	} else if (kind > 1.5) {
		float gust = 0.6 + 0.4 * sin(time_s * 0.35 + wp0.x * 0.05);
		VERTEX.x += sin(time_s * 1.1 + ph + wp0.y * 0.8) * 0.045 * wind * gust;
		VERTEX.y += sin(time_s * 1.7 + ph * 1.7) * 0.02 * wind * gust;
		VERTEX.z += cos(time_s * 0.9 + ph * 1.2) * 0.04 * wind * gust;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = NORMAL;
	vnorm = n;
	float facing = n.y > 0.5 ? 1.0 : (n.y < -0.5 ? 0.5 : (abs(n.x) > 0.5 ? 0.78 : 0.66));
	if (noclamp > 0.5) {
		facing = 0.92;
		n = normalize(sun_dir);
	}
	float sky = COLOR.g;
	float ndl = max(dot(n, normalize(sun_dir)), 0.0);
	vec3 skyl = ambient_color * facing * sky + sun_color * ndl * sky * sky * 0.85;
	float bl = COLOR.a * COLOR.a * 1.25;
	float lum = dot(skyl, vec3(0.3, 0.5, 0.2));
	vlight = (skyl + block_light_color * bl * (0.6 + 0.4 * facing) * (1.0 - 0.55 * clamp(lum, 0.0, 1.0))) * COLOR.r;
	vfacing = facing;
}

vec4 sample_tile(vec2 uv_in) {
	vec2 uv = noclamp > 0.5 ? clamp(uv_in, vec2(0.002), vec2(0.998)) : fract(uv_in);
	return textureGrad(tiles, vec3(uv, layer), dFdx(uv_in), dFdy(uv_in));
}

float cell_hash(vec3 c) {
	return fract(sin(dot(c, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Breaks up texture repetition: a small per-block brightness offset plus a broad,
// slowly varying tint across the landscape.
vec3 surface_variation(vec3 col) {
	vec3 cell = floor(wpos - vnorm * 0.01);
	float h = cell_hash(cell);
	float macro = sin(wpos.x * 0.071 + sin(wpos.z * 0.053) * 2.0) * sin(wpos.z * 0.067 + wpos.x * 0.021);
	col *= 0.95 + 0.07 * h;
	col *= vec3(1.0 + 0.05 * macro, 1.0 + 0.025 * macro, 1.0 - 0.04 * macro);
	if (vkind > 1.5) {
		// foliage canopy: sunlit tops lighter and warmer, undersides cooler
		col *= mix(vec3(0.82, 0.88, 1.02), vec3(1.22, 1.16, 1.02), clamp((vfacing - 0.5) * 2.0, 0.0, 1.0)) * 1.08;
	}
	return col;
}

vec3 grade(vec3 c) {
	c *= grade_tint;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, grade_sat);
	c = (c - 0.45) * grade_contrast + 0.45;
	return max(c, vec3(0.0));
}

vec3 scan_ring(vec3 col) {
	if (scan_fade <= 0.0) {
		return col;
	}
	float d = distance(wpos, scan_origin);
	float ring = smoothstep(1.6, 0.0, abs(d - scan_radius));
	float inside = step(d, scan_radius) * 0.06;
	return col + vec3(0.25, 0.9, 1.0) * (ring * 0.9 + inside) * scan_fade;
}

vec3 terrain_light(float ao) {
	vec3 L = vlight;
	vec3 d = wpos - lamp_pos;
	float lf = clamp(1.0 - dot(d, d) / (lamp_range * lamp_range), 0.0, 1.0);
	L += lamp_color * lf * lf * (0.55 + 0.45 * vfacing) * ao;
	return max(L, vec3(0.025) * ao);
}

vec3 shade_terrain(vec4 t, vec4 vc) {
	vec3 col;
	if (vc.b > 0.5) {
		col = t.rgb * emissive_boost * (0.82 + 0.18 * sin(time_s * 2.2 + wpos.x * 0.45 + wpos.y * 0.7 + wpos.z * 0.3));
	} else {
		col = surface_variation(t.rgb) * terrain_light(vc.r);
	}
	return scan_ring(grade(col));
}
