@tool
extends VoxelTerrain
class_name Voxel

signal voxel_removed(removed_pos: Vector3)

#@onready var player : PlayerController = get_tree().get_first_node_in_group("player")

@export var texture_rock : Texture2D
@export var texture_grass : Texture2D
@export var texture_dirt : Texture2D
@export var texture_none : Texture2D

@export var voxel_data: Array[CaveVoxelData] = []

func _ready() -> void:
	var texture_2d_array := Texture2DArray.new()
	texture_2d_array.create_from_images([texture_rock.get_image(), texture_grass.get_image(), texture_dirt.get_image(), texture_none.get_image()])
	material_override.set("shader_parameter/u_texture_array", texture_2d_array)
	#if player: player.connect("voxel_dug", Callable(self, "_on_player_dug_voxel"))

func _on_player_dug_voxel(removed_pos: Vector3):
	emit_signal("voxel_removed", removed_pos)
