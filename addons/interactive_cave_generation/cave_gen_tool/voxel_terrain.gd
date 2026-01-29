@tool
extends VoxelTerrain
class_name Voxel

@export var texture_dirt : Texture2D
@export var texture_grass : Texture2D
@export var texture_rock : Texture2D
@export var texture_none : Texture2D

@export var voxel_data: Array[CaveVoxelData] = []

func _ready() -> void:
	var texture_2d_array := Texture2DArray.new()
	texture_2d_array.create_from_images([texture_dirt.get_image(), texture_grass.get_image(), texture_rock.get_image(), texture_none.get_image()])
	material_override.set("shader_parameter/u_texture_array", texture_2d_array)
