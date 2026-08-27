class_name Court3D
extends Node3D

var serve_box := Rect2()
var show_serve_box := false
var kitchen_emphasis := true

var _serve_mesh: MeshInstance3D
var _line_south: MeshInstance3D
var _line_north: MeshInstance3D


func _ready() -> void:
	_build()


func set_serve_box(box: Rect2, shown: bool) -> void:
	serve_box = box
	show_serve_box = shown
	if _serve_mesh == null:
		return
	_serve_mesh.visible = shown
	if shown:
		_serve_mesh.position = Vector3(
			box.position.x + box.size.x * 0.5,
			0.04,
			box.position.y + box.size.y * 0.5
		)
		var mesh := _serve_mesh.mesh as BoxMesh
		if mesh:
			mesh.size = Vector3(box.size.x, 0.03, box.size.y)


func set_kitchen_emphasis(active: bool) -> void:
	kitchen_emphasis = active
	var color := Color(0.98, 0.86, 0.28) if active else Color(0.93, 0.94, 0.88)
	_tint(_line_south, color, active)
	_tint(_line_north, color, active)


func _build() -> void:
	var apron := _box(
		Vector3(36.0, 0.06, 60.0),
		Vector3(MatchRules.HALF, -0.08, MatchRules.NET_Y),
		Color(0.11, 0.20, 0.14)
	)
	apron.name = "Apron"
	var floor := _box(
		Vector3(MatchRules.COURT_WIDTH, 0.08, MatchRules.COURT_LENGTH),
		Vector3(MatchRules.HALF, -0.03, MatchRules.NET_Y),
		Color(0.20, 0.46, 0.33)
	)
	floor.name = "Floor"
	var nvz := _box(
		Vector3(MatchRules.COURT_WIDTH, 0.025, MatchRules.NVZ_DEPTH * 2.0),
		Vector3(MatchRules.HALF, 0.02, MatchRules.NET_Y),
		Color(0.16, 0.36, 0.28)
	)
	nvz.name = "NVZ"
	var line := Color(0.93, 0.94, 0.88)
	_hline(0.0, line, 0.16)
	_hline(MatchRules.COURT_LENGTH, line, 0.16)
	_vline(0.0, 0.0, MatchRules.COURT_LENGTH, line, 0.16)
	_vline(MatchRules.COURT_WIDTH, 0.0, MatchRules.COURT_LENGTH, line, 0.16)
	_vline(MatchRules.HALF, 0.0, MatchRules.NVZ_NORTH, line, 0.12)
	_vline(MatchRules.HALF, MatchRules.NVZ_SOUTH, MatchRules.COURT_LENGTH, line, 0.12)
	_line_north = _hline(MatchRules.NVZ_NORTH, Color(0.98, 0.86, 0.28), 0.28)
	_line_south = _hline(MatchRules.NVZ_SOUTH, Color(0.98, 0.86, 0.28), 0.28)
	_line_north.name = "KitchenNorth"
	_line_south.name = "KitchenSouth"
	_build_net()
	_serve_mesh = _box(
		Vector3(MatchRules.HALF, 0.03, MatchRules.SERVICE_DEPTH),
		Vector3(5.0, 0.04, 7.5),
		Color(0.95, 0.88, 0.35, 0.22)
	)
	_serve_mesh.name = "ServeBox"
	_serve_mesh.visible = false
	var serve_mesh := _serve_mesh.mesh as BoxMesh
	if serve_mesh and serve_mesh.material is StandardMaterial3D:
		(serve_mesh.material as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-28.0, -150.0, 0.0)
	fill.light_energy = 0.28
	fill.light_color = Color(0.75, 0.82, 0.9)
	fill.shadow_enabled = false
	add_child(fill)


func _build_net() -> void:
	var net := _box(
		Vector3(MatchRules.COURT_WIDTH, MatchRules.NET_HEIGHT, 0.07),
		Vector3(MatchRules.HALF, MatchRules.NET_HEIGHT * 0.5, MatchRules.NET_Y),
		Color(0.07, 0.08, 0.09, 0.62)
	)
	net.name = "Net"
	var tape := _box(
		Vector3(MatchRules.COURT_WIDTH + 0.2, 0.08, 0.1),
		Vector3(MatchRules.HALF, MatchRules.NET_HEIGHT, MatchRules.NET_Y),
		Color(0.92, 0.93, 0.9)
	)
	tape.name = "NetTape"
	_post(0.0)
	_post(MatchRules.COURT_WIDTH)


func _post(x: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.12
	mesh.height = MatchRules.NET_HEIGHT + 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(x, mesh.height * 0.5, MatchRules.NET_Y)
	mi.material_override = _mat(Color(0.75, 0.75, 0.72), true)
	add_child(mi)


func _hline(z: float, color: Color, width: float) -> MeshInstance3D:
	return _box(
		Vector3(MatchRules.COURT_WIDTH + 0.08, 0.05, width),
		Vector3(MatchRules.HALF, 0.035, z),
		color
	)


func _vline(x: float, z0: float, z1: float, color: Color, width: float) -> MeshInstance3D:
	return _box(
		Vector3(width, 0.05, absf(z1 - z0)),
		Vector3(x, 0.035, (z0 + z1) * 0.5),
		color
	)


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color, color.a < 0.99)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	return mi


func _mat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if unshaded or color.a < 0.99:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _tint(mi: MeshInstance3D, color: Color, emit: bool) -> void:
	if mi == null:
		return
	var mat := _mat(color, true)
	if emit:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.55
	mi.material_override = mat
