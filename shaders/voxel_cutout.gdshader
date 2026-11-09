shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://shaders/voxel_common.gdshaderinc"

void fragment() {
	vec4 t = sample_tile(UV);
	if (t.a < 0.5) {
		discard;
	}
	vec3 col = COLOR.b > 0.5 ? t.rgb * emissive_boost * (0.82 + 0.18 * sin(time_s * 2.2 + wpos.x * 0.45 + wpos.y * 0.7 + wpos.z * 0.3)) : t.rgb * terrain_light(COLOR.r);
	ALBEDO = col;
}
