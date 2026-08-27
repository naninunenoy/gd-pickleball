class_name Athlete
extends Node3D

enum Team { HUMAN, CPU }
enum Side { LEFT, RIGHT }

const MOVE_SPEED := 16.0
const REACH := 3.8
const RADIUS_FT := 0.9
const BODY_HEIGHT := 5.5

var team := Team.HUMAN
var side := Side.LEFT
var court_pos := Vector2.ZERO
var is_hitter := false
var speed := 0.0

var _body: MeshInstance3D
var _paddle: MeshInstance3D
var _ring: MeshInstance3D
var _shadow: MeshInstance3D


func setup(p_team: int, p_side: int) -> void:
	team = p_team
	side = p_side
	court_pos = home_back()
	speed = 0.0
	_build_meshes()


func is_human() -> bool:
	return team == Team.HUMAN


func home_x() -> float:
	return 5.0 if side == Side.LEFT else 15.0


func home_back() -> Vector2:
	if team == Team.HUMAN:
		return Vector2(home_x(), 40.6)
	return Vector2(home_x(), 3.4)


func home_nvz() -> Vector2:
	if team == Team.HUMAN:
		return Vector2(home_x(), 30.2)
	return Vector2(home_x(), 13.8)


func serve_stance() -> Vector2:
	if team == Team.HUMAN:
		return Vector2(home_x(), 45.1)
	return Vector2(home_x(), -1.1)


func receive_stance() -> Vector2:
	if team == Team.HUMAN:
		return Vector2(home_x(), 38.4)
	return Vector2(home_x(), 5.6)


func in_nvz() -> bool:
	return MatchRules.is_in_nvz(court_pos)


func in_front() -> bool:
	if team == Team.HUMAN:
		return court_pos.y <= 32.0
	return court_pos.y >= 12.0


func move_towards(target: Vector2, delta: float) -> void:
	var prev := court_pos
	var offset := target - court_pos
	var dist := offset.length()
	if dist <= 0.04:
		court_pos = target
		speed = 0.0
		return
	court_pos += offset / dist * minf(MOVE_SPEED * delta, dist)
	if delta > 0.0:
		speed = court_pos.distance_to(prev) / delta
	else:
		speed = 0.0


func can_reach(point: Vector2) -> bool:
	return court_pos.distance_to(point) <= REACH


func sync_world() -> void:
	if _body == null:
		_build_meshes()
	position = CourtMap.to_world(court_pos, 0.0)
	var net_dir := -1.0 if is_human() else 1.0
	var set_at_line := KitchenOccupancy.is_set_athlete(self)
	_paddle.position = Vector3(0.62, 3.25 if set_at_line else 2.7, net_dir * 1.05)
	_ring.visible = is_hitter or set_at_line
	var ring_mat := _ring.material_override as StandardMaterial3D
	if ring_mat:
		if set_at_line:
			ring_mat.albedo_color = Color(0.98, 0.86, 0.28)
		elif is_hitter:
			ring_mat.albedo_color = Color(1.0, 1.0, 1.0)
		else:
			ring_mat.albedo_color = Color(0.7, 0.7, 0.7, 0.4)


func _build_meshes() -> void:
	if _body != null:
		return
	var cap := CapsuleMesh.new()
	cap.radius = 0.72
	cap.height = BODY_HEIGHT
	_body = MeshInstance3D.new()
	_body.mesh = cap
	_body.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.32, 0.78, 0.86) if is_human() else Color(0.93, 0.47, 0.33)
	_body.material_override = body_mat
	add_child(_body)
	var paddle_mesh := BoxMesh.new()
	paddle_mesh.size = Vector3(0.18, 1.15, 0.48)
	_paddle = MeshInstance3D.new()
	_paddle.mesh = paddle_mesh
	var paddle_mat := StandardMaterial3D.new()
	paddle_mat.albedo_color = Color(0.95, 0.93, 0.82)
	_paddle.material_override = paddle_mat
	add_child(_paddle)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.08
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.position = Vector3(0.0, 0.06, 0.0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1, 1, 1)
	_ring.material_override = ring_mat
	add_child(_ring)
	var shadow_mesh := SphereMesh.new()
	shadow_mesh.radius = 0.85
	shadow_mesh.height = 0.08
	_shadow = MeshInstance3D.new()
	_shadow.mesh = shadow_mesh
	_shadow.position = Vector3(0.0, 0.03, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.05, 0.07, 0.05, 0.35)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow.material_override = shadow_mat
	add_child(_shadow)
