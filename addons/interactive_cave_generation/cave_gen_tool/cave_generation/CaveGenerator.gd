@tool
extends Node3D
class_name CaveGenerator

signal finish_gen

@export var can_generate := false

@export var voxel_terrain : Voxel
var voxel_tool : VoxelTool

@export var show_walker : bool = true
@export var walkers : Array[CaveWalker] = []
@export var current_walker : CaveWalker
var last_walker : CaveWalker

var current_walker_index : int = 0
@export var ceiling_thickness_m : int = 5
@export var do_wall_decoration_step : bool = true
@export var do_voxel_addition : bool = true

var random_walk_positions : Array[Vector3] = []
var affected_voxels: Array[Vector3] = []
var undo_voxel_cache := {}  # Dictionary<Vector3i, int>
var generation_stack: Array = []
var current_generation := {}  # Dictionary<Vector3i, int>
var noise : FastNoiseLite

#func _ready() -> void:
	#if not can_generate: return
	#setup()
	#if show_walker and current_walker:
		#current_walker.show()
	#await get_tree().physics_frame
	#random_walk()

func get_valid_walkers() -> Array[CaveWalker]:
	var result: Array[CaveWalker] = []
	for w in walkers:
		if w != null and is_instance_valid(w):
			result.append(w)
	return result

func setup():
	if voxel_terrain == null:
		push_error("Voxel terrain not assigned")
		return

	voxel_tool = voxel_terrain.get_voxel_tool()

	var valid_walkers = get_valid_walkers()
	if valid_walkers.is_empty():
		push_error("CaveGenerator: No valid walkers assigned")
		return

	walkers = valid_walkers
	current_walker_index = 0
	current_walker = walkers[0]
	last_walker = current_walker
	#current_walker.global_position = global_position
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.03
	noise.fractal_octaves = 3

func generate() -> void:
	setup()
	if current_walker == null:
		return

	current_generation = {
		"spheres": [],
		"walker_start_pos": current_walker.global_position
	}
	generation_stack.append(current_generation)

	#current_walker_index = 0
	#current_walker = walkers[0]

	random_walk_positions.clear()
	affected_voxels.clear()
	wall_marker_positions.clear()

	random_walk()

func undo_generate() -> void:
	if generation_stack.is_empty():
		print("No generation to undo")
		return

	var last_generation = generation_stack.pop_back()
	var spheres : Array = last_generation["spheres"]

	# Restore voxels
	voxel_tool.mode = VoxelTool.MODE_ADD
	for i in range(spheres.size() - 1, -1, -1):
		var s = spheres[i]
		voxel_tool.do_sphere(s["pos"], s["radius"])

	# Restore walker state
	current_walker_index = 0
	current_walker = walkers[0]
	current_walker.global_position = last_generation["walker_start_pos"]

	print("Reverted last cave generation")

func reset_walkers():
	current_walker_index = 0
	current_walker = walkers[0]
	current_walker.global_position = global_position

func finish_walk():
	last_walker = current_walker
	current_walker_index += 1

	if current_walker_index < walkers.size():
		current_walker = walkers[current_walker_index]
		random_walk()
	else:
		set_voxel_meta_data()
		finish_gen.emit()
		current_walker_index = 0
		current_walker = walkers[0]
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
	var pos = current_walker.global_position

	# Record the operation
	current_generation["spheres"].append({
		"pos": pos,
		"radius": radius
	})

	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.do_sphere(pos, radius)

func do_sphere_addition(at_point: bool = false, global_point: Vector3 = Vector3.ZERO):
	voxel_tool.mode = VoxelTool.MODE_ADD

	var pos: Vector3
	if at_point:
		pos = global_point
	else:
		pos = current_walker.global_position

	voxel_tool.do_sphere(pos, get_removal_size(1) / 2.0)

func set_voxel_meta_data():
	if random_walk_positions.is_empty():
		return

	voxel_tool.mode = VoxelTool.MODE_TEXTURE_PAINT
	voxel_tool.texture_opacity = 1.0
	voxel_tool.texture_falloff = 0.0  # no blending

	for voxel_pos in random_walk_positions:
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
		voxel_tool.do_sphere(world_pos, 2.5)

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

	return voxel_terrain.voxel_data[1].texture_index

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
