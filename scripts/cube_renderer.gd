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

var cube_logic: Node

# sticker_map[face][index] = StandardMaterial3D
# So we can just set albedo_color directly
var sticker_map = {}

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
	spawn_cubies()
	debug_sticker_slots()
	cube_logic.reset()     # solved, no scramble
	update_colors()
	update_camera()	
# ─────────────────────────────────────────
#  Spawn all 26 cubies and pre-create
#  every sticker with a material slot
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

	# Pre-create exactly one sticker per visible face
	# and store its material in sticker_map
	if y == 1:
		var idx = facelet_index_U(x, z)
		var m = create_sticker(cubie, Vector3(0, STICKER_OFFSET, 0), Vector3(-90, 0, 0))
		sticker_map["U"][idx] = m

	if y == -1:
		var idx = facelet_index_D(x, z)
		var m = create_sticker(cubie, Vector3(0, -STICKER_OFFSET, 0), Vector3(90, 0, 0))
		sticker_map["D"][idx] = m

	if z == 1:
		var idx = facelet_index_F(x, y)
		var m = create_sticker(cubie, Vector3(0, 0, STICKER_OFFSET), Vector3(0, 0, 0))
		sticker_map["F"][idx] = m

	if z == -1:
		var idx = facelet_index_B(x, y)
		var m = create_sticker(cubie, Vector3(0, 0, -STICKER_OFFSET), Vector3(0, 180, 0))
		sticker_map["B"][idx] = m

	if x == 1:
		var idx = facelet_index_R(z, y)
		var m = create_sticker(cubie, Vector3(STICKER_OFFSET, 0, 0), Vector3(0, 90, 0))
		sticker_map["R"][idx] = m

	if x == -1:
		var idx = facelet_index_L(z, y)
		var m = create_sticker(cubie, Vector3(-STICKER_OFFSET, 0, 0), Vector3(0, -90, 0))
		sticker_map["L"][idx] = m

	add_child(cubie)

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
	mat.albedo_color = Color(0.05, 0.05, 0.05)  # default black until update
	sticker.material_override = mat

	sticker.position = offset
	sticker.rotation_degrees = rotation_deg
	cubie.add_child(sticker)

	return mat

# ─────────────────────────────────────────
#  Update colors — just set material colors
#  No nodes created or destroyed
# ─────────────────────────────────────────
func update_colors():
	for face in ["U", "D", "F", "B", "L", "R"]:
		for i in range(9):
			var mat = sticker_map[face][i]
			if mat != null:
				mat.albedo_color = COLORS[cube_logic.state[face][i]]

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
					cube_logic.move_R_prime()
				else:
					cube_logic.move_R()
			KEY_U:
				if event.shift_pressed:
					cube_logic.move_U_prime()
				else:
					cube_logic.move_U()
			KEY_F:
				if event.shift_pressed:
					cube_logic.move_F_prime()
				else:
					cube_logic.move_F()
			KEY_L:
				if event.shift_pressed:
					cube_logic.move_L_prime()
				else:
					cube_logic.move_L()
			KEY_D:
				if event.shift_pressed:
					cube_logic.move_D_prime()
				else:
					cube_logic.move_D()
			KEY_B:
				if event.shift_pressed:
					cube_logic.move_B_prime()
				else:
					cube_logic.move_B()
			KEY_SPACE:
				cube_logic.scramble(20)
			KEY_ENTER:
				cube_logic.reset()

		update_colors()

		if cube_logic.is_solved():
			print("SOLVED!")

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
	
func debug_sticker_slots():
	print("=== U sticker assignments ===")
	for z in range(1, -2, -1):
		for x in range(-1, 2):
			var idx = facelet_index_U(x, z)
			print("U grid(x=", x, " z=", z, ") -> slot ", idx)

	print("=== F sticker assignments ===")
	for y in range(1, -2, -1):
		for x in range(-1, 2):
			var idx = facelet_index_F(x, y)
			print("F grid(x=", x, " y=", y, ") -> slot ", idx)

	print("=== R sticker assignments ===")
	for y in range(1, -2, -1):
		for z in range(1, -2, -1):
			var idx = facelet_index_R(z, y)
			print("R grid(z=", z, " y=", y, ") -> slot ", idx)

	print("=== L sticker assignments ===")
	for y in range(1, -2, -1):
		for z in range(-1, 2):
			var idx = facelet_index_L(z, y)
			print("L grid(z=", z, " y=", y, ") -> slot ", idx)
