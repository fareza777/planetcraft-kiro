class_name FarLod
extends MeshInstance3D
## Low-detail far-terrain horizon mesh (1 cell = 4x4 blocks) rendered beyond the voxel
## chunk ring. One single draw call; rebuilt only when the player moves > 32 blocks.

const STEP := 4
const RING_OUT := 220

var gen: VoxelWorld.Gen
var planet: Dictionary
var _last_center := Vector2i(1 << 30, 1 << 30)
var _mat: StandardMaterial3D


func setup(g: VoxelWorld.Gen, p: Dictionary) -> void:
	gen = g
	planet = p
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _mat


func update_around(pos: Vector3, inner_radius: float, sky_light: Color) -> void:
	visible = Game.settings.get("far_lod", true) and planet.get("type", "terrain") == "terrain"
	if not visible or gen == null:
		return
	_mat.albedo_color = sky_light
	var ck := Vector2i(int(floor(pos.x / 32.0)) * 32, int(floor(pos.z / 32.0)) * 32)
	if ck == _last_center:
		return
	_last_center = ck
	_rebuild(ck.x, ck.y, inner_radius)


func _rebuild(cx: int, cz: int, inner_r: float) -> void:
	var outer := int(clampf(inner_r * 2.2, 128.0, float(RING_OUT)))
	var half := outer / STEP
	var side := half * 2 + 1
	var hs := PackedFloat32Array()
	var cs := PackedColorArray()
	hs.resize(side * side)
	cs.resize(side * side)
	var sea := float(planet.get("sea_level", 0))
	var fluid_id: int = gen.fluid
	var fluid_col := Reg.block_color(fluid_id) if fluid_id > 0 else Color(0.15, 0.35, 0.55)
	var biomes: Array = gen.biomes
	for gz in side:
		var wz := cz + (gz - half) * STEP
		for gx in side:
			var wx := cx + (gx - half) * STEP
			var col := gen.column(wx, wz)
			var h := float(col[0]) - 0.6
			var bcol := Color(0.4, 0.45, 0.5)
			if h < sea and fluid_id > 0:
				h = sea - 0.25
				bcol = fluid_col
			elif int(col[1]) < biomes.size():
				bcol = Reg.block_color(int(biomes[int(col[1])].surface_id))
			var idx := gx + gz * side
			hs[idx] = h
			cs[idx] = bcol
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var indices := PackedInt32Array()
	var inner_sq := maxf(inner_r - 12.0, 24.0)
	inner_sq *= inner_sq
	var outer_sq := float(outer * outer)
	for gz in side - 1:
		var wz0 := float(cz + (gz - half) * STEP)
		for gx in side - 1:
			var wx0 := float(cx + (gx - half) * STEP)
			var dx := wx0 + STEP * 0.5 - float(cx)
			var dz := wz0 + STEP * 0.5 - float(cz)
			var d2 := dx * dx + dz * dz
			if d2 < inner_sq or d2 > outer_sq:
				continue
			var i00 := gx + gz * side
			var i10 := i00 + 1
			var i01 := i00 + side
			var i11 := i01 + 1
			var s := verts.size()
			verts.append(Vector3(wx0, hs[i00], wz0))
			verts.append(Vector3(wx0 + STEP, hs[i10], wz0))
			verts.append(Vector3(wx0 + STEP, hs[i11], wz0 + STEP))
			verts.append(Vector3(wx0, hs[i01], wz0 + STEP))
			var shade := clampf(0.82 + (hs[i00] - hs[i11]) * 0.04, 0.65, 1.15)
			cols.append(cs[i00] * shade)
			cols.append(cs[i10] * shade)
			cols.append(cs[i11] * shade)
			cols.append(cs[i01] * shade)
			indices.append_array([s, s + 1, s + 2, s, s + 2, s + 3])
	if verts.is_empty():
		mesh = null
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = am
