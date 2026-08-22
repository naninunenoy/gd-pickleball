class_name AimReticle
extends Node2D

var court_pos := Vector2(5.0, 11.25)
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
	var color := Color(0.98, 0.92, 0.45)
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, color, 2.0)
	draw_circle(Vector2.ZERO, 3.0, color)
