class_name RallyBall
extends Node3D

const IMPACT_DURATION := 0.30

var _sphere: MeshInstance3D
var _shadow: MeshInstance3D
var _landing: MeshInstance3D
var _trail: Array[MeshInstance3D] = []
var _trail_time := 0.0
var _impact: Node3D
var _impact_ring: MeshInstance3D
var _impact_flash: MeshInstance3D
var _impact_sparks: Array[MeshInstance3D] = []
var _impact_material: StandardMaterial3D


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
	_build_impact()


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
	_sync_impact(rally)


func _build_impact() -> void:
	_impact = Node3D.new()
	_impact.name = "HitEffect"
	_impact.visible = false
	add_child(_impact)
	_impact_material = StandardMaterial3D.new()
	_impact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := TorusMesh.new()
	ring.inner_radius = 0.25
	ring.outer_radius = 0.35
	ring.rings = 24
	ring.ring_segments = 8
	_impact_ring = _impact_mesh(ring)
	_impact_ring.rotation_degrees.x = 90.0
	var flash := SphereMesh.new()
	flash.radius = 0.20
	flash.height = 0.40
	flash.radial_segments = 12
	flash.rings = 6
	_impact_flash = _impact_mesh(flash)
	var spark := SphereMesh.new()
	spark.radius = 0.1
	spark.height = 0.2
	spark.radial_segments = 8
	spark.rings = 4
	for index in range(6):
		_impact_sparks.append(_impact_mesh(spark))


func _sync_impact(rally: WallRally) -> void:
	_impact.visible = rally.phase == WallRally.Phase.OUTBOUND and rally.contact_age < IMPACT_DURATION
	if not _impact.visible:
		return
	_impact.position = rally.last_contact_pos
	var progress := clampf(rally.contact_age / IMPACT_DURATION, 0.0, 1.0)
	var color := Color("fff4c4").lerp(Color("ffae6b"), rally.shot_charge)
	color.a = (1.0 - progress) * (1.0 - progress)
	_impact_material.albedo_color = color
	_impact_ring.scale = Vector3.ONE * (1.0 + progress * (3.2 + rally.shot_charge))
	_impact_flash.scale = Vector3.ONE * (1.0 - progress) * 1.6
	for index in range(_impact_sparks.size()):
		var angle := TAU * float(index) / float(_impact_sparks.size()) + 0.3
		_impact_sparks[index].position = Vector3(cos(angle), sin(angle), 0.0) * (0.25 + progress * (1.2 + rally.shot_charge * 0.8))
		_impact_sparks[index].scale = Vector3.ONE * (1.2 - progress)


func _impact_mesh(shape: Mesh) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = _impact_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact.add_child(mesh)
	return mesh


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
