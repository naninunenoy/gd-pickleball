class_name Court3D
extends Node3D

var _target: MeshInstance3D
var _flash := 0.0


func _ready() -> void:
	_box(Vector3(80.0, 0.1, 90.0), Vector3(6.0, -0.15, 10.0), Color("173e36"))
	_box(Vector3(16.0, 0.1, 28.0), Vector3(6.0, -0.04, 11.5), Color("bcad8d"))
	_box(Vector3(12.0, 0.08, 23.0), Vector3(6.0, 0.02, 11.5), Color("39836c"))
	_box(Vector3(12.0, 0.03, 8.0), Vector3(6.0, 0.07, 4.0), Color("31745f"))
	var line := Color("dcdfbb")
	for x in [0.0, 12.0]:
		_box(Vector3(0.1, 0.04, 23.0), Vector3(x, 0.1, 11.5), line)
	for z in [0.0, 8.0, 23.0]:
		_box(Vector3(12.1, 0.04, 0.1), Vector3(6.0, 0.1, z), line)
	_box(Vector3(0.08, 0.04, 8.0), Vector3(6.0, 0.1, 4.0), line)
	# A solid practice wall replaces the net and opponents.
	_box(Vector3(14.0, 8.0, 0.5), Vector3(6.0, 4.0, -0.15), Color("a4bea5"))
	_box(Vector3(14.3, 0.2, 0.7), Vector3(6.0, 8.05, -0.15), Color("e5e5c8"))
	_box(Vector3(13.8, 0.12, 0.08), Vector3(6.0, 2.6, 0.13), Color("e5e5c8"))
	for x in [-1.0, 13.0]:
		_box(Vector3(0.3, 8.0, 0.8), Vector3(x, 4.0, -0.15), Color("618f78"))
	var target_mesh := TorusMesh.new()
	target_mesh.inner_radius = 0.9
	target_mesh.outer_radius = 1.0
	_target = MeshInstance3D.new()
	_target.mesh = target_mesh
	_target.position = Vector3(6.0, 4.2, 0.16)
	_target.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("557e65")
	_target.material_override = mat
	add_child(_target)
	var label := Label3D.new()
	label.text = "W A L L   /   0 1"
	label.font = load("res://fonts/Inter-Regular.ttf")
	label.font_size = 64
	label.pixel_size = 0.01
	label.position = Vector3(6.0, 6.9, 0.2)
	label.modulate = Color("355e4d")
	label.outline_size = 0
	add_child(label)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, -25.0, 0.0)
	sun.light_color = Color.WHITE
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)


func flash_wall() -> void:
	_flash = 0.24


func animate(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _target != null:
		_target.scale = Vector3.ONE * (1.0 + _flash * 0.8)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
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
	add_child(mesh)
