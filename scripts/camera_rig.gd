class_name CameraRig
extends Node3D

## Wall overview and a steady first-person volley view.
const PADDLE_REST := Vector3(0.55, -0.55, -1.4)
const FIRST_PERSON_FOV := 62.0
const DOUBLES_FOV := 90.0
const DOUBLES_EYE_Z := 23.8
const LOOK_SPEED := PI * 0.5

@onready var camera: Camera3D = $Camera3D
var _first_person: Node3D
var _view_paddle: Node3D
var _view_player_count := 0


func _ready() -> void:
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	_build_first_person()
	set_volley_mode(false)


func set_volley_mode(enabled: bool) -> void:
	_view_player_count = 0
	camera.position = Vector3(6.0, 5.4, 20.8) if enabled else Vector3(6.0, 16.0, 34.5)
	camera.look_at(Vector3(6.0, VolleyRally.VOLLEY_HEIGHT, 4.7) if enabled else Vector3(6.0, 1.0, 12.0))
	camera.fov = FIRST_PERSON_FOV if enabled else 46.0
	_first_person.visible = enabled
	_view_paddle.position = PADDLE_REST


func sync_volley(rally: WallRally, delta: float = 0.0) -> void:
	var volley := rally as VolleyRally
	if volley == null:
		return
	var doubles := rally.player_count == 2
	# One shared view covers both lanes. Changing receiver must never pan X.
	var forward_offset := rally.player_position(rally.active_player).z - volley.home_position(rally.active_player).z
	var eye_z := (DOUBLES_EYE_Z if doubles else 20.8) + forward_offset
	var eye := Vector3(WallRally.WIDTH * 0.5, 4.2 if volley.dink_shot else 5.4, eye_z)
	var initialize := _view_player_count != rally.player_count
	if initialize:
		_view_player_count = rally.player_count
		camera.fov = DOUBLES_FOV if doubles else FIRST_PERSON_FOV
		camera.position = eye
	elif delta > 0.0:
		camera.position = camera.position.move_toward(eye, WallRally.MOVE_SPEED * delta)
	var look_y := 1.2 if volley.dink_shot else VolleyRally.VOLLEY_HEIGHT
	var look_z := VolleyRally.NET_Z if volley.dink_shot else 4.7
	var pitch := atan2(look_y - camera.position.y, camera.position.z - look_z)
	if initialize:
		camera.rotation = Vector3(pitch, 0.0, 0.0)
	elif delta > 0.0:
		camera.rotation.x = move_toward(camera.rotation.x, pitch, LOOK_SPEED * delta)
	# A wider court view keeps the foreground racket at its familiar size.
	var view_scale := tan(deg_to_rad(camera.fov * 0.5)) / tan(deg_to_rad(FIRST_PERSON_FOV * 0.5))
	var side := rally.hand_side()
	var resting := Vector3(PADDLE_REST.x * side * view_scale, PADDLE_REST.y * view_scale, PADDLE_REST.z)
	var recovery := clampf(rally.contact_age / 0.17, 0.0, 1.0) if rally.last_hitter == rally.active_player else 1.0
	var contact := camera.to_local(rally.last_contact_pos)
	var swing := Vector3(0.0, -0.35, -1.4)
	if contact.z < -0.1:
		swing = contact * (1.4 / -contact.z)
		swing.x = clampf(swing.x, -1.25 if doubles else -0.35, 1.25 if doubles else 0.35)
		swing.y = clampf(swing.y, -0.9 * view_scale, 0.1 * view_scale)
	_view_paddle.position = swing.lerp(resting, recovery)
	_view_paddle.scale = Vector3(side * view_scale, view_scale, 1.0)
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
