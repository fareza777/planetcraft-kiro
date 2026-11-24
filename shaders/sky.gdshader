shader_type sky;
// Procedural alien sky: day/night gradient, sun disc and halo, star field, a large companion
// planet with an optional ring, and soft cloud bands. All parameters come from planets.json.

uniform vec3 top_color : source_color = vec3(0.11, 0.08, 0.31);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.44, 0.79);
uniform vec3 night_top : source_color = vec3(0.01, 0.01, 0.06);
uniform vec3 night_horizon : source_color = vec3(0.11, 0.06, 0.2);
uniform vec3 sun_color : source_color = vec3(1.0, 0.89, 0.72);
uniform vec3 moon_color : source_color = vec3(1.0, 0.69, 0.18);
uniform vec3 sun_dir = vec3(0.3, 0.6, 0.5);
uniform vec3 moon_dir = vec3(-0.5, 0.35, -0.6);
uniform float night = 0.0;
uniform float ring = 1.0;
uniform float space = 0.0;
uniform float time_s = 0.0;
uniform float storm = 0.0;
uniform float clouds = 1.0;
uniform vec3 storm_color : source_color = vec3(0.5, 0.4, 0.3);
// terrain fog colour: the band just above/below the horizon fades into it so distant chunk
// edges melt into the sky instead of ending in a hard line
uniform vec3 fog_color : source_color = vec3(0.5, 0.4, 0.6);
uniform float aurora = 0.0;
uniform vec3 aurora_color : source_color = vec3(0.3, 1.0, 0.7);
uniform float cloud_style = 0.0;
uniform vec3 grade_tint : source_color = vec3(1.0);
uniform float grade_sat = 1.0;
uniform float grade_contrast = 1.0;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash3(vec3(i, 1.0));
	float b = hash3(vec3(i + vec2(1.0, 0.0), 1.0));
	float c = hash3(vec3(i + vec2(0.0, 1.0), 1.0));
	float d = hash3(vec3(i + vec2(1.0, 1.0), 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float grad = smoothstep(-0.05, 0.65, h);
	vec3 day = mix(horizon_color, top_color, grad);
	vec3 nightc = mix(night_horizon, night_top, grad);
	float n = clamp(night, 0.0, 1.0);
	vec3 col = mix(day, nightc, n);
	if (h < 0.0) {
		col = mix(col, col * 0.35, smoothstep(0.0, -0.4, h));
	}
	vec3 sd = normalize(sun_dir);
	float s = max(dot(d, sd), 0.0);
	col += sun_color * (pow(s, 900.0) * 6.0 + pow(s, 24.0) * 0.45 + pow(s, 4.0) * 0.12) * (1.0 - n * 0.6);
	// sunset tint near horizon
	float sunset = (1.0 - abs(sd.y)) * smoothstep(0.35, 0.0, abs(h)) * (1.0 - n);
	col += sun_color * vec3(1.0, 0.45, 0.25) * sunset * 0.35 * pow(s, 2.0);
	// stars
	float star_vis = max(n, space) * smoothstep(-0.05, 0.2, h + space);
	if (star_vis > 0.01) {
		vec3 q = floor(d * 220.0);
		float r = hash3(q);
		float tw = 0.6 + 0.4 * sin(time_s * 2.0 + r * 40.0);
		col += vec3(0.9, 0.95, 1.0) * step(0.9965, r) * tw * star_vis * 1.4;
		float neb = vnoise(d.xz * 3.0 + d.y * 2.0);
		col += vec3(0.35, 0.15, 0.55) * neb * neb * neb * star_vis * 0.5;
		// shooting stars: a few short streaks per minute crossing a random sky patch
		float slot = floor(time_s / 7.0);
		float st = fract(time_s / 7.0);
		vec3 a0 = normalize(vec3(hash3(vec3(slot, 1.0, 3.0)) - 0.5, 0.55 + hash3(vec3(slot, 2.0, 5.0)) * 0.4, hash3(vec3(slot, 4.0, 7.0)) - 0.5));
		vec3 adir = normalize(cross(a0, vec3(0.3, 1.0, 0.2)));
		vec3 head = normalize(a0 + adir * (st * 0.9));
		float along = dot(d - head, -adir);
		float across = length(cross(d - head, adir));
		float streak = step(0.0, along) * smoothstep(0.18, 0.0, along) * smoothstep(0.0025, 0.0, across);
		col += vec3(1.0, 0.95, 0.85) * streak * step(st, 0.22) * star_vis * 2.5;
		// aurora curtains (cold worlds)
		if (aurora > 0.01 && h > 0.05) {
			vec2 ap = d.xz / (h + 0.25);
			float band = sin(ap.x * 2.2 + sin(ap.y * 1.3 + time_s * 0.15) * 2.5 + time_s * 0.05);
			float curtain = smoothstep(0.6, 1.0, band) * smoothstep(0.05, 0.3, h) * smoothstep(0.85, 0.35, h);
			float ripple = 0.6 + 0.4 * sin(ap.x * 14.0 + time_s * 1.2);
			col += mix(aurora_color, aurora_color.bgr, smoothstep(0.2, 0.7, h)) * curtain * ripple * aurora * star_vis * 0.7;
		}
	}
	// companion planet with ring
	vec3 md = normalize(moon_dir);
	vec3 t1 = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
	vec3 t2 = cross(t1, md);
	float mz = dot(d, md);
	if (mz > 0.0) {
		vec2 p = vec2(dot(d, t1), dot(d, t2)) / mz;
		float R = 0.16;
		float pr = length(p) / R;
		float ringr = length(vec2(p.x, p.y * 3.2) * mat2(vec2(0.96, -0.28), vec2(0.28, 0.96))) / R;
		bool front_ring = p.y * 3.2 * 0.96 + p.x * 0.28 < 0.0;
		vec3 ringc = vec3(0.0);
		float ringa = 0.0;
		if (ring > 0.5 && ringr > 1.35 && ringr < 2.2) {
			float bands = 0.55 + 0.45 * sin(ringr * 38.0);
			ringc = mix(moon_color, vec3(1.0), 0.35) * bands;
			ringa = 0.75 * smoothstep(1.35, 1.5, ringr) * smoothstep(2.2, 2.05, ringr);
		}
		if (pr < 1.0) {
			vec3 nrm = vec3(p / R, sqrt(max(1.0 - pr * pr, 0.0)));
			float lit = clamp(dot(nrm, normalize(vec3(0.6, 0.5, 0.6))), 0.0, 1.0);
			float bandsp = 0.8 + 0.2 * sin(p.y / R * 9.0 + vnoise(p * 20.0) * 3.0);
			vec3 pc = moon_color * bandsp * (0.12 + 0.88 * lit);
			if (!(front_ring && ringa > 0.0)) {
				col = mix(col, pc, smoothstep(1.0, 0.97, pr));
			} else {
				col = mix(mix(col, pc, smoothstep(1.0, 0.97, pr)), ringc, ringa);
			}
		} else if (ringa > 0.0) {
			col = mix(col, ringc, ringa);
		}
		col += moon_color * pow(max(mz, 0.0), 300.0) * 0.15;
	}
	// cloud bands (not in space)
	if (clouds > 0.5 && space < 0.5 && h > 0.02) {
		vec2 cp = d.xz / (h + 0.15) * 1.5 + vec2(time_s * 0.01, 0.0);
		// cloud_style: 0 = puffy, 1 = long streaks (hot/dusty worlds), 2 = thin icy wisps
		if (cloud_style > 0.5) {
			cp *= cloud_style > 1.5 ? vec2(0.6, 3.0) : vec2(0.45, 2.2);
		}
		float c = vnoise(cp) * 0.65 + vnoise(cp * 2.3) * 0.35;
		c = smoothstep(cloud_style > 1.5 ? 0.62 : 0.55, 0.85, c) * smoothstep(0.02, 0.25, h);
		vec3 cc = mix(horizon_color * 1.2, vec3(0.08, 0.06, 0.14), n);
		col = mix(col, cc, c * 0.55);
	}
	col = mix(col, storm_color * (1.0 - n * 0.8), storm * 0.85);
	if (space < 0.5) {
		col = mix(col, fog_color, smoothstep(0.14, -0.02, h) * 0.9);
	}
	col *= grade_tint;
	float gl = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(gl), col, grade_sat);
	col = max((col - 0.45) * grade_contrast + 0.45, vec3(0.0));
	COLOR = col;
}
