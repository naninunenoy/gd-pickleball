class_name CourtMap
extends RefCounted

var view_size := Vector2(1280.0, 720.0)
var scale := 14.5
var origin := Vector2.ZERO


func configure(size: Vector2) -> void:
	view_size = size
	var side_ui := 300.0
	var margin_y := 36.0
	var sx := (size.x - side_ui) / MatchRules.COURT_WIDTH
	var sy := (size.y - margin_y * 2.0) / MatchRules.COURT_LENGTH
	scale = minf(sx, sy)
	var court_px := Vector2(MatchRules.COURT_WIDTH, MatchRules.COURT_LENGTH) * scale
	origin = Vector2((size.x - court_px.x) * 0.5, (size.y - court_px.y) * 0.5)


func to_screen(court: Vector2) -> Vector2:
	return origin + court * scale


func to_court(screen: Vector2) -> Vector2:
	if scale <= 0.0:
		return Vector2.ZERO
	return (screen - origin) / scale


func feet_to_px(feet: float) -> float:
	return feet * scale
