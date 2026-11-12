class_name Athlete
extends Node3D

## Footwork and the striking hand share the simulation's contact geometry.
const FOLLOW_THROUGH := 0.28
const UPPER_ARM_LENGTH := 0.95
const FOREARM_LENGTH := 0.95

@export var outfit_color := Color("e9f0d7")
@export var selection_color := Color("d5ef9d")

var _body: Node3D
var _paddle: Node3D
var _upper_arm: MeshInstance3D
var _forearm: MeshInstance3D
var _hand: MeshInstance3D
var _free_arm: MeshInstance3D
var _selection_ring: MeshInstance3D
var _id_label: Label3D
var _clock := 0.0
var _previous_pos := Vector3(WallRally.WIDTH * 0.5, 0.0, WallRally.PLAYER_Z)


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_piece(CapsuleMesh.new(), Vector3(0.0, 2.1, 0.0), outfit_color, Vector3(0.82, 1.1, 0.65))
	var head := SphereMesh.new()
	head.radius = 0.43
	head.height = 0.86
	_piece(head, Vector3(0.0, 3.48, 0.0), Color("edb38c"))
	var hair := SphereMesh.new()
	hair.radius = 0.44
	hair.height = 0.45
	_piece(hair, Vector3(0.0, 3.76, 0.03), Color("233c37"))
	for x in [-0.28, 0.28]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.18
		leg.height = 1.2
		_piece(leg, Vector3(x, 0.74, 0.0), Color("203d36"))
		var shoe := BoxMesh.new()
		shoe.size = Vector3(0.42, 0.24, 0.75)
		_piece(shoe, Vector3(x, 0.14, -0.12), Color("fff7dd"))
	_paddle = Node3D.new()
	_paddle.name = "Paddle"
	add_child(_paddle)
	var face := CylinderMesh.new()
	face.top_radius = 0.4
	face.bottom_radius = 0.4
	face.height = 0.14
	var paddle := MeshInstance3D.new()
	paddle.mesh = face
	paddle.rotation_degrees.x = 90.0
	paddle.material_override = _material(Color("ff9c70"))
	_paddle.add_child(paddle)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.15, 0.65, 0.15)
	var grip := MeshInstance3D.new()
	grip.mesh = handle
	grip.position.y = -0.5
	grip.material_override = _material(Color("243e38"))
	_paddle.add_child(grip)
	_upper_arm = _arm_piece(outfit_color, 0.16, UPPER_ARM_LENGTH)
	_forearm = _arm_piece(Color("edb38c"), 0.12, FOREARM_LENGTH)
	_free_arm = _arm_piece(outfit_color, 0.15)
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.16
	hand_mesh.height = 0.32
	_hand = MeshInstance3D.new()
	_hand.mesh = hand_mesh
	_hand.material_override = _material(Color("edb38c"))
	add_child(_hand)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	_selection_ring = _piece(ring, Vector3(0.0, 0.04, 0.0), selection_color)
	_id_label = Label3D.new()
	_id_label.position = Vector3(0.0, 4.6, 0.0)
	_id_label.font = load("res://fonts/Inter-Regular.ttf")
	_id_label.font_size = 48
	_id_label.pixel_size = 0.02
	_id_label.outline_size = 6
	_id_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_id_label.modulate = selection_color
	add_child(_id_label)


func paddle_contact_position() -> Vector3:
	return _paddle.global_position


func sync_practice(rally: WallRally, delta: float, player_index: int = 0) -> void:
	if _body == null:
		return
	_clock += delta
	var feet := rally.player_position(player_index)
	var volley := rally as VolleyRally
	var opponent := volley != null and volley.is_opponent(player_index)
	var facing := -1.0 if opponent else 1.0
	var moving := feet.distance_to(_previous_pos) > 0.002
	position = feet
	_selection_ring.visible = not opponent and (rally.player_count == 1 or rally.active_player == player_index)
	_id_label.visible = rally.player_count == 2 or volley != null
	_id_label.text = volley.player_label(player_index) if volley != null else "P%d" % (player_index + 1)
	_id_label.position = Vector3(0.6 if opponent else -0.6, 5.0, 0.0) if volley != null else Vector3(0.0, 4.6, 0.0)
	_body.rotation.y = PI if opponent else 0.0
	_body.position.y = absf(sin(_clock * 14.0)) * 0.08 if moving else 0.0
	_body.rotation.z = clampf((_previous_pos.x - position.x) * 1.5, -0.12, 0.12)
	_previous_pos = position
	var side := rally.hand_side()
	var recovery := clampf(rally.contact_age / FOLLOW_THROUGH, 0.0, 1.0) if rally.last_hitter == player_index else 1.0
	var follow := sin(recovery * PI)
	var resting := rally.paddle_position(player_index)
	# The face starts exactly at the real ball contact, then follows through.
	var contact := (position + rally.last_contact_offset).lerp(resting, recovery)
	contact += Vector3(-side * follow * 0.3 * facing, follow * 0.15, -follow * 0.85 * facing)
	_paddle.rotation.y = -side * follow * 0.65
	# Lower the shoulders for a low pickup rather than lengthening the arms.
	_body.position.y -= clampf(2.65 - contact.y, 0.0, 1.1)
	var shoulder := _body.transform * Vector3(side * 0.43, 2.75, 0.0)
	var offset := contact - position + Vector3(0.0, -0.48, 0.0) - shoulder
	var distance := clampf(offset.length(), 0.01, UPPER_ARM_LENGTH + FOREARM_LENGTH - 0.001)
	var direction := offset.normalized() if offset.length_squared() > 0.000001 else Vector3.DOWN
	var grip := shoulder + direction * distance
	var along := (UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + distance * distance) / (2.0 * distance)
	var bend := Vector3(side * 0.25, -0.8, 0.35 * facing)
	bend -= direction * bend.dot(direction)
	if bend.length_squared() < 0.000001:
		bend = direction.cross(Vector3.RIGHT)
	var elbow := shoulder + direction * along + bend.normalized() * sqrt(maxf(0.0, UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - along * along))
	_paddle.position = grip + Vector3(0.0, 0.48, 0.0)
	_connect_arm(_upper_arm, shoulder, elbow)
	_connect_arm(_forearm, elbow, grip)
	_hand.position = grip
	_connect_arm(_free_arm, _body.transform * Vector3(-side * 0.43, 2.7, 0.0), _body.transform * Vector3(-side * 0.62, 1.7, -0.15))


func _arm_piece(color: Color, radius: float, length: float = 1.0) -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = length
	var arm := MeshInstance3D.new()
	arm.mesh = shape
	arm.material_override = _material(color)
	add_child(arm)
	return arm


func _connect_arm(arm: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var offset := end - start
	arm.position = (start + end) * 0.5
	arm.scale = Vector3.ONE
	if offset.length_squared() > 0.000001:
		arm.quaternion = Quaternion(Vector3.UP, offset.normalized())


func _piece(mesh: Mesh, pos: Vector3, color: Color, mesh_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.scale = mesh_scale
	part.material_override = _material(color)
	_body.add_child(part)
	return part


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
