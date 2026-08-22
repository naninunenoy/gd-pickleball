class_name CourtView
extends Node2D

var map: CourtMap
var serve_box := Rect2()
var show_serve_box := false


func redraw() -> void:
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var tl := map.to_screen(Vector2.ZERO)
	var size := Vector2(MatchRules.COURT_WIDTH, MatchRules.COURT_LENGTH) * map.scale
	var court := Rect2(tl, size)
	draw_rect(court, Color(0.20, 0.46, 0.33))
	var nvz_tl := map.to_screen(Vector2(0.0, MatchRules.NVZ_NORTH))
	var nvz_size := Vector2(MatchRules.COURT_WIDTH, MatchRules.NVZ_DEPTH * 2.0) * map.scale
	draw_rect(Rect2(nvz_tl, nvz_size), Color(0.16, 0.36, 0.28, 0.95))
	if show_serve_box:
		var box_tl := map.to_screen(serve_box.position)
		var box_sz := serve_box.size * map.scale
		draw_rect(Rect2(box_tl, box_sz), Color(0.95, 0.88, 0.35, 0.16))
	var line := Color(0.93, 0.94, 0.88)
	_stroke_rect(court, line, 3.0)
	_hline(MatchRules.NET_Y, line, 5.0)
	_hline(MatchRules.NVZ_NORTH, line, 2.0)
	_hline(MatchRules.NVZ_SOUTH, line, 2.0)
	_vline_segment(MatchRules.HALF, 0.0, MatchRules.NVZ_NORTH, line, 2.0)
	_vline_segment(MatchRules.HALF, MatchRules.NVZ_SOUTH, MatchRules.COURT_LENGTH, line, 2.0)
	var net := Color(0.08, 0.08, 0.08, 0.85)
	_hline(MatchRules.NET_Y, net, 2.0)
	var post_n := map.to_screen(Vector2(0.0, MatchRules.NET_Y))
	var post_s := map.to_screen(Vector2(MatchRules.COURT_WIDTH, MatchRules.NET_Y))
	draw_circle(post_n, 5.0, Color(0.75, 0.75, 0.72))
	draw_circle(post_s, 5.0, Color(0.75, 0.75, 0.72))


func _hline(y_ft: float, color: Color, width: float) -> void:
	var a := map.to_screen(Vector2(0.0, y_ft))
	var b := map.to_screen(Vector2(MatchRules.COURT_WIDTH, y_ft))
	draw_line(a, b, color, width)


func _vline_segment(x_ft: float, y0: float, y1: float, color: Color, width: float) -> void:
	draw_line(map.to_screen(Vector2(x_ft, y0)), map.to_screen(Vector2(x_ft, y1)), color, width)


func _stroke_rect(rect: Rect2, color: Color, width: float) -> void:
	var p := rect.position
	var s := rect.size
	draw_line(p, p + Vector2(s.x, 0.0), color, width)
	draw_line(p + Vector2(s.x, 0.0), p + s, color, width)
	draw_line(p + s, p + Vector2(0.0, s.y), color, width)
	draw_line(p + Vector2(0.0, s.y), p, color, width)
