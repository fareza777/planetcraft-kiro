shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2DArray tiles : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 ambient_color : source_color = vec3(0.35, 0.33, 0.45);
uniform vec3 lamp_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float lamp_range = 10.0;
uniform float time_s = 0.0;
uniform float alpha = 0.72;

varying vec3 wpos;
varying flat float layer;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	layer = UV2.x;
	if (NORMAL.y > 0.5) {
		VERTEX.y += sin(wpos.x * 0.9 + time_s * 1.6) * 0.035 + cos(wpos.z * 0.7 + time_s * 1.2) * 0.035;
	}
}

void fragment() {
	vec2 flow = vec2(time_s * 0.05, time_s * 0.03);
	vec4 t = textureGrad(tiles, vec3(fract(UV + flow), layer), dFdx(UV), dFdy(UV));
	vec4 t2 = textureGrad(tiles, vec3(fract(UV * 0.7 - flow * 1.3), layer), dFdx(UV), dFdy(UV));
	vec3 base = mix(t.rgb, t2.rgb, 0.5);
	if (COLOR.b > 0.5) {
		float pulse = 0.85 + 0.15 * sin(time_s * 2.0 + wpos.x * 0.3 + wpos.z * 0.2);
		ALBEDO = base * 1.6 * pulse;
		ALPHA = 1.0;
	} else {
		float sky = COLOR.g;
		vec3 L = ambient_color * sky + sun_color * max(sun_dir.y, 0.0) * sky * 0.8;
		float lf = clamp(1.0 - distance(wpos, lamp_pos) / lamp_range, 0.0, 1.0);
		L += lamp_color * lf * lf;
		vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
		float fres = pow(1.0 - abs(v.y), 3.0);
		vec3 spec = sun_color * pow(max(dot(reflect(-normalize(sun_dir), vec3(0.0, 1.0, 0.0)), v), 0.0), 48.0) * sky;
		ALBEDO = base * max(L, vec3(0.04)) + spec + vec3(0.25, 0.35, 0.45) * fres * sky * 0.4;
		ALPHA = mix(alpha, 0.92, fres);
	}
}
