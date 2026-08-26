class_name CameraRig
extends Node3D

## Two rigs: pulled-back when away from the kitchen, low TPS when on the line.
## Blend 0 = baseline / approach. Blend 1 = kitchen line.

const BACK_HEIGHT := 9.4
const BACK_PULL := 12.0
const BACK_SIDE := 2.6
const BACK_LOOK_HEIGHT := 1.6
const BACK_FOV := 68.0
const BACK_FOLLOW := 3.4

const KITCHEN_HEIGHT := 4.7
const KITCHEN_PULL := 3.15
const KITCHEN_SIDE := 1.28
const KITCHEN_LOOK_HEIGHT := 3.15
const KITCHEN_FOV := 50.0
const KITCHEN_FOLLOW := 9.2

@onready var camera: Camera3D = $Camera3D

var _pos := Vector3(10.0, 9.4, 52.0)
var _look := Vector3(10.0, 1.6, 29.0)
var _fov := BACK_FOV
var _blend := 0.0
var _clock := 0.0
var last_on_kitchen := false
var last_set := false
var last_shake := 0.0


static func compose(focus_court: Vector2, ball_world: Vector3, blend: float) -> Dictionary:
	var t := clampf(blend, 0.0, 1.0)
	var toward_center := 1.0 if focus_court.x < MatchRules.HALF else -1.0
	var height := lerpf(BACK_HEIGHT, KITCHEN_HEIGHT, t)
	var pull := lerpf(BACK_PULL, KITCHEN_PULL, t)
	var side := toward_center * lerpf(BACK_SIDE, KITCHEN_SIDE, t)
	var fov := lerpf(BACK_FOV, KITCHEN_FOV, t)
	var pos := Vector3(focus_court.x + side, height, focus_court.y + pull)
	var back_look := Vector3(focus_court.x, BACK_LOOK_HEIGHT, MatchRules.NVZ_SOUTH).lerp(
		Vector3(ball_world.x, clampf(ball_world.y, 0.7, 5.5), ball_world.z),
		0.32
	)
	var net_look := Vector3(
		lerpf(focus_court.x, MatchRules.HALF, 0.22),
		KITCHEN_LOOK_HEIGHT,
		MatchRules.NET_Y - 1.8
	)
	var kitchen_look := net_look.lerp(
		Vector3(ball_world.x, maxf(ball_world.y, 1.4), ball_world.z),
		0.58
	)
	var look: Vector3 = back_look.lerp(kitchen_look, t)
	return {"pos": pos, "look": look, "fov": fov}


static func follow_speed(blend: float, is_set: bool) -> float:
	if blend > 0.7 and is_set:
		return KITCHEN_FOLLOW
	return lerpf(BACK_FOLLOW, KITCHEN_FOLLOW * 0.55, blend)


func camera_node() -> Camera3D:
	return camera


func mouse_to_court(mouse: Vector2) -> Variant:
	return CourtMap.mouse_on_ground(camera, mouse)


func snap_to(focus_court: Vector2, ball_world: Vector3, on_kitchen: bool) -> void:
	_blend = 1.0 if on_kitchen else 0.0
	var desired := compose(focus_court, ball_world, _blend)
	_pos = desired.pos
	_look = desired.look
	_fov = desired.fov
	_apply(0.0)


func apply(
	delta: float,
	focus_court: Vector2,
	ball_world: Vector3,
	on_kitchen: bool,
	is_set: bool,
	move_speed: float,
	snap: bool = false
) -> void:
	_clock += delta
	var target_blend := 1.0 if on_kitchen else 0.0
	if snap:
		_blend = target_blend
	else:
		_blend = move_toward(_blend, target_blend, delta * 1.7)
	last_on_kitchen = on_kitchen
	last_set = is_set
	var desired := compose(focus_court, ball_world, _blend)
	var shake := 0.0
	if not (on_kitchen and is_set):
		shake = clampf(move_speed * 0.045, 0.0, 0.38)
	last_shake = shake
	if snap:
		_pos = desired.pos
		_look = desired.look
		_fov = desired.fov
	else:
		var k := 1.0 - exp(-follow_speed(_blend, is_set) * delta)
		_pos = _pos.lerp(desired.pos, k)
		_look = _look.lerp(desired.look, k)
		_fov = lerpf(_fov, desired.fov, k)
	_apply(shake)


func _apply(shake: float) -> void:
	if camera == null:
		return
	var wobble := Vector3.ZERO
	if shake > 0.001:
		wobble = Vector3(
			sin(_clock * 29.0) * shake,
			cos(_clock * 23.5) * shake * 0.45,
			sin(_clock * 17.0) * shake * 0.25
		)
	camera.global_position = _pos + wobble
	if camera.global_position.distance_to(_look) > 0.2:
		camera.look_at(_look, Vector3.UP)
	camera.fov = _fov
