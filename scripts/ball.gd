class_name RallyBall
extends Node2D

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
var map: CourtMap
var just_first_bounce := false
var just_second_bounce := false
var just_net := false


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


func launch(from: Vector2, from_h: float, to: Vector2, shot: int) -> void:
	start_pos = from
	land_pos = to
	start_height = from_h
	end_height = 0.0
	apex_extra = ShotCatalog.apex_extra(shot)
	duration = maxf(ShotCatalog.flight_time(shot), 0.12)
	time = 0.0
	bounce_count = 0
	ground_pos = from
	last_ground = from
	height = from_h
	stage = Stage.FLIGHT
	just_first_bounce = false
	just_second_bounce = false
	just_net = false


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
	if stage == Stage.FLIGHT and _crossed_net():
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
	duration = 0.52
	time = 0.0
	ground_pos = start_pos
	height = start_height


func sync_screen() -> void:
	if map == null:
		return
	position = map.to_screen(ground_pos)
	queue_redraw()


func _draw() -> void:
	if map == null or stage == Stage.IDLE:
		return
	var shadow := map.feet_to_px(0.35 + height * 0.04)
	draw_circle(Vector2.ZERO, shadow, Color(0.05, 0.07, 0.05, 0.35))
	var lift := Vector2(0.0, -map.feet_to_px(height) * 0.55)
	if stage == Stage.FLIGHT:
		var land_px := map.to_screen(land_pos) - position
		draw_arc(land_px, 8.0, 0.0, TAU, 20, Color(0.95, 0.9, 0.35, 0.45), 1.5)
	var ball_r := map.feet_to_px(0.32)
	draw_circle(lift, ball_r, Color(0.96, 0.93, 0.28))
	draw_arc(lift, ball_r, 0.0, TAU, 20, Color(0.2, 0.18, 0.05, 0.7), 1.2)
