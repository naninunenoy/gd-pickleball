class_name RallyBall
extends Node3D

enum Stage { IDLE, HELD, FLIGHT, BOUNCE, DEAD }

var stage: Stage = Stage.IDLE
var start_pos := Vector2.ZERO
var land_pos := Vector2.ZERO
var start_height := 0.0
var end_height := 0.0
var apex_extra := 0.0
var duration := 1.0
var time := 0.0
var bounce_count := 0
var ground_pos := Vector2.ZERO
var height := 0.0
var last_ground := Vector2.ZERO
var just_first_bounce := false
var just_second_bounce := false
var just_net := false
var ignore_net := false

var _sphere: MeshInstance3D
var _shadow: MeshInstance3D
var _stem: MeshInstance3D
var _land: MeshInstance3D


func hold(pos: Vector2, h: float) -> void:
	stage = Stage.HELD
	ground_pos = pos
	last_ground = pos
	land_pos = pos
	height = h
	bounce_count = 0
	duration = 1.0
	time = 0.0
	just_first_bounce = false
	just_second_bounce = false
	just_net = false
	ignore_net = false


func launch(from: Vector2, from_h: float, to: Vector2, shot: int, skip_net: bool = false, in_air: bool = false) -> void:
	start_pos = from
	land_pos = to
	start_height = from_h
	end_height = 0.0
	apex_extra = ShotCatalog.apex_extra(shot, in_air, from_h)
	duration = maxf(ShotCatalog.flight_time(shot, in_air, from_h), 0.12)
	time = 0.0
	bounce_count = 0
	ground_pos = from
	last_ground = from
	height = from_h
	stage = Stage.FLIGHT
	just_first_bounce = false
	just_second_bounce = false
	just_net = false
	ignore_net = skip_net


func predicted_land() -> Vector2:
	if stage == Stage.BOUNCE:
		return land_pos
	if stage == Stage.FLIGHT:
		return land_pos
	return ground_pos


func in_air() -> bool:
	return stage == Stage.FLIGHT


func waiting_after_bounce() -> bool:
	return stage == Stage.BOUNCE


func is_live() -> bool:
	return stage == Stage.FLIGHT or stage == Stage.BOUNCE


func height_on_path(u: float) -> float:
	return lerpf(start_height, end_height, u) + 4.0 * apex_extra * u * (1.0 - u)


func advance(delta: float) -> void:
	just_first_bounce = false
	just_second_bounce = false
	just_net = false
	if stage != Stage.FLIGHT and stage != Stage.BOUNCE:
		return
	last_ground = ground_pos
	time += delta
	var u := clampf(time / duration, 0.0, 1.0)
	ground_pos = start_pos.lerp(land_pos, u)
	height = height_on_path(u)
	if not ignore_net and stage == Stage.FLIGHT and _crossed_net():
		var net_h := MatchRules.height_at_net(start_pos, land_pos, start_height, end_height, apex_extra)
		if net_h >= 0.0 and net_h < MatchRules.NET_HEIGHT:
			ground_pos = Vector2(ground_pos.x, MatchRules.NET_Y)
			height = maxf(net_h, 0.0)
			just_net = true
			stage = Stage.DEAD
			return
	if time >= duration:
		ground_pos = land_pos
		height = end_height
		if stage == Stage.FLIGHT:
			bounce_count = 1
			just_first_bounce = true
			_begin_bounce()
		else:
			bounce_count = 2
			just_second_bounce = true
			stage = Stage.DEAD
			height = 0.0


func _crossed_net() -> bool:
	return (last_ground.y - MatchRules.NET_Y) * (ground_pos.y - MatchRules.NET_Y) <= 0.0 and last_ground.y != ground_pos.y


func _begin_bounce() -> void:
	stage = Stage.BOUNCE
	var incoming := land_pos - start_pos
	var cont := Vector2.ZERO
	if incoming.length() > 0.01:
		cont = incoming.normalized() * 3.4
	start_pos = land_pos
	land_pos = land_pos + cont
	start_height = 0.05
	end_height = 0.0
	apex_extra = 2.15
	duration = 0.90
	time = 0.0
	ground_pos = start_pos
	height = start_height


func sync_world() -> void:
	_ensure_meshes()
	visible = stage != Stage.IDLE
	position = CourtMap.to_world(ground_pos, 0.0)
	_sphere.position = Vector3(0.0, height, 0.0)
	_shadow.scale = Vector3.ONE * (1.0 + height * 0.06)
	var stem_h := maxf(height, 0.08)
	_stem.scale = Vector3(1.0, stem_h, 1.0)
	_stem.position = Vector3(0.0, stem_h * 0.5, 0.0)
	var stem_mat := _stem.material_override as StandardMaterial3D
	if stem_mat:
		if height >= ShotCatalog.SMASH_MIN_HEIGHT:
			stem_mat.albedo_color = Color(0.98, 0.45, 0.18, 0.85)
		elif height < MatchRules.NET_HEIGHT:
			stem_mat.albedo_color = Color(0.35, 0.62, 0.95, 0.7)
		else:
			stem_mat.albedo_color = Color(0.95, 0.92, 0.4, 0.65)
	_land.visible = stage == Stage.FLIGHT
	if _land.visible:
		_land.global_position = CourtMap.to_world(land_pos, 0.04)


func _ensure_meshes() -> void:
	if _sphere != null:
		return
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.22
	ball_mesh.height = 0.44
	_sphere = MeshInstance3D.new()
	_sphere.mesh = ball_mesh
	var ball_mat := StandardMaterial3D.new()
	ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_mat.albedo_color = Color(0.96, 0.93, 0.28)
	_sphere.material_override = ball_mat
	add_child(_sphere)
	var shadow_mesh := SphereMesh.new()
	shadow_mesh.radius = 0.32
	shadow_mesh.height = 0.06
	_shadow = MeshInstance3D.new()
	_shadow.mesh = shadow_mesh
	_shadow.position = Vector3(0.0, 0.03, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.05, 0.07, 0.05, 0.35)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow.material_override = shadow_mat
	add_child(_shadow)
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.03
	stem_mesh.bottom_radius = 0.03
	stem_mesh.height = 1.0
	_stem = MeshInstance3D.new()
	_stem.mesh = stem_mesh
	var stem_mat := StandardMaterial3D.new()
	stem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stem_mat.albedo_color = Color(0.95, 0.92, 0.4, 0.65)
	_stem.material_override = stem_mat
	add_child(_stem)
	var land_mesh := TorusMesh.new()
	land_mesh.inner_radius = 0.42
	land_mesh.outer_radius = 0.58
	_land = MeshInstance3D.new()
	_land.mesh = land_mesh
	var land_mat := StandardMaterial3D.new()
	land_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	land_mat.albedo_color = Color(0.95, 0.9, 0.35, 0.7)
	land_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_land.material_override = land_mat
	_land.visible = false
	add_child(_land)
	_land.top_level = true
