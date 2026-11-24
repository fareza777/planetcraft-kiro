shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// Water / magma / frozen seas. Vertex colour: r = water depth (0 at the shore, 1 = 8+ blocks),
// g = sky light, b = emissive (magma), a = block light.
uniform sampler2DArray tiles : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 ambient_color : source_color = vec3(0.35, 0.33, 0.45);
uniform vec3 lamp_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float lamp_range = 10.0;
uniform vec3 block_light_color : source_color = vec3(1.0, 0.78, 0.5);
uniform float time_s = 0.0;
uniform float alpha = 0.72;
uniform vec3 grade_tint : source_color = vec3(1.0);
uniform float grade_sat = 1.0;
uniform float grade_contrast = 1.0;

varying vec3 wpos;
varying flat float layer;
varying float depth;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	layer = UV2.x;
	depth = COLOR.r;
	if (NORMAL.y > 0.5) {
		float amp = 0.035 * clamp(depth * 2.0, 0.3, 1.0);
		VERTEX.y += sin(wpos.x * 0.9 + time_s * 1.6) * amp + cos(wpos.z * 0.7 + time_s * 1.2) * amp;
	}
}

vec3 grade(vec3 c) {
	c *= grade_tint;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, grade_sat);
	c = (c - 0.45) * grade_contrast + 0.45;
	return max(c, vec3(0.0));
}

float n2(vec2 p) {
	return sin(p.x * 1.7 + sin(p.y * 1.3)) * sin(p.y * 1.9 + sin(p.x * 1.1));
}

void fragment() {
	vec2 flow = vec2(time_s * 0.05, time_s * 0.03);
	vec4 t = textureGrad(tiles, vec3(fract(UV + flow), layer), dFdx(UV), dFdy(UV));
	vec4 t2 = textureGrad(tiles, vec3(fract(UV * 0.7 - flow * 1.3), layer), dFdx(UV), dFdy(UV));
	vec3 base = mix(t.rgb, t2.rgb, 0.5);
	float dep = clamp(depth, 0.0, 1.0);
	if (COLOR.b > 0.5) {
		float pulse = 0.85 + 0.15 * sin(time_s * 2.0 + wpos.x * 0.3 + wpos.z * 0.2);
		// cooler crust near the shore, hotter in the middle of a lava lake
		vec3 hot = base * 1.6 * pulse;
		ALBEDO = grade(mix(hot * vec3(0.55, 0.35, 0.3), hot, smoothstep(0.0, 0.5, dep)));
		ALPHA = 1.0;
	} else {
		float sky = COLOR.g;
		vec3 L = ambient_color * sky + sun_color * max(sun_dir.y, 0.0) * sky * 0.8;
		L += block_light_color * COLOR.a * COLOR.a * 1.2;
		float lf = clamp(1.0 - distance(wpos, lamp_pos) / lamp_range, 0.0, 1.0);
		L += lamp_color * lf * lf;
		vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
		float fres = pow(1.0 - abs(v.y), 3.0);
		vec3 spec = sun_color * pow(max(dot(reflect(-normalize(sun_dir), vec3(0.0, 1.0, 0.0)), v), 0.0), 48.0) * sky;
		// shallow water is lighter and greener, deep water darker and bluer
		vec3 shallow = base * vec3(1.15, 1.3, 1.15) + vec3(0.04, 0.08, 0.06);
		vec3 deep = base * vec3(0.55, 0.7, 0.95);
		vec3 wcol = mix(shallow, deep, smoothstep(0.05, 0.9, dep));
		// animated shoreline foam
		float wave = n2(wpos.xz * 0.9 + vec2(time_s * 0.6, time_s * 0.4)) * 0.5 + 0.5;
		float foam = smoothstep(0.32, 0.08, dep + wave * 0.12) * (0.6 + 0.4 * sin(time_s * 2.5 + dep * 30.0 + wpos.x));
		vec3 col = wcol * max(L, vec3(0.04)) + spec + vec3(0.25, 0.35, 0.45) * fres * sky * 0.4;
		col = mix(col, vec3(0.92, 0.97, 1.0) * max(L, vec3(0.15)), clamp(foam, 0.0, 1.0) * 0.75);
		ALBEDO = grade(col);
		ALPHA = clamp(mix(mix(alpha * 0.7, alpha, smoothstep(0.0, 0.5, dep)), 0.92, fres) + foam * 0.3, 0.0, 1.0);
	}
}
