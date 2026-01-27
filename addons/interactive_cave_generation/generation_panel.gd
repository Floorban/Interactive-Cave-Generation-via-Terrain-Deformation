@tool
extends VBoxContainer

const TERRAIN = preload("uid://dspkvmg4oah8m")
const CAVE_GENERATOR = preload("uid://hik4wbxfsq2p")
const CAMERA = preload("uid://jhfruvrqqktf")

@onready var button_generate: Button = %ButtonGenerate
@onready var button_clear: Button = %ButtonClear

func _ready() -> void:
	button_generate.pressed.connect(_on_generate_pressed)
	button_clear.pressed.connect(_on_clear_pressed)

func _on_generate_pressed() -> void:
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		push_warning("No active scene to add to.")
		return
	var terrian = TERRAIN.instantiate()
	var generator = CAVE_GENERATOR.instantiate()
	var camera = CAMERA.instantiate()
	scene_root.add_child(terrian)
	scene_root.add_child(generator)
	scene_root.add_child(camera)
	terrian.owner = scene_root
	generator.owner = scene_root
	camera.owner = scene_root
	terrian.name = "Terrian"
	generator.name = "CaveGenerator"
	camera.name = "FlyingCamera"
	print("Start generating")

func _on_clear_pressed() -> void:
	print("clear caves")
