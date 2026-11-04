class_name Athlete
extends Node3D

## The only player. Footwork is automatic; the tap animates the paddle.
var _body: Node3D
var _paddle: Node3D
var _swing_time := 0.0
var _clock := 0.0
var _previous_x := WallRally.WIDTH * 0.5


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_piece(CapsuleMesh.new(), Vector3(0.0, 2.1, 0.0), Color("e9f0d7"), Vector3(0.82, 1.1, 0.65))
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
	_paddle.position = Vector3(0.8, 2.0, -0.25)
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
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	_piece(ring, Vector3(0.0, 0.04, 0.0), Color("d5ef9d"))


func swing() -> void:
	_swing_time = 0.28


func sync_practice(x: float, delta: float) -> void:
	if _body == null:
		return
	_clock += delta
	var moving := absf(x - _previous_x) > 0.002
	position = Vector3(x, 0.0, WallRally.PLAYER_Z)
	_body.position.y = absf(sin(_clock * 14.0)) * 0.08 if moving else 0.0
	_body.rotation.z = clampf((_previous_x - x) * 1.5, -0.12, 0.12)
	_previous_x = x
	_swing_time = maxf(0.0, _swing_time - delta)
	_paddle.rotation.y = -sin(_swing_time / 0.28 * PI) * 1.8
	_paddle.position.z = -0.25 - sin(_swing_time / 0.28 * PI) * 1.0


func _piece(mesh: Mesh, pos: Vector3, color: Color, mesh_scale: Vector3 = Vector3.ONE) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.scale = mesh_scale
	part.material_override = _material(color)
	_body.add_child(part)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
