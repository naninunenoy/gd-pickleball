class_name Court3D
extends Node3D

var _practice_parts: Array[Node3D] = []
var _volley_root: Node3D


func _ready() -> void:
	_box(Vector3(80.0, 0.1, 90.0), Vector3(6.0, -0.15, 10.0), Color("173e36"))
	_box(Vector3(16.0, 0.1, 28.0), Vector3(6.0, -0.04, 11.5), Color("bcad8d"))
	_box(Vector3(12.0, 0.08, 23.0), Vector3(6.0, 0.02, 11.5), Color("39836c"))
	_practice_parts.append(_box(Vector3(12.0, 0.03, 8.0), Vector3(6.0, 0.07, 4.0), Color("31745f")))
	var line := Color("dcdfbb")
	for x in [0.0, 12.0]:
		_box(Vector3(0.1, 0.04, 23.0), Vector3(x, 0.1, 11.5), line)
	for z in [0.0, 8.0, 23.0]:
		var stripe := _box(Vector3(12.1, 0.04, 0.1), Vector3(6.0, 0.1, z), line)
		if z == 8.0:
			_practice_parts.append(stripe)
	_practice_parts.append(_box(Vector3(0.08, 0.04, 8.0), Vector3(6.0, 0.1, 4.0), line))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, -25.0, 0.0)
	sun.light_color = Color.WHITE
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)
	_build_volley_court()


func _build_volley_court() -> void:
	_volley_root = Node3D.new()
	add_child(_volley_root)
	_box(Vector3(12.0, 0.025, 14.0), Vector3(6.0, 0.075, 11.5), Color("31745f"), _volley_root)
	for z in [4.5, 18.5]:
		_box(Vector3(12.1, 0.04, 0.1), Vector3(6.0, 0.1, z), Color("dcdfbb"), _volley_root)
	for z in [2.25, 20.75]:
		_box(Vector3(0.08, 0.04, 4.5), Vector3(6.0, 0.1, z), Color("dcdfbb"), _volley_root)
	for x in [-0.3, 12.3]:
		_box(Vector3(0.14, 3.0, 0.14), Vector3(x, 1.5, VolleyRally.NET_Z), Color("294d43"), _volley_root)
	_box(Vector3(12.6, 0.12, 0.12), Vector3(6.0, VolleyRally.NET_HEIGHT, VolleyRally.NET_Z), Color("eff0d7"), _volley_root)
	for index in range(17):
		_box(Vector3(0.025, 2.7, 0.025), Vector3(float(index) * 0.75, 1.4, VolleyRally.NET_Z), Color("547a6a"), _volley_root)
	for height in [0.15, 0.8, 1.45, 2.1]:
		_box(Vector3(12.0, 0.025, 0.025), Vector3(6.0, height, VolleyRally.NET_Z), Color("547a6a"), _volley_root)
	_volley_root.visible = false


func set_volley_mode(_enabled: bool) -> void:
	for part in _practice_parts:
		part.visible = false
	_volley_root.visible = true


func _box(size: Vector3, pos: Vector3, color: Color, root: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 0.9
	mesh.material_override = mat
	if root == null:
		add_child(mesh)
	else:
		root.add_child(mesh)
	return mesh
