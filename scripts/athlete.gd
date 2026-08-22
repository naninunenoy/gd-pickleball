class_name Athlete
extends Node2D

enum Team { HUMAN, CPU }
enum Side { LEFT, RIGHT }

const MOVE_SPEED := 16.0
const REACH := 3.8
const RADIUS_FT := 0.9

var team := Team.HUMAN
var side := Side.LEFT
var court_pos := Vector2.ZERO
var is_hitter := false
var map: CourtMap


func setup(p_team: int, p_side: int, p_map: CourtMap) -> void:
	team = p_team
	side = p_side
	map = p_map
	court_pos = home_back()
	z_index = 10


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
	var offset := target - court_pos
	var dist := offset.length()
	if dist <= 0.04:
		court_pos = target
		return
	court_pos += offset / dist * minf(MOVE_SPEED * delta, dist)


func can_reach(point: Vector2) -> bool:
	return court_pos.distance_to(point) <= REACH


func sync_screen() -> void:
	if map == null:
		return
	position = map.to_screen(court_pos)
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var radius := map.feet_to_px(RADIUS_FT)
	var fill := Color(0.32, 0.78, 0.86) if is_human() else Color(0.93, 0.47, 0.33)
	var outline := Color(1, 1, 1, 0.95) if is_hitter else Color(0.08, 0.1, 0.1, 0.9)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 28, outline, 3.0 if is_hitter else 1.5)
	var net_dir := -1.0 if is_human() else 1.0
	var paddle := Vector2(0.0, net_dir * radius * 1.15)
	draw_line(Vector2.ZERO, paddle, Color(0.95, 0.93, 0.82), 4.0)
	draw_circle(paddle, 5.0, Color(0.95, 0.93, 0.82))
