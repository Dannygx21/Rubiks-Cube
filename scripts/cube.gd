extends Node

#
# Color constants - easier to read than 0-5
#

const WHITE = 0
const YELLOW = 1
const GREEN = 2
const BLUE = 3
const ORANGE = 4
const RED = 5

#
# Cube state 
# Each face has 9 facelets, indexed 0-8
#
# 0 1 2
# 3 4 5
# 6 7 8
#
# Face centers (index 4) never moves

var state: Dictionary = {}

func _ready():
	reset()
	print("Solved? ", is_solved())   # true

	scramble(20)
	print("Solved? ", is_solved())   # false
	print_state()

	reset()
	print("Solved? ", is_solved())   # true

func get_solved_state() -> Dictionary:
	return {
		"U": [0,0,0,0,0,0,0,0,0],
		"D": [1,1,1,1,1,1,1,1,1],
		"F": [2,2,2,2,2,2,2,2,2],
		"B": [3,3,3,3,3,3,3,3,3],
		"L": [4,4,4,4,4,4,4,4,4],
		"R": [5,5,5,5,5,5,5,5,5],
	}
	
	
#
# Resect to solved state
#
func reset():
	state = {
		"U": [WHITE, WHITE, WHITE, WHITE, WHITE, WHITE, WHITE, WHITE, WHITE],
		"D": [YELLOW, YELLOW,YELLOW,YELLOW,YELLOW,YELLOW,YELLOW,YELLOW,YELLOW],
		"F": [GREEN, GREEN, GREEN, GREEN, GREEN, GREEN, GREEN, GREEN, GREEN],
		"B": [BLUE, BLUE, BLUE, BLUE, BLUE, BLUE, BLUE, BLUE, BLUE],
		"L": [ORANGE, ORANGE, ORANGE, ORANGE, ORANGE, ORANGE, ORANGE, ORANGE, ORANGE],
		"R": [RED, RED, RED, RED, RED, RED, RED, RED, RED]
	}

#
# Debug - print the code state to output
#
func print_state():
	for face in ["U", "D", "F", "B", "L", "R"]:
		print(face, ": ", state[face])
		

#
# Helper - rotate a face array clockwise
#

func rotate_face_cw(face: String):
	var f = state[face]
	state[face] = [
		f[6], f[3], f[0],
		f[7], f[4], f[1],
		f[8], f[5], f[2]
	]

func rotate_face_ccw(face: String):
	var f = state[face]
	state[face] =[
		f[2], f[5], f[8],
		f[1], f[4], f[7],
		f[0], f[3], f[6]
	]
	
#
# R Move - right face clockwise
#
func move_R():
	rotate_face_cw("R")
	var u = state["U"].duplicate()
	var f = state["F"].duplicate()
	var d = state["D"].duplicate()
	var b = state["B"].duplicate()

	# U right col → F right col
	state["F"][2] = u[2]
	state["F"][5] = u[5]
	state["F"][8] = u[8]

	# F right col → D right col
	state["D"][2] = f[2]
	state["D"][5] = f[5]
	state["D"][8] = f[8]

	# D right col → B left col (reversed)
	state["B"][0] = d[8]
	state["B"][3] = d[5]
	state["B"][6] = d[2]

	# B left col → U right col (reversed)
	state["U"][2] = b[6]
	state["U"][5] = b[3]
	state["U"][8] = b[0]

func move_R_prime():
	rotate_face_ccw("R")
	var u = state["U"].duplicate()
	var f = state["F"].duplicate()
	var d = state["D"].duplicate()
	var b = state["B"].duplicate()

	# F right col → U right col
	state["U"][2] = f[2]
	state["U"][5] = f[5]
	state["U"][8] = f[8]

	# U right col → B left col (reversed)
	state["B"][0] = u[8]
	state["B"][3] = u[5]
	state["B"][6] = u[2]

	# B left col → D right col (reversed)
	state["D"][2] = b[6]
	state["D"][5] = b[3]
	state["D"][8] = b[0]

	# D right col → F right col
	state["F"][2] = d[2]
	state["F"][5] = d[5]
	state["F"][8] = d[8]

# ─────────────────────────────────────────
#  U move — top face clockwise
# ─────────────────────────────────────────
func move_U():
	rotate_face_cw("U")
	var f = state["F"].duplicate()
	var r = state["R"].duplicate()
	var b = state["B"].duplicate()
	var l = state["L"].duplicate()

	state["R"][0] = f[0]
	state["R"][1] = f[1]
	state["R"][2] = f[2]

	state["B"][0] = r[0]
	state["B"][1] = r[1]
	state["B"][2] = r[2]

	state["L"][0] = b[0]
	state["L"][1] = b[1]
	state["L"][2] = b[2]

	state["F"][0] = l[0]
	state["F"][1] = l[1]
	state["F"][2] = l[2]

func move_U_prime():
	rotate_face_ccw("U")
	var f = state["F"].duplicate()
	var r = state["R"].duplicate()
	var b = state["B"].duplicate()
	var l = state["L"].duplicate()

	state["L"][0] = f[0]
	state["L"][1] = f[1]
	state["L"][2] = f[2]

	state["F"][0] = r[0]
	state["F"][1] = r[1]
	state["F"][2] = r[2]

	state["R"][0] = b[0]
	state["R"][1] = b[1]
	state["R"][2] = b[2]

	state["B"][0] = l[0]
	state["B"][1] = l[1]
	state["B"][2] = l[2]

# ─────────────────────────────────────────
#  F move — front face clockwise
# ─────────────────────────────────────────
func move_F():
	rotate_face_cw("F")
	var u = state["U"].duplicate()
	var r = state["R"].duplicate()
	var d = state["D"].duplicate()
	var l = state["L"].duplicate()

	state["R"][0] = u[6]
	state["R"][3] = u[7]
	state["R"][6] = u[8]

	state["D"][0] = r[6]
	state["D"][1] = r[3]
	state["D"][2] = r[0]

	state["L"][2] = d[0]
	state["L"][5] = d[1]
	state["L"][8] = d[2]

	state["U"][6] = l[8]
	state["U"][7] = l[5]
	state["U"][8] = l[2]

func move_F_prime():
	rotate_face_ccw("F")
	var u = state["U"].duplicate()
	var r = state["R"].duplicate()
	var d = state["D"].duplicate()
	var l = state["L"].duplicate()

	state["L"][2] = u[8]
	state["L"][5] = u[7]
	state["L"][8] = u[6]

	state["U"][6] = r[0]
	state["U"][7] = r[3]
	state["U"][8] = r[6]

	state["R"][0] = d[2]
	state["R"][3] = d[1]
	state["R"][6] = d[0]

	state["D"][0] = l[2]
	state["D"][1] = l[5]
	state["D"][2] = l[8]

# ─────────────────────────────────────────
#  L move — left face clockwise
# ─────────────────────────────────────────
func move_L():
	rotate_face_cw("L")
	var u = state["U"].duplicate()
	var f = state["F"].duplicate()
	var d = state["D"].duplicate()
	var b = state["B"].duplicate()

	state["F"][0] = u[0]
	state["F"][3] = u[3]
	state["F"][6] = u[6]

	state["D"][0] = f[0]
	state["D"][3] = f[3]
	state["D"][6] = f[6]

	state["B"][2] = d[6]
	state["B"][5] = d[3]
	state["B"][8] = d[0]

	state["U"][0] = b[8]
	state["U"][3] = b[5]
	state["U"][6] = b[2]

func move_L_prime():
	rotate_face_ccw("L")
	var u = state["U"].duplicate()
	var f = state["F"].duplicate()
	var d = state["D"].duplicate()
	var b = state["B"].duplicate()

	state["U"][0] = f[0]
	state["U"][3] = f[3]
	state["U"][6] = f[6]

	state["F"][0] = d[0]
	state["F"][3] = d[3]
	state["F"][6] = d[6]

	state["D"][0] = b[8]
	state["D"][3] = b[5]
	state["D"][6] = b[2]

	state["B"][2] = u[6]
	state["B"][5] = u[3]
	state["B"][8] = u[0]

# ─────────────────────────────────────────
#  D move — bottom face clockwise
# ─────────────────────────────────────────
func move_D():
	rotate_face_cw("D")
	var f = state["F"].duplicate()
	var r = state["R"].duplicate()
	var b = state["B"].duplicate()
	var l = state["L"].duplicate()

	state["L"][6] = f[6]
	state["L"][7] = f[7]
	state["L"][8] = f[8]

	state["F"][6] = r[6]
	state["F"][7] = r[7]
	state["F"][8] = r[8]

	state["R"][6] = b[6]
	state["R"][7] = b[7]
	state["R"][8] = b[8]

	state["B"][6] = l[6]
	state["B"][7] = l[7]
	state["B"][8] = l[8]

func move_D_prime():
	rotate_face_ccw("D")
	var f = state["F"].duplicate()
	var r = state["R"].duplicate()
	var b = state["B"].duplicate()
	var l = state["L"].duplicate()

	state["R"][6] = f[6]
	state["R"][7] = f[7]
	state["R"][8] = f[8]

	state["B"][6] = r[6]
	state["B"][7] = r[7]
	state["B"][8] = r[8]

	state["L"][6] = b[6]
	state["L"][7] = b[7]
	state["L"][8] = b[8]

	state["F"][6] = l[6]
	state["F"][7] = l[7]
	state["F"][8] = l[8]

# ─────────────────────────────────────────
#  B move — back face clockwise
# ─────────────────────────────────────────
func move_B():
	rotate_face_cw("B")
	var u = state["U"].duplicate()
	var r = state["R"].duplicate()
	var d = state["D"].duplicate()
	var l = state["L"].duplicate()

	state["L"][0] = u[2]
	state["L"][3] = u[1]
	state["L"][6] = u[0]

	state["U"][0] = r[2]
	state["U"][1] = r[5]
	state["U"][2] = r[8]

	state["R"][2] = d[8]
	state["R"][5] = d[7]
	state["R"][8] = d[6]

	state["D"][6] = l[0]
	state["D"][7] = l[3]
	state["D"][8] = l[6]

func move_B_prime():
	rotate_face_ccw("B")
	var u = state["U"].duplicate()
	var r = state["R"].duplicate()
	var d = state["D"].duplicate()
	var l = state["L"].duplicate()

	state["R"][2] = u[0]
	state["R"][5] = u[1]
	state["R"][8] = u[2]

	state["D"][6] = r[2]
	state["D"][7] = r[5]
	state["D"][8] = r[8]

	state["L"][0] = d[8]
	state["L"][3] = d[7]
	state["L"][6] = d[6]

	state["U"][0] = l[6]
	state["U"][1] = l[3]
	state["U"][2] = l[0]

#
# Scramble - apply n random moves
#
func scramble(n: int = 20):
	var moves =[
		move_R, move_R_prime,
		move_U, move_U_prime,
		move_F, move_F_prime,
		move_L, move_L_prime,
		move_D, move_D_prime,
		move_B, move_B_prime
	]
	for i in range(n):
		moves[randi() % moves.size()].call()
		

#
# Check if cube is solved
#
func is_solved() -> bool:
	return state == get_solved_state()
