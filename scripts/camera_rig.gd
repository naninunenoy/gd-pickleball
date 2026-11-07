class_name CameraRig
extends Node3D

## Wall overview and a steady first-person volley view.
const PADDLE_REST := Vector3(0.55, -0.55, -1.4)
const FIRST_PERSON_FOV := 62.0

@onready var camera: Camera3D = $Camera3D
var _first_person: Node3D
var _view_paddle: Node3D


func _ready() -> void:
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	_build_first_person()
	set_volley_mode(false)


func set_volley_mode(enabled: bool) -> void:
	camera.position = Vector3(6.0, 4.2, 20.8) if enabled else Vector3(6.0, 16.0, 34.5)
	camera.look_at(Vector3(6.0, VolleyRally.VOLLEY_HEIGHT, 4.7) if enabled else Vector3(6.0, 1.0, 12.0))
	camera.fov = FIRST_PERSON_FOV if enabled else 46.0
	_first_person.visible = enabled
	_view_paddle.position = PADDLE_REST


func sync_volley(rally: WallRally) -> void:
	if not rally is VolleyRally:
		return
	var side := rally.hand_side()
	var resting := Vector3(PADDLE_REST.x * side, PADDLE_REST.y, PADDLE_REST.z)
	var recovery := clampf(rally.contact_age / 0.24, 0.0, 1.0) if rally.last_hitter == 0 else 1.0
	var contact := camera.to_local(rally.last_contact_pos)
	var swing := Vector3(0.0, -0.35, -1.4)
	if contact.z < -0.1:
		swing = contact * (1.4 / -contact.z)
		swing.x = clampf(swing.x, -0.35, 0.35)
		swing.y = clampf(swing.y, -0.9, 0.1)
	_view_paddle.position = swing.lerp(resting, recovery)
	_view_paddle.scale.x = side
	_view_paddle.rotation.z = -0.25 * side * sin(recovery * PI)


func _build_first_person() -> void:
	_first_person = Node3D.new()
	camera.add_child(_first_person)
	_view_paddle = Node3D.new()
	_first_person.add_child(_view_paddle)
	var face := CylinderMesh.new()
	face.top_radius = 0.18
	face.bottom_radius = 0.18
	face.height = 0.04
	var paddle := _view_mesh(face, Color("ff9c70"), Vector3.ZERO)
	paddle.rotation.x = PI * 0.5
	var handle := BoxMesh.new()
	handle.size = Vector3(0.07, 0.4, 0.07)
	_view_mesh(handle, Color("243e38"), Vector3(0.0, -0.32, 0.0))
	var hand := SphereMesh.new()
	hand.radius = 0.1
	hand.height = 0.2
	_view_mesh(hand, Color("edb38c"), Vector3(0.0, -0.5, 0.04))
	var arm := CapsuleMesh.new()
	arm.radius = 0.085
	arm.height = 0.65
	var forearm := _view_mesh(arm, Color("edb38c"), Vector3(0.06, -0.85, 0.2))
	forearm.rotation.x = -0.45
	forearm.rotation.z = 0.15


func _view_mesh(shape: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	mesh.material_override = material
	_view_paddle.add_child(mesh)
	return mesh
