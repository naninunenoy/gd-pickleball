class_name KitchenOccupancy
extends RefCounted

## Just behind the NVZ line. home_nvz sits in this band; the baseline does not.
const LINE_BEHIND := 3.0
const LINE_FORWARD := 0.6
const SET_SPEED := 2.8
const APPROACH_HUMAN_Y := 36.5
const APPROACH_CPU_Y := 7.5


static func in_front_view(pos: Vector2, human: bool) -> bool:
	if human:
		return pos.y <= MatchRules.NVZ_SOUTH + LINE_BEHIND and pos.y >= MatchRules.NET_Y
	return pos.y >= MatchRules.NVZ_NORTH - LINE_BEHIND and pos.y <= MatchRules.NET_Y


static func is_on_line(pos: Vector2, human: bool) -> bool:
	if human:
		return pos.y >= MatchRules.NVZ_SOUTH - LINE_FORWARD and pos.y <= MatchRules.NVZ_SOUTH + LINE_BEHIND
	return pos.y >= MatchRules.NVZ_NORTH - LINE_BEHIND and pos.y <= MatchRules.NVZ_NORTH + LINE_FORWARD


static func is_set_on_line(pos: Vector2, human: bool, speed: float) -> bool:
	return is_on_line(pos, human) and speed <= SET_SPEED


static func is_set_athlete(athlete: Athlete) -> bool:
	return is_set_on_line(athlete.court_pos, athlete.is_human(), athlete.speed)


static func describe_player(pos: Vector2, human: bool, speed: float) -> String:
	if is_set_on_line(pos, human, speed):
		return "at the line"
	if in_front_view(pos, human):
		return "at kitchen"
	if human and pos.y <= APPROACH_HUMAN_Y:
		return "moving up"
	if not human and pos.y >= APPROACH_CPU_Y:
		return "moving up"
	return "back"


static func describe_team(left: Athlete, right: Athlete) -> String:
	var left_set := is_set_athlete(left)
	var right_set := is_set_athlete(right)
	if left_set and right_set:
		return "kitchen SET"
	if left_set or right_set:
		return "split"
	var left_d := describe_player(left.court_pos, left.is_human(), left.speed)
	var right_d := describe_player(right.court_pos, right.is_human(), right.speed)
	if left_d == "moving up" or right_d == "moving up" or left_d == "at kitchen" or right_d == "at kitchen":
		return "moving up"
	return "back"


static func rally_phase(human_left: Athlete, human_right: Athlete, cpu_left: Athlete, cpu_right: Athlete) -> String:
	var you := describe_team(human_left, human_right)
	var them := describe_team(cpu_left, cpu_right)
	var you_set := you == "kitchen SET"
	var them_set := them == "kitchen SET"
	if you_set and them_set:
		return "Both at the kitchen"
	if you_set:
		return "You have the kitchen"
	if them_set:
		return "CPU has the kitchen"
	return "Taking the kitchen"
