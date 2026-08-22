class_name AimReticle
extends Node2D

var court_pos := Vector2(10.0, 8.0)
var valid := true
var map: CourtMap
var shown := true


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
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 28, color, 2.2)
	draw_line(Vector2(-16, 0), Vector2(16, 0), color, 1.6)
	draw_line(Vector2(0, -16), Vector2(0, 16), color, 1.6)
	draw_circle(Vector2.ZERO, 3.0, color)
