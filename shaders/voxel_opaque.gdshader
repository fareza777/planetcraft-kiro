shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://shaders/voxel_common.gdshaderinc"

void fragment() {
	ALBEDO = shade_terrain(sample_tile(UV), COLOR);
}
