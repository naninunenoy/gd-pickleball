class_name Minimap
extends Control

signal aim_at(court_pos: Vector2)

const PAD := 8.0

var athletes: Array[Athlete] = []
var ball_pos := Vector2.ZERO
var ball_height := 0.0
var show_ball := false
var reticle_pos := Vector2.ZERO
var show_reticle := false
var reticle_valid := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(160, 250)


static func local_to_court(local: Vector2, widget_size: Vector2) -> Vector2:
	var inner := widget_size - Vector2(PAD * 2.0, PAD * 2.0)
	if inner.x <= 0.001 or inner.y <= 0.001:
		return Vector2(MatchRules.HALF, 8.0)
	var p := (local - Vector2(PAD, PAD)) / inner
	return Vector2(p.x * MatchRules.COURT_WIDTH, p.y * MatchRules.COURT_LENGTH)


func sync_state(
	everyone: Array[Athlete],
	p_ball_pos: Vector2,
	p_ball_height: float,
	p_show_ball: bool,
	p_reticle: Vector2,
	p_show_reticle: bool,
	p_reticle_valid: bool
) -> void:
	athletes = everyone
	ball_pos = p_ball_pos
	ball_height = p_ball_height
	show_ball = p_show_ball
	reticle_pos = p_reticle
	show_reticle = p_show_reticle
	reticle_valid = p_reticle_valid
	queue_redraw()


func _draw() -> void:
	var pad := 8.0
	var inner := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
	var sx := inner.size.x / MatchRules.COURT_WIDTH
	var sy := inner.size.y / MatchRules.COURT_LENGTH
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.06, 0.62), true)
	var court := Rect2(inner.position, Vector2(MatchRules.COURT_WIDTH * sx, MatchRules.COURT_LENGTH * sy))
	draw_rect(court, Color(0.18, 0.42, 0.30, 0.95), true)
	var nvz := Rect2(
		_map(Vector2(0.0, MatchRules.NVZ_NORTH), court),
		Vector2(MatchRules.COURT_WIDTH * sx, MatchRules.NVZ_DEPTH * 2.0 * sy)
	)
	draw_rect(nvz, Color(0.14, 0.32, 0.24, 0.95), true)
	var line := Color(0.92, 0.93, 0.86, 0.9)
	draw_rect(court, line, false, 1.5)
	_h(court, MatchRules.NET_Y, Color(0.08, 0.08, 0.08, 0.95), 2.0)
	_h(court, MatchRules.NVZ_NORTH, Color(0.98, 0.86, 0.28, 0.95), 2.0)
	_h(court, MatchRules.NVZ_SOUTH, Color(0.98, 0.86, 0.28, 0.95), 2.0)
	if show_reticle:
		var rc := Color(0.45, 0.92, 0.52) if reticle_valid else Color(0.92, 0.32, 0.28)
		draw_arc(_map(reticle_pos, court), 5.0, 0.0, TAU, 16, rc, 1.4)
	for athlete in athletes:
		if athlete == null:
			continue
		var fill := Color(0.32, 0.78, 0.86) if athlete.is_human() else Color(0.93, 0.47, 0.33)
		var p := _map(athlete.court_pos, court)
		draw_circle(p, 5.5 if athlete.is_hitter else 4.2, fill)
		if KitchenOccupancy.is_set_athlete(athlete):
			draw_arc(p, 7.5, 0.0, TAU, 16, Color(0.98, 0.86, 0.28), 1.4)
	if show_ball:
		var bp := _map(ball_pos, court)
		draw_circle(bp, 3.2, Color(0.05, 0.07, 0.05, 0.4))
		draw_circle(bp + Vector2(0, -clampf(ball_height, 0.0, 8.0) * 0.7), 3.4, Color(0.96, 0.93, 0.28))


func _map(court_pos: Vector2, court: Rect2) -> Vector2:
	var sx := court.size.x / MatchRules.COURT_WIDTH
	var sy := court.size.y / MatchRules.COURT_LENGTH
	return court.position + Vector2(court_pos.x * sx, court_pos.y * sy)


func _h(court: Rect2, y_ft: float, color: Color, width: float) -> void:
	var a := _map(Vector2(0.0, y_ft), court)
	var b := _map(Vector2(MatchRules.COURT_WIDTH, y_ft), court)
	draw_line(a, b, color, width)


func _gui_input(event: InputEvent) -> void:
	var local := Vector2.ZERO
	var aiming := false
	if event is InputEventScreenTouch and event.pressed:
		local = event.position
		aiming = true
	elif event is InputEventScreenDrag:
		local = event.position
		aiming = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		local = event.position
		aiming = true
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		local = event.position
		aiming = true
	if not aiming:
		return
	aim_at.emit(CourtMap.clamp_aim(local_to_court(local, size)))
	accept_event()
