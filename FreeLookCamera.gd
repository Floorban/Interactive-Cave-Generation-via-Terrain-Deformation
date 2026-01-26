class_name FreeLookCamera extends Camera3D

# Modifier keys' speed multiplier
const SHIFT_MULTIPLIER = 2.5
const ALT_MULTIPLIER = 1.0 / SHIFT_MULTIPLIER

@export_range(0.0, 1.0) var sensitivity: float = 0.25

# Mouse state
var _mouse_position = Vector2(0.0, 0.0)
var _total_pitch = 0.0

# Movement state
var _direction = Vector3(0.0, 0.0, 0.0)
var _velocity = Vector3(0.0, 0.0, 0.0)
var _acceleration = 30
var _deceleration = -10
var _vel_multiplier = 4

# Keyboard state
var _w = false
var _s = false
var _a = false
var _d = false
var _q = false
var _e = false
var _shift = false
var _alt = false

signal voxel_dug(world_pos: Vector3)
@export var voxel_terrain : Voxel
@onready var voxel_tool : VoxelTool = voxel_terrain.get_voxel_tool()
@onready var dig_cast : RayCast3D = $DigCast

func _process(delta: float) -> void:
	_update_mouselook()
	_update_movement(delta)

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
		# print("wrong tool, need:", voxel_data.tool_type)
		return

	# get current damage
	var damage: int = 0
	if meta != null and meta.has("damage"):
		damage = meta["damage"]

	damage += 1 # TODO: add tool power

	# print("ID:", voxel_id, " Current damage:", damage, " Max HP:", voxel_data.base_hp)

	if damage >= voxel_data.base_hp:
		# fully destroyed
		voxel_tool.mode = VoxelTool.MODE_REMOVE
		voxel_tool.do_sphere(voxel_pos, radius)
		voxel_tool.set_voxel_metadata(voxel_pos, null)
		paint_neighbor(voxel_pos, radius*0.85, voxel_data)
		emit_signal("voxel_dug", world_pos)
	else:
		# update meta and repaint cracked voxel
		voxel_tool.set_voxel_metadata(voxel_pos, {
			"id": voxel_id,
			"pos": voxel_pos,
			"damage": damage,
		})

		# voxel_tool.mode = VoxelTool.MODE_TEXTURE_PAINT
		# voxel_tool.texture_index = voxel_data.texture_index
		# voxel_tool.do_sphere(world_pos, 0.1)

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
			mine_voxel(collision_point, 0.9, "pickaxe")
	# Receives mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = event.relative
	
	# Receives mouse button input
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT: # Only allows rotation if right click down
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
			MOUSE_BUTTON_WHEEL_UP: # Increases max velocity
				_vel_multiplier = clamp(_vel_multiplier * 1.1, 0.2, 20)
			MOUSE_BUTTON_WHEEL_DOWN: # Decereases max velocity
				_vel_multiplier = clamp(_vel_multiplier / 1.1, 0.2, 20)

	# Receives key input
	if event is InputEventKey:
		match event.keycode:
			KEY_W:
				_w = event.pressed
			KEY_S:
				_s = event.pressed
			KEY_A:
				_a = event.pressed
			KEY_D:
				_d = event.pressed
			KEY_Q:
				_q = event.pressed
			KEY_E:
				_e = event.pressed
			KEY_SHIFT:
				_shift = event.pressed
			KEY_ALT:
				_alt = event.pressed

# Updates camera movement
func _update_movement(delta):
	# Computes desired direction from key states
	_direction = Vector3(
		(_d as float) - (_a as float), 
		(_e as float) - (_q as float),
		(_s as float) - (_w as float)
	)
	
	# Computes the change in velocity due to desired direction and "drag"
	# The "drag" is a constant acceleration on the camera to bring it's velocity to 0
	var offset = _direction.normalized() * _acceleration * _vel_multiplier * delta \
		+ _velocity.normalized() * _deceleration * _vel_multiplier * delta
	
	# Compute modifiers' speed multiplier
	var speed_multi = 1
	if _shift: speed_multi *= SHIFT_MULTIPLIER
	if _alt: speed_multi *= ALT_MULTIPLIER
	
	# Checks if we should bother translating the camera
	if _direction == Vector3.ZERO and offset.length_squared() > _velocity.length_squared():
		# Sets the velocity to 0 to prevent jittering due to imperfect deceleration
		_velocity = Vector3.ZERO
	else:
		# Clamps speed to stay within maximum value (_vel_multiplier)
		_velocity.x = clamp(_velocity.x + offset.x, -_vel_multiplier, _vel_multiplier)
		_velocity.y = clamp(_velocity.y + offset.y, -_vel_multiplier, _vel_multiplier)
		_velocity.z = clamp(_velocity.z + offset.z, -_vel_multiplier, _vel_multiplier)
	
		translate(_velocity * delta * speed_multi)

# Updates mouse look 
func _update_mouselook():
	# Only rotates mouse if the mouse is captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_position *= sensitivity
		var yaw = _mouse_position.x
		var pitch = _mouse_position.y
		_mouse_position = Vector2(0, 0)
		
		# Prevents looking up/down too far
		pitch = clamp(pitch, -90 - _total_pitch, 90 - _total_pitch)
		_total_pitch += pitch
	
		rotate_y(deg_to_rad(-yaw))
		rotate_object_local(Vector3(1,0,0), deg_to_rad(-pitch))
