class_name AimReticle
extends Node3D

var court_pos := Vector2(10.0, 8.0)
var valid := true
var shown := true

var _ring: MeshInstance3D
var _x: MeshInstance3D
var _z: MeshInstance3D


func sync_world() -> void:
	_ensure_meshes()
	visible = shown
	position = CourtMap.to_world(court_pos, 0.05)
	var color := Color(0.45, 0.92, 0.52) if valid else Color(0.92, 0.32, 0.28)
	_tint(_ring, color)
	_tint(_x, color)
	_tint(_z, color)


func _ensure_meshes() -> void:
	if _ring != null:
		return
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.58
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	add_child(_ring)
	_x = _bar(Vector3(1.7, 0.04, 0.08))
	_z = _bar(Vector3(0.08, 0.04, 1.7))
	var core := SphereMesh.new()
	core.radius = 0.12
	core.height = 0.24
	var dot := MeshInstance3D.new()
	dot.mesh = core
	add_child(dot)
	_tint(dot, Color(0.45, 0.92, 0.52))


func _bar(size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	return mi


func _tint(mi: MeshInstance3D, color: Color) -> void:
	if mi == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mi.material_override = mat
