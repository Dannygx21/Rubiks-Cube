extends Node3D

const COLORS = {
	0: Color(1.0, 1.0, 1.0),
	1: Color(1.0, 1.0, 0.0),
	2: Color(0.0, 0.8, 0.0),
	3: Color(0.0, 0.0, 1.0),
	4: Color(1.0, 0.5, 0.0),
	5: Color(1.0, 0.0, 0.0),
}

const CUBIE_SIZE     = 0.95
const CUBIE_OFFSET   = 1.0
const STICKER_SIZE   = 0.85
const STICKER_OFFSET = 0.476
const ANIM_DURATION  = 0.15

# Local-space normal direction for each spawn face's sticker quad.
# Used to compute world-space face direction after the cubie has rotated.
const STICKER_DIR = {
	"U": Vector3(0,  1,  0),
	"D": Vector3(0, -1,  0),
	"F": Vector3(0,  0,  1),
	"B": Vector3(0,  0, -1),
	"R": Vector3( 1, 0,  0),
	"L": Vector3(-1, 0,  0),
}

var cube_logic: Node

# sticker_map[face][index] = StandardMaterial3D
var sticker_map = {}

# Cubie tracking — needed to identify slice members and rebuild sticker_map after moves
var cubie_nodes: Dictionary = {}     # Vector3i → Node3D (current grid position)
var cubie_stickers: Dictionary = {}  # Node3D  → { spawn_face: material }
var cubie_spawn_pos: Dictionary = {} # Node3D  → Vector3i (original grid position)

# Animation queue
var move_queue: Array = []
var is_animating: bool = false
var active_pivot: Node3D = null
var active_cubies: Array = []

var is_dragging = false
var last_mouse_pos = Vector2.ZERO
var orbit_angles = Vector2(20, 30)
var orbit_distance = 8.0

func _ready():
	cube_logic = load("res://scripts/cube.gd").new()
	add_child(cube_logic)

	for face in ["U", "D", "F", "B", "L", "R"]:
		sticker_map[face] = []
		for i in range(9):
			sticker_map[face].append(null)

	spawn_cubies()
	cube_logic.reset()
	update_colors()
	update_camera()

# ─────────────────────────────────────────
#  Spawn all 26 cubies
# ─────────────────────────────────────────
func spawn_cubies():
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				if x == 0 and y == 0 and z == 0:
					continue
				spawn_cubie(Vector3i(x, y, z))

func spawn_cubie(grid_pos: Vector3i):
	var cubie = Node3D.new()
	cubie.position = Vector3(
		grid_pos.x * CUBIE_OFFSET,
		grid_pos.y * CUBIE_OFFSET,
		grid_pos.z * CUBIE_OFFSET
	)

	# Black body
	var body = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(CUBIE_SIZE, CUBIE_SIZE, CUBIE_SIZE)
	body.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	body.material_override = mat
	cubie.add_child(body)

	var x = grid_pos.x
	var y = grid_pos.y
	var z = grid_pos.z
	var stickers = {}

	if y == 1:
		var idx = facelet_index_U(x, z)
		var m = create_sticker(cubie, Vector3(0, STICKER_OFFSET, 0), Vector3(-90, 0, 0))
		sticker_map["U"][idx] = m
		stickers["U"] = m

	if y == -1:
		var idx = facelet_index_D(x, z)
		var m = create_sticker(cubie, Vector3(0, -STICKER_OFFSET, 0), Vector3(90, 0, 0))
		sticker_map["D"][idx] = m
		stickers["D"] = m

	if z == 1:
		var idx = facelet_index_F(x, y)
		var m = create_sticker(cubie, Vector3(0, 0, STICKER_OFFSET), Vector3(0, 0, 0))
		sticker_map["F"][idx] = m
		stickers["F"] = m

	if z == -1:
		var idx = facelet_index_B(x, y)
		var m = create_sticker(cubie, Vector3(0, 0, -STICKER_OFFSET), Vector3(0, 180, 0))
		sticker_map["B"][idx] = m
		stickers["B"] = m

	if x == 1:
		var idx = facelet_index_R(z, y)
		var m = create_sticker(cubie, Vector3(STICKER_OFFSET, 0, 0), Vector3(0, 90, 0))
		sticker_map["R"][idx] = m
		stickers["R"] = m

	if x == -1:
		var idx = facelet_index_L(z, y)
		var m = create_sticker(cubie, Vector3(-STICKER_OFFSET, 0, 0), Vector3(0, -90, 0))
		sticker_map["L"][idx] = m
		stickers["L"] = m

	add_child(cubie)

	cubie_nodes[grid_pos]    = cubie
	cubie_stickers[cubie]    = stickers
	cubie_spawn_pos[cubie]   = grid_pos

# ─────────────────────────────────────────
#  Create one sticker, return its material
# ─────────────────────────────────────────
func create_sticker(cubie: Node3D, offset: Vector3, rotation_deg: Vector3) -> StandardMaterial3D:
	var sticker = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2(STICKER_SIZE, STICKER_SIZE)
	sticker.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	sticker.material_override = mat

	sticker.position = offset
	sticker.rotation_degrees = rotation_deg
	cubie.add_child(sticker)

	return mat

# ─────────────────────────────────────────
#  Update colors — read logical state, paint materials
# ─────────────────────────────────────────
func update_colors():
	for face in ["U", "D", "F", "B", "L", "R"]:
		for i in range(9):
			var mat = sticker_map[face][i]
			if mat != null:
				mat.albedo_color = COLORS[cube_logic.state[face][i]]

# ─────────────────────────────────────────
#  Animation
# ─────────────────────────────────────────

# Enqueue a move. Starts immediately if nothing is running.
# axis/angle define the 3D rotation; layer_axis (0=x,1=y,2=z) + layer_val (-1/0/1)
# identify which slice of cubies to move.
func queue_move(logic_func: Callable, axis: Vector3, angle: float,
		layer_axis: int, layer_val: int) -> void:
	move_queue.append([logic_func, axis, angle, layer_axis, layer_val])
	if not is_animating:
		_process_next_move()

func _process_next_move() -> void:
	if move_queue.is_empty():
		is_animating = false
		return
	is_animating = true
	var p = move_queue.pop_front()
	_animate_move(p[0], p[1], p[2], p[3], p[4])

func _animate_move(logic_func: Callable, axis: Vector3, angle: float,
		layer_axis: int, layer_val: int) -> void:
	active_cubies = _get_cubies_in_layer(layer_axis, layer_val)

	active_pivot = Node3D.new()
	add_child(active_pivot)
	for cubie in active_cubies:
		cubie.reparent(active_pivot, true)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(active_pivot, "rotation", axis * angle, ANIM_DURATION)
	tween.tween_callback(_finish_move.bind(logic_func, axis, angle, layer_axis, layer_val))

func _finish_move(logic_func: Callable, axis: Vector3, angle: float,
		layer_axis: int, layer_val: int) -> void:
	# Reparent cubies back, snapping position and basis to avoid float drift
	for cubie in active_cubies:
		cubie.reparent(self, true)
		cubie.position = Vector3(
			roundi(cubie.position.x),
			roundi(cubie.position.y),
			roundi(cubie.position.z)
		)
		cubie.basis = _snap_basis(cubie.basis)

	active_pivot.queue_free()
	active_pivot = null

	_update_cubie_positions(layer_axis, layer_val, axis, angle)
	_rebuild_sticker_map()
	logic_func.call()
	update_colors()

	if cube_logic.is_solved():
		print("SOLVED!")

	active_cubies.clear()
	_process_next_move()

# Return all cubies whose grid position has the given coordinate on the given axis
func _get_cubies_in_layer(axis: int, val: int) -> Array:
	var result = []
	for pos in cubie_nodes:
		var coord = pos.x if axis == 0 else (pos.y if axis == 1 else pos.z)
		if coord == val:
			result.append(cubie_nodes[pos])
	return result

# Update cubie_nodes dict to reflect new grid positions after a rotation
func _update_cubie_positions(layer_axis: int, layer_val: int,
		axis: Vector3, angle: float) -> void:
	var q = Quaternion(axis, angle)
	var updated: Dictionary = {}
	for pos in cubie_nodes:
		var coord = pos.x if layer_axis == 0 else (pos.y if layer_axis == 1 else pos.z)
		if coord == layer_val:
			var v = q * Vector3(pos)
			updated[Vector3i(roundi(v.x), roundi(v.y), roundi(v.z))] = cubie_nodes[pos]
		else:
			updated[pos] = cubie_nodes[pos]
	cubie_nodes = updated

# Rebuild sticker_map by reading each cubie's current basis to determine
# which world face each of its sticker materials now belongs to.
func _rebuild_sticker_map() -> void:
	for face in sticker_map:
		for i in range(9):
			sticker_map[face][i] = null

	for pos in cubie_nodes:
		var cubie = cubie_nodes[pos]
		var x = pos.x; var y = pos.y; var z = pos.z

		for spawn_face in cubie_stickers[cubie]:
			var world_dir = (cubie.basis * STICKER_DIR[spawn_face]).normalized()
			var current_face = _dir_to_face(world_dir)

			var idx: int
			match current_face:
				"U": idx = facelet_index_U(x, z)
				"D": idx = facelet_index_D(x, z)
				"F": idx = facelet_index_F(x, y)
				"B": idx = facelet_index_B(x, y)
				"R": idx = facelet_index_R(z, y)
				"L": idx = facelet_index_L(z, y)
				_: continue

			sticker_map[current_face][idx] = cubie_stickers[cubie][spawn_face]

func _dir_to_face(dir: Vector3) -> String:
	if   dir.x >  0.5: return "R"
	elif dir.x < -0.5: return "L"
	elif dir.y >  0.5: return "U"
	elif dir.y < -0.5: return "D"
	elif dir.z >  0.5: return "F"
	else:              return "B"

# Snap each basis column to the nearest cardinal axis direction.
# Keeps rotations exactly axis-aligned after floating-point tween.
func _snap_basis(b: Basis) -> Basis:
	return Basis(_snap_vec(b.x), _snap_vec(b.y), _snap_vec(b.z))

func _snap_vec(v: Vector3) -> Vector3:
	var ax = abs(v.x); var ay = abs(v.y); var az = abs(v.z)
	if ax >= ay and ax >= az: return Vector3(sign(v.x), 0, 0)
	if ay >= az:              return Vector3(0, sign(v.y), 0)
	return                           Vector3(0, 0, sign(v.z))

# ─────────────────────────────────────────
#  Instant visual reset (cancels animation)
# ─────────────────────────────────────────
func reset_visual() -> void:
	move_queue.clear()
	is_animating = false

	if active_pivot:
		for cubie in active_cubies:
			if cubie.get_parent() == active_pivot:
				cubie.reparent(self, false)
		active_pivot.queue_free()
		active_pivot = null
		active_cubies.clear()

	cubie_nodes.clear()
	for cubie in cubie_spawn_pos:
		var spawn = cubie_spawn_pos[cubie]
		cubie.position = Vector3(spawn)
		cubie.basis    = Basis.IDENTITY
		cubie_nodes[spawn] = cubie

	_rebuild_sticker_map()

# ─────────────────────────────────────────
#  Facelet index helpers
# ─────────────────────────────────────────
func facelet_index_U(x: int, z: int) -> int:
	return (1 - z) * 3 + (x + 1)

func facelet_index_D(x: int, z: int) -> int:
	return (z + 1) * 3 + (x + 1)

func facelet_index_F(x: int, y: int) -> int:
	return (1 - y) * 3 + (x + 1)

func facelet_index_B(x: int, y: int) -> int:
	return (1 - y) * 3 + (1 - x)

func facelet_index_R(z: int, y: int) -> int:
	return (1 - y) * 3 + (1 - z)

func facelet_index_L(z: int, y: int) -> int:
	return (1 - y) * 3 + (z + 1)

# ─────────────────────────────────────────
#  Input
# ─────────────────────────────────────────
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			last_mouse_pos = event.position

	if event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_pos
		last_mouse_pos = event.position
		orbit_angles.y -= delta.x * 0.4
		orbit_angles.x += delta.y * 0.4
		orbit_angles.x = clamp(orbit_angles.x, -80, 80)
		update_camera()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if event.shift_pressed:
					queue_move(cube_logic.move_R_prime, Vector3(1,0,0),  PI/2, 0,  1)
				else:
					queue_move(cube_logic.move_R,       Vector3(1,0,0), -PI/2, 0,  1)
			KEY_U:
				if event.shift_pressed:
					queue_move(cube_logic.move_U_prime, Vector3(0,1,0), -PI/2, 1,  1)
				else:
					queue_move(cube_logic.move_U,       Vector3(0,1,0),  PI/2, 1,  1)
			KEY_F:
				if event.shift_pressed:
					queue_move(cube_logic.move_F_prime, Vector3(0,0,1),  PI/2, 2,  1)
				else:
					queue_move(cube_logic.move_F,       Vector3(0,0,1), -PI/2, 2,  1)
			KEY_L:
				if event.shift_pressed:
					queue_move(cube_logic.move_L_prime, Vector3(1,0,0), -PI/2, 0, -1)
				else:
					queue_move(cube_logic.move_L,       Vector3(1,0,0),  PI/2, 0, -1)
			KEY_D:
				if event.shift_pressed:
					queue_move(cube_logic.move_D_prime, Vector3(0,1,0),  PI/2, 1, -1)
				else:
					queue_move(cube_logic.move_D,       Vector3(0,1,0), -PI/2, 1, -1)
			KEY_B:
				if event.shift_pressed:
					queue_move(cube_logic.move_B_prime, Vector3(0,0,1), -PI/2, 2, -1)
				else:
					queue_move(cube_logic.move_B,       Vector3(0,0,1),  PI/2, 2, -1)
			KEY_M:
				if event.shift_pressed:
					queue_move(cube_logic.move_M_prime, Vector3(1,0,0), -PI/2, 0,  0)
				else:
					queue_move(cube_logic.move_M,       Vector3(1,0,0),  PI/2, 0,  0)
			KEY_E:
				if event.shift_pressed:
					queue_move(cube_logic.move_E_prime, Vector3(0,1,0),  PI/2, 1,  0)
				else:
					queue_move(cube_logic.move_E,       Vector3(0,1,0), -PI/2, 1,  0)
			KEY_S:
				if event.shift_pressed:
					queue_move(cube_logic.move_S_prime, Vector3(0,0,1),  PI/2, 2,  0)
				else:
					queue_move(cube_logic.move_S,       Vector3(0,0,1), -PI/2, 2,  0)
			KEY_SPACE:
				reset_visual()
				cube_logic.reset()
				cube_logic.scramble(20)
				update_colors()
			KEY_ENTER:
				reset_visual()
				cube_logic.reset()
				update_colors()

# ─────────────────────────────────────────
#  Camera
# ─────────────────────────────────────────
func update_camera():
	var pitch = deg_to_rad(orbit_angles.x)
	var yaw   = deg_to_rad(orbit_angles.y)
	var x = orbit_distance * cos(pitch) * sin(yaw)
	var y = orbit_distance * sin(pitch)
	var z = orbit_distance * cos(pitch) * cos(yaw)
	var camera = $Camera3D
	camera.position = Vector3(x, y, z)
	camera.look_at(Vector3.ZERO, Vector3.UP)
