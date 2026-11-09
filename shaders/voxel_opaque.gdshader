shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://shaders/voxel_common.gdshaderinc"

void fragment() {
	vec4 t = sample_tile(UV);
	vec3 col = COLOR.b > 0.5 ? t.rgb * emissive_boost : t.rgb * terrain_light(COLOR.r);
	ALBEDO = col;
}
