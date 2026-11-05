class_name RallyBall
extends Node3D

var _sphere: MeshInstance3D
var _shadow: MeshInstance3D
var _landing: MeshInstance3D
var _trail: Array[MeshInstance3D] = []
var _trail_time := 0.0


func _ready() -> void:
	_sphere = _mesh(SphereMesh.new(), Color("eeff80"))
	_sphere.scale = Vector3(0.68, 0.68, 0.68)
	_shadow = _mesh(SphereMesh.new(), Color(0.04, 0.14, 0.12, 0.3))
	_shadow.scale = Vector3(0.95, 0.035, 0.95)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.61
	_landing = _mesh(ring, Color("d9f7a5"))
	for i in range(5):
		var dot := _mesh(SphereMesh.new(), Color("e9f6b6"))
		dot.scale = Vector3.ONE * (0.2 - float(i) * 0.026)
		_trail.append(dot)


func sync_practice(rally: WallRally, delta: float) -> void:
	if _sphere == null:
		return
	_sphere.position = rally.ball_pos
	_shadow.position = Vector3(rally.ball_pos.x, 0.06, rally.ball_pos.z)
	_landing.visible = rally.phase == WallRally.Phase.RETURNING or rally.phase == WallRally.Phase.BOUNCED
	_landing.position = Vector3(rally.receive_apex.x, 0.055, rally.receive_apex.z)
	_landing.scale = Vector3.ONE * (1.05 if rally.can_return() else 0.8)
	_trail_time += delta
	if _trail_time >= 0.035:
		_trail_time = 0.0
		for i in range(_trail.size() - 1, 0, -1):
			_trail[i].position = _trail[i - 1].position
		_trail[0].position = rally.ball_pos
	for dot in _trail:
		dot.visible = rally.phase != WallRally.Phase.READY and rally.phase != WallRally.Phase.MISSED


func _mesh(shape: Mesh, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	add_child(mesh)
	return mesh
