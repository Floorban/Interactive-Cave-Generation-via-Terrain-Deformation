@tool
extends VBoxContainer

const TERRAIN = preload("uid://dspkvmg4oah8m")
const CAVE_GENERATOR = preload("uid://hik4wbxfsq2p")
const CAMERA = preload("uid://jhfruvrqqktf")

var undo_redo : EditorUndoRedoManager

@onready var button_generate: Button = %ButtonGenerate
@onready var button_undo_gen: Button = %ButtonUndo
@onready var button_clear: Button = %ButtonClear

@onready var cave_decor_obj: CaveResourcePicker = $CaveResourcePicker
@onready var button_clear_decor: Button = %ButtonClearDecor
@onready var button_undo_decor: Button = %ButtonUndoDecor
@onready var button_decorate: Button = %ButtonDecorate

func _ready() -> void:
	button_generate.pressed.connect(_on_generate_pressed)
	button_undo_gen.pressed.connect(_on_gen_undo_pressed)
	button_clear.pressed.connect(_on_clear_pressed)
	button_decorate.pressed.connect(_on_decorate_pressed)

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

func _spawn_player_camera(free_cam: bool) -> void:
	if get_current_scene() == null: return
	var scene_root = get_current_scene()
	if free_cam:
		var camera = CAMERA.instantiate()
		scene_root.add_child(camera)
		camera.owner = scene_root
		camera.name = "FlyingCamera"

func _on_generate_pressed() -> void:
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

func _on_decorate_pressed() -> void:
	if get_current_scene() == null: return
	var scene_root = get_current_scene()
	if cave_decor_obj.edited_resource:
		var generator = get_tree().get_first_node_in_group("generator")
		spawn_objects_from_markers(generator, cave_decor_obj.edited_resource)
	else:
		print("no obj selected")

func get_current_scene():
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		push_warning("No active scene found")
		return null
	return scene_root

func spawn_objects_from_markers(generator: CaveGenerator, obj_scene: PackedScene):
	for pos in generator.wall_marker_positions:
		var obj = obj_scene.instantiate()
		generator.add_child(obj)
		obj.owner = generator.owner
		obj.name = "Rock"
		obj.global_position = pos
