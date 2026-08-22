class_name AimReticle
extends Node2D

const AIM_SPEED := 22.0

var court_pos := Vector2(10.0, 9.0)
var valid := true
var map: CourtMap
var shown := true


func move(dir: Vector2, delta: float) -> void:
	if dir.length() <= 0.01:
		return
	court_pos += dir.normalized() * AIM_SPEED * delta
	court_pos.x = clampf(court_pos.x, -3.0, 23.0)
	court_pos.y = clampf(court_pos.y, -3.0, 47.0)


func sync_screen() -> void:
	if map == null:
		return
	visible = shown
	position = map.to_screen(court_pos)
	queue_redraw()


func _draw() -> void:
	if not shown:
		return
	var color := Color(0.45, 0.92, 0.52) if valid else Color(0.92, 0.32, 0.28)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 28, color, 2.2)
	draw_line(Vector2(-18, 0), Vector2(18, 0), color, 1.6)
	draw_line(Vector2(0, -18), Vector2(0, 18), color, 1.6)
	draw_circle(Vector2.ZERO, 3.0, color)
