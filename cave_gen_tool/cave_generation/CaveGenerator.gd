@tool
extends Node3D
class_name CaveGenerator

signal finish_gen

@export var can_generate := false

@export var voxel_terrain : Voxel
var voxel_tool : VoxelTool

@export var show_walker : bool = true
@export var walkers : Array[CaveWalker] = []
var current_walker : CaveWalker
var last_walker : CaveWalker

var current_walker_index : int = 0
@export var ceiling_thickness_m : int = 5
@export var do_wall_decoration_step : bool = true
@export var do_voxel_addition : bool = true

var random_walk_positions : Array[Vector3] = []
var affected_voxels: Array[Vector3] = []
var noise : FastNoiseLite


#func _ready() -> void:
	#if not can_generate: return
	#setup()
	#if show_walker and current_walker:
		#current_walker.show()
	#await get_tree().physics_frame
	#random_walk()

func generate() -> void:
	setup()
	random_walk()

func setup():
	current_walker = walkers[0]
	last_walker = current_walker
	#current_walker.global_position = global_position
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.03
	noise.fractal_octaves = 3

func finish_walk():
	#current_walker.queue_free()
	last_walker = current_walker
	current_walker_index += 1
	if current_walker_index < walkers.size():
		current_walker = walkers[current_walker_index]
		random_walk()
	else:
		set_voxel_meta_data()
		finish_gen.emit()
	random_walk_positions.clear()
	affected_voxels.clear()

func random_walk():
	if not current_walker:
		return

	for i in range(current_walker.random_walk_length):
		current_walker.global_position += get_random_direction()
		current_walker.global_position.y = clampf(
			current_walker.global_position.y,
			-1000,
			voxel_terrain.generator.height - ceiling_thickness_m)

		if i % 2 == 0:
			random_walk_positions.append(current_walker.global_position)

		if current_walker.display_speed > 0:
			await get_tree().create_timer(current_walker.display_speed).timeout

		# Carve out a chunk
		do_sphere_removal()

		# Add rock formations or walls occasionally
		if do_voxel_addition:
			var wall_point = get_random_wall_point()
			if wall_point:
				current_walker.ray.look_at(wall_point)
				do_sphere_addition(true, wall_point)

	if do_wall_decoration_step:
		wall_additions_pass()

func wall_additions_pass():
	for walk_position : Vector3 in random_walk_positions:
		if current_walker.display_speed > 0:
			await get_tree().create_timer(current_walker.display_speed).timeout

		var raycast_result : VoxelRaycastResult = voxel_tool.raycast(walk_position, get_random_direction(true), 20)
		if not raycast_result:
			continue

		current_walker.global_position = walk_position
	finish_walk()

func do_sphere_removal():
	var radius = get_removal_size()
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.do_sphere(current_walker.global_position, radius)

	# record all voxels near the surface
	var voxel_center = Vector3(CaveConstants.world_to_voxel(voxel_terrain, current_walker.global_position))
	var int_r = radius
	for x in range(-int_r, int_r + 1):
		for y in range(-int_r, int_r + 1):
			for z in range(-int_r, int_r + 1):
				var voxel_pos = voxel_center + Vector3(x, y, z)
				if Vector3(x, y, z).length() <= radius:
					if not affected_voxels.has(voxel_pos):
						affected_voxels.append(voxel_pos)

func do_sphere_addition(at_point: bool = false, global_point: Vector3 = Vector3.ZERO):
	voxel_tool.mode = VoxelTool.MODE_ADD

	var pos: Vector3
	if at_point:
		pos = global_point
	else:
		pos = current_walker.global_position

	voxel_tool.do_sphere(pos, get_removal_size(1) / 2.0)

func set_voxel_meta_data():
	if affected_voxels.is_empty():
		return

	voxel_tool.mode = VoxelTool.MODE_TEXTURE_PAINT
	voxel_tool.texture_opacity = 1.0
	voxel_tool.texture_falloff = 0.0  # no blending

	for voxel_pos in affected_voxels:
		paint_voxel_and_neighbors(voxel_pos, 1.0)

func paint_voxel_and_neighbors(voxel_pos: Vector3i, radius: float):
	if voxel_tool.get_voxel(voxel_pos) == 0:
		return

	var meta = voxel_tool.get_voxel_metadata(voxel_pos)
	var tex_id = get_texture_for_height(voxel_pos.y)

	if meta == null or not meta.has("id"):
		voxel_tool.set_voxel_metadata(voxel_pos, {
			"id": tex_id,
			"pos": voxel_pos,
			"damage": 0
		})

		voxel_tool.texture_index = tex_id
		var world_pos = voxel_terrain.to_global(Vector3(voxel_pos)) # + Vector3.ONE * 0.5
		voxel_tool.do_sphere(world_pos, radius)

	var neighbors = CaveConstants.get_nearby_voxel_positions(voxel_pos)
	for n_pos in neighbors:
		var n_meta = voxel_tool.get_voxel_metadata(n_pos)
		if n_meta == null or not n_meta.has("id"):
			var n_tex_id = tex_id
			if voxel_terrain.voxel_data.size() > tex_id:
				var voxel_data = voxel_terrain.voxel_data[tex_id]
				if voxel_data and voxel_data.neighbor_chances.size() > 0:
					n_tex_id = voxel_data.get_random_neighbor()

			voxel_tool.set_voxel_metadata(n_pos, {
				"id": n_tex_id,
				"pos": n_pos,
				"damage": 0
			})
			voxel_tool.texture_index = voxel_terrain.voxel_data[n_tex_id].texture_index
			var n_world_pos = voxel_terrain.to_global(Vector3(n_pos)) # + Vector3.ONE * 0.5
			voxel_tool.do_sphere(n_world_pos, radius)

func get_texture_for_height(y: float) -> int:
	if y > -2:
		return  voxel_terrain.voxel_data.size() - 1# none

	var matching_voxels: Array = []
	for v in voxel_terrain.voxel_data:
		if y >= v.min_height and y <= v.max_height:
			matching_voxels.append(v)

	if matching_voxels.size() > 0:
		var chosen: CaveVoxelData = matching_voxels.pick_random()
		return chosen.texture_index

	return voxel_terrain.voxel_data[0].texture_index

func get_voxel_data_for_height(y: float) -> CaveVoxelData:
	for v in voxel_terrain.voxel_data:
		if y >= v.min_height and y <= v.max_height:
			return v
	return null

func get_removal_size(variance : float = 1.0) -> float:
	var removal_size : float = current_walker.removal_size
	return removal_size + randf_range(-removal_size * variance, removal_size * variance)

func get_random_wall_point() -> Vector3:
	var raycast_result : VoxelRaycastResult = voxel_tool.raycast(current_walker.global_position, get_random_direction(true), 20)
	if raycast_result:
		return raycast_result.position
	return Vector3.ZERO

func get_random_direction(use_float : bool = true) -> Vector3:
	if use_float:
		return current_walker.get_walker_range()
	return Vector3(
		[-1, 0, 1].pick_random(),
		[-1, 0, 1].pick_random(),
		[-1, 0, 1].pick_random())
