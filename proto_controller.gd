# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

@onready var dig_cast: RayCast3D = %DigCast

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

@onready var voxel_terrain : Voxel = get_tree().get_first_node_in_group("terrain")
@onready var voxel_tool : VoxelTool = voxel_terrain.get_voxel_tool() if voxel_terrain else null

func mine_voxel(world_pos: Vector3, radius: float, tool_type: String):
	var voxel_pos: Vector3 = CaveConstants.world_to_voxel(voxel_terrain, world_pos)
	var meta = voxel_tool.get_voxel_metadata(voxel_pos)
	var voxel_id: int = 0

	if meta != null and meta.has("id"):
		voxel_id = meta["id"]
	else:
		var dist_xz = Vector2(voxel_pos.x, voxel_pos.z).distance_to(Vector2(voxel_terrain.global_position.x, voxel_terrain.global_position.z))

		if voxel_pos.y < -50:
			voxel_id = voxel_terrain.voxel_data.size() - 1
		elif voxel_pos.y < -30 or voxel_pos.y >= -1:
			voxel_id = 0  # rock
		elif dist_xz < CaveConstants.LAYER_RANGE[1].y:
			voxel_id = 1  # grass
		elif dist_xz < CaveConstants.LAYER_RANGE[2].y:
			voxel_id = 2  # dirt
		else:
			voxel_id = 0  # rock

	# check id
	if voxel_id < 0 or voxel_id >= voxel_terrain.voxel_data.size():
		print("invalid voxel id:", voxel_id)
		return

	# get voxel data
	var voxel_data: CaveVoxelData = voxel_terrain.voxel_data[voxel_id]

	# check tool type
	if voxel_data.tool_type != "" and voxel_data.tool_type != tool_type:
		print("wrong tool, need:", voxel_data.tool_type)
		return

	var damage: int = 0
	if meta != null and meta.has("damage"):
		damage = meta["damage"]
	damage += 1

	if damage >= voxel_data.base_hp:
		# fully destroyed
		voxel_tool.mode = VoxelTool.MODE_REMOVE
		voxel_tool.do_sphere(voxel_pos, radius)
		voxel_tool.set_voxel_metadata(voxel_pos, null)
		paint_neighbor(voxel_pos, radius*0.85, voxel_data)
	else:
		# update meta and repaint cracked voxel
		voxel_tool.set_voxel_metadata(voxel_pos, {
			"id": voxel_id,
			"pos": voxel_pos,
			"damage": damage,
		})

		#voxel_tool.mode = VoxelTool.MODE_TEXTURE_PAINT
		#voxel_tool.texture_index = voxel_data.texture_index
		#voxel_tool.do_sphere(world_pos, 0.1)

func paint_neighbor(center_pos: Vector3i, radius: float, voxel_data: CaveVoxelData):
	var neighbors = CaveConstants.get_nearby_voxel_positions(center_pos)
	voxel_tool.mode = VoxelTool.MODE_TEXTURE_PAINT
	voxel_tool.texture_opacity = 1.0
	voxel_tool.texture_falloff = 0.0  # no blending
	var random_neighbor = voxel_data.get_random_neighbor()

	for n_pos in neighbors:
		var n_voxel = voxel_tool.get_voxel(n_pos)
		if n_voxel == 0:
			continue
		var n_meta = voxel_tool.get_voxel_metadata(n_pos)
		if n_meta != null and n_meta.has("id"):
			continue

		var dist_xz = Vector2(n_pos.x, n_pos.z).distance_to(Vector2(voxel_terrain.global_position.x, voxel_terrain.global_position.z))
		var layer_tex_id = get_texture_for_horizontal_distance(dist_xz)
		if dist_xz <= CaveConstants.LAYER_RANGE[1].x:
			layer_tex_id = random_neighbor
		elif dist_xz > CaveConstants.LAYER_RANGE[0].y:
			layer_tex_id = voxel_terrain.voxel_data.size() - 1
		elif n_pos.y < -50:
			layer_tex_id = voxel_terrain.voxel_data.size() - 1
		elif n_pos.y < -30:
			layer_tex_id = 0

		if layer_tex_id < 0 or layer_tex_id >= voxel_terrain.voxel_data.size():
			continue

		voxel_tool.set_voxel_metadata(n_pos, {
			"id": layer_tex_id,
			"pos": n_pos,
			"damage": 0
		})

		var target_voxel_data: CaveVoxelData = voxel_terrain.voxel_data[layer_tex_id]
		voxel_tool.texture_index = target_voxel_data.texture_index
		voxel_tool.do_sphere(n_pos, radius)

func get_texture_for_horizontal_distance(dist_xz: float) -> int:
	for i in range(CaveConstants.LAYER_RANGE.size()):
		var _range = CaveConstants.LAYER_RANGE[i]
		if dist_xz >= abs(_range.x) and dist_xz <= abs(_range.y):
			if i < voxel_terrain.voxel_data.size():
				return voxel_terrain.voxel_data[i].texture_index
			break
	return voxel_terrain.voxel_data[0].texture_index

func _input(event):
	if Input.is_action_pressed("dig"):
		if dig_cast.is_colliding():
			var collision_point: Vector3 = dig_cast.get_collision_point()
			mine_voxel(collision_point, 1.0, "pickaxe")

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0
	
	# Use velocity to actually move
	move_and_slide()


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
