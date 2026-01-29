@tool
extends VBoxContainer

const TERRAIN = preload("uid://dspkvmg4oah8m")
const CAVE_GENERATOR = preload("uid://hik4wbxfsq2p")
const CAMERA = preload("uid://jhfruvrqqktf")

var undo_redo : EditorUndoRedoManager

@onready var slider_cave_branch: HSlider = %SliderCaveBranch
@onready var slider_cave_density: HSlider = %SliderCaveDensity
@onready var slider_cave_size: HSlider = %SliderCaveSize
@onready var slider_cave_length: HSlider = %SliderCaveLength
@onready var slider_cave_dir_x: HSlider = %SliderCaveDirX
@onready var slider_cave_dir_y: HSlider = %SliderCaveDirY
@onready var slider_cave_dir_z: HSlider = %SliderCaveDirZ

@onready var button_generate: Button = %ButtonGenerate
@onready var button_undo_gen: Button = %ButtonUndo
@onready var button_clear: Button = %ButtonClear

@onready var cave_decor_obj: CaveResourcePicker = $CaveResourcePicker
@onready var button_clear_decor: Button = %ButtonClearDecor
@onready var button_randomize: Button = %ButtonRandomize
@onready var slider_decor_density: HSlider = %SliderDecorDensity
@onready var slider_decor_size: HSlider = %SliderDecorSize
@export var decor_seed: int = 0

@onready var texture_array_editor: TextureArrayEditor = $TextureArrayEditor

func _ready() -> void:
	button_generate.pressed.connect(_on_generate_pressed)
	button_undo_gen.pressed.connect(_on_gen_undo_pressed)
	button_clear.pressed.connect(_on_clear_pressed)
	button_clear_decor.pressed.connect(_on_decor_clear_pressed)
	button_randomize.pressed.connect(_on_randomize_pressed)
	slider_decor_density.value_changed.connect(_on_decorate_pressed)

func assign_textures_to_voxel(voxel: Voxel) -> void:
	if texture_array_editor.textures.size() >= 4:
		voxel.texture_dirt = texture_array_editor.textures[0]
		voxel.texture_grass = texture_array_editor.textures[1]
		voxel.texture_rock = texture_array_editor.textures[2]
		voxel.texture_none = texture_array_editor.textures[3]
		voxel.set_texture()
		print("Textures assigned to voxel node")
	else:
		push_warning("Not enough textures in the editor array")

func _set_walker_params() -> void:
	var generator = get_tree().get_first_node_in_group("generator")
	if not generator:
		return
	if generator is CaveGenerator:
		var branch_count := 0
		for walker: CaveWalker in generator.walkers:
			walker.can_walk = true if branch_count < slider_cave_branch.value else false
			branch_count += 1
			walker.removal_size = slider_cave_size.value
			walker.random_walk_length = slider_cave_length.value
			walker.direction = Vector3(slider_cave_dir_x.value, slider_cave_dir_y.value, slider_cave_dir_z.value)

func _init_generator_essentials() -> void:
	if get_current_scene() == null: return
	var scene_root = get_current_scene()
	
	var generator = get_tree().get_first_node_in_group("generator")
	if generator:
		print("generate new layout")
		(generator as CaveGenerator).generate()
		return
		
	var terrian = get_tree().get_first_node_in_group("terrain")
	if not terrian:
		terrian = TERRAIN.instantiate()
		scene_root.add_child(terrian)
		terrian.owner = scene_root
		terrian.name = "Terrian"
	
	generator = CAVE_GENERATOR.instantiate()
	scene_root.add_child(generator)
	generator.owner = scene_root
	generator.name = "CaveGenerator"
	(generator as CaveGenerator).voxel_terrain = terrian
	(generator as CaveGenerator).voxel_tool = terrian.get_voxel_tool()
	(generator as CaveGenerator).generate()
	print("Start generating")

func spawn_decor_objects(generator: CaveGenerator, obj_scene: PackedScene):
	var rng = RandomNumberGenerator.new()
	rng.seed = decor_seed
	
	for pos in generator.wall_marker_positions:
		if rng.randf() * slider_decor_density.max_value < slider_decor_density.value:
			var obj = obj_scene.instantiate()
			generator.decoration.add_child(obj)
			obj.owner = generator.owner
			obj.name = "Rock"
			obj.global_position = pos
			obj.rotation_degrees = Vector3(
				rng.randf_range(0, 360),
				rng.randf_range(0, 360),
				rng.randf_range(0, 360)
			)
			var scale_factor = slider_decor_size.value + rng.randf_range(-0.2, .2)
			obj.scale = Vector3.ONE * scale_factor

func clear_decor_objects() -> void:
	var generator = get_tree().get_first_node_in_group("generator")
	if generator is CaveGenerator:
		for o in generator.decoration.get_children():
			o.queue_free()

func _spawn_player_camera(free_cam: bool) -> void:
	if get_current_scene() == null: return
	var scene_root = get_current_scene()
	if free_cam:
		var camera = CAMERA.instantiate()
		scene_root.add_child(camera)
		camera.owner = scene_root
		camera.name = "FlyingCamera"

func _on_generate_pressed() -> void:
	var terrian = get_tree().get_first_node_in_group("terrain")
	if terrian:	assign_textures_to_voxel((terrian as Voxel))
	_set_walker_params()
	_init_generator_essentials()
	#undo_redo.create_action("Cave Generation: Has Random Walked")
	#undo_redo.add_do_property(  "Cave Generation: Cave Generated")
	#undo_redo.add_undo_property("Cave Generation: Cave Generated")
	#undo_redo.commit_action()

func _on_gen_undo_pressed() -> void:
	var generator = get_tree().get_first_node_in_group("generator")
	if generator is CaveGenerator:
		generator.undo_generate()
	#if get_current_scene() == null: return
	#var scene_root = get_current_scene()
	#
	#var terrian = get_tree().get_first_node_in_group("terrain")
	#if terrian: 
		#terrian.queue_free()
	#
	#var new_terrian = TERRAIN.instantiate()
	#scene_root.add_child(new_terrian)
	#new_terrian.owner = scene_root
	#new_terrian.name = "Terrian"
	#
	#var generator = get_tree().get_first_node_in_group("generator")
	#if generator is CaveGenerator:
		#generator.voxel_terrain = new_terrian
		#generator.voxel_tool = new_terrian.get_voxel_tool()
		#generator.undo_generate()
		#print("clear caves")

func _on_clear_pressed() -> void:
	var terrian = get_tree().get_first_node_in_group("terrain")
	if terrian: terrian.queue_free()
	var generator = get_tree().get_first_node_in_group("generator")
	if generator is CaveGenerator: 
		generator.queue_free()

func _on_decorate_pressed(value) -> void:
	if get_current_scene() == null: return
	var scene_root = get_current_scene()
	if cave_decor_obj.edited_resource:
		clear_decor_objects()
		var generator = get_tree().get_first_node_in_group("generator")
		spawn_decor_objects(generator, cave_decor_obj.edited_resource)
	else:
		print("no obj selected")

func _on_decor_clear_pressed() -> void:
	clear_decor_objects()

func _on_randomize_pressed() -> void:
	decor_seed = randi()
	_on_decorate_pressed(slider_decor_density.value)
	print("New decor seed:", decor_seed)

func get_current_scene():
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		push_warning("No active scene found")
		return null
	return scene_root
