@tool
extends MeshInstance3D
class_name CaveWalker

@onready var ray : RayCast3D = $DebugRaycast

@export var random_walk_length : int = 100
@export var removal_size : float = 4.0
@export var display_speed : float = 0.01

var dir_x: float = 0
var dir_y: float = 0
var dir_z: float = 0

@export var x_range : Vector2 = Vector2(-0.5,0.5)
@export var y_range : Vector2 = Vector2(-0.5,0)
@export var z_range : Vector2 = Vector2(-0.5,0.5)

func get_walker_range() -> Vector3:
	return Vector3(
		dir_x + randf_range(x_range.x, x_range.y),
		dir_y + randf_range(y_range.x, y_range.y),
		dir_z + randf_range(z_range.x, z_range.y))
