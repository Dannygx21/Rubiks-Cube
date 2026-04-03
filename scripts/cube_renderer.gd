extends Node3D

# ─────────────────────────────────────────
#  Color map — matches your state constants
#  0=White 1=Yellow 2=Green 3=Blue 4=Orange 5=Red
# ─────────────────────────────────────────
const COLORS = {
	0: Color(1.0, 1.0, 1.0),      # White
	1: Color(1.0, 1.0, 0.0),      # Yellow
	2: Color(0.0, 0.8, 0.0),      # Green
	3: Color(0.0, 0.0, 1.0),      # Blue
	4: Color(1.0, 0.5, 0.0),      # Orange
	5: Color(1.0, 0.0, 0.0),      # Red
}

const CUBIE_SIZE = 0.95   # Slightly less than 1 so there's a small gap
const CUBIE_OFFSET = 1.0  # Distance between cubie centers
const STICKER_SIZE = 0.85
const STICKER_OFFSET = 0.476 # just above the cubie face


var cubies = {} # Dictionary keyed by Vector3i grid position
var cube_logic: Node

# Called when the node enters the scene tree for the first time.
func _ready():
	# load the logic cube
	cube_logic = load("res://scripts/cube.gd").new()
	add_child(cube_logic)
	
	spawn_cubies()
	update_colors()
	
# Scarmble and see if colors update correctly
	cube_logic.scramble(20)
	update_colors()

# Position Camera to see 3 faces
	var camera = $Camera3D
	camera.position = Vector3(4,3,6)
	camera.rotation_degrees = Vector3(-20, 30, 0)
# ─────────────────────────────────────────
#  Spawn all 26 visible cubies
#  (3x3x3 = 27 total, minus 1 hidden center)
# ─────────────────────────────────────────
func spawn_cubies():
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				# Skip the invisible core center
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

	add_child(cubie)
	cubies[grid_pos] = cubie

# ─────────────────────────────────────────
#  Sticker helper — adds a colored quad
#  to a cubie face
# ─────────────────────────────────────────
func add_sticker(cubie: Node3D, color: Color, offset: Vector3, rotation_deg: Vector3):
	var sticker = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2(STICKER_SIZE, STICKER_SIZE)
	sticker.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sticker.material_override = mat

	sticker.position = offset
	sticker.rotation_degrees = rotation_deg
	cubie.add_child(sticker)
	
	# ─────────────────────────────────────────
#  Read logic state and color all stickers
# ─────────────────────────────────────────
func update_colors():
	# Clear old stickers
	for grid_pos in cubies:
		var cubie = cubies[grid_pos]
		for child in cubie.get_children():
			if child is MeshInstance3D and child.mesh is QuadMesh:
				child.queue_free()

	var s = cube_logic.state

	for grid_pos in cubies:
		var cubie = cubies[grid_pos]
		var x = grid_pos.x
		var y = grid_pos.y
		var z = grid_pos.z

		# U face (y == 1) — top stickers
		if y == 1:
			var idx = facelet_index_U(x, z)
			add_sticker(cubie, COLORS[s["U"][idx]],
				Vector3(0, STICKER_OFFSET, 0),
				Vector3(-90, 0, 0))

		# D face (y == -1) — bottom stickers
		if y == -1:
			var idx = facelet_index_D(x, z)
			add_sticker(cubie, COLORS[s["D"][idx]],
				Vector3(0, -STICKER_OFFSET, 0),
				Vector3(90, 0, 0))

		# F face (z == 1) — front stickers
		if z == 1:
			var idx = facelet_index_F(x, y)
			add_sticker(cubie, COLORS[s["F"][idx]],
				Vector3(0, 0, STICKER_OFFSET),
				Vector3(0, 0, 0))

		# B face (z == -1) — back stickers
		if z == -1:
			var idx = facelet_index_B(x, y)
			add_sticker(cubie, COLORS[s["B"][idx]],
				Vector3(0, 0, -STICKER_OFFSET),
				Vector3(0, 180, 0))

		# R face (x == 1) — right stickers
		if x == 1:
			var idx = facelet_index_R(z, y)
			add_sticker(cubie, COLORS[s["R"][idx]],
				Vector3(STICKER_OFFSET, 0, 0),
				Vector3(0, 90, 0))

		# L face (x == -1) — left stickers
		if x == -1:
			var idx = facelet_index_L(z, y)
			add_sticker(cubie, COLORS[s["L"][idx]],
				Vector3(-STICKER_OFFSET, 0, 0),
				Vector3(0, -90, 0))

# ─────────────────────────────────────────
#  Facelet index helpers
#  Maps 3D grid position → face array index
#
#  Face layout (viewed from outside):
#   0 1 2
#   3 4 5
#   6 7 8
# ─────────────────────────────────────────
func facelet_index_U(x: int, z: int) -> int:
	# Viewed from top: z=-1 is top row, x=-1 is left
	var row = z + 1      # z: -1→0, 0→1, 1→2
	var col = x + 1      # x: -1→0, 0→1, 1→2
	return row * 3 + col

func facelet_index_D(x: int, z: int) -> int:
	# Viewed from bottom: z=1 is top row
	var row = 1 - (z - (-1)) # flip z
	var col = x + 1
	return row * 3 + col

func facelet_index_F(x: int, y: int) -> int:
	# Viewed from front: y=1 is top row, x=-1 is left
	var row = 1 - (y - (-1)) # flip y: 1→0, 0→1, -1→2
	var col = x + 1
	return row * 3 + col

func facelet_index_B(x: int, y: int) -> int:
	# Viewed from back: y=1 is top row, x=1 is left
	var row = 1 - (y - (-1))
	var col = 1 - (x - (-1))
	return row * 3 + col

func facelet_index_R(z: int, y: int) -> int:
	# Viewed from right: y=1 is top row, z=1 is left
	var row = 1 - (y - (-1))
	var col = 1 - (z - (-1))
	return row * 3 + col

func facelet_index_L(z: int, y: int) -> int:
	# Viewed from left: y=1 is top row, z=-1 is left
	var row = 1 - (y - (-1))
	var col = z + 1
	return row * 3 + col
	
	

	
	
	
	
	
