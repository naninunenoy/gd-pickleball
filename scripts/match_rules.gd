class_name MatchRules
extends RefCounted

const COURT_WIDTH := 20.0
const COURT_LENGTH := 44.0
const NET_Y := 22.0
const NVZ_DEPTH := 7.0
const NVZ_NORTH := 15.0
const NVZ_SOUTH := 29.0
const SERVICE_DEPTH := 15.0
const HALF := 10.0
const NET_HEIGHT := 3.0
const POINTS_TO_WIN := 11


static func is_in_court(p: Vector2) -> bool:
	return p.x >= 0.0 and p.x <= COURT_WIDTH and p.y >= 0.0 and p.y <= COURT_LENGTH


static func is_in_nvz(p: Vector2) -> bool:
	return p.x >= 0.0 and p.x <= COURT_WIDTH and p.y >= NVZ_NORTH and p.y <= NVZ_SOUTH


static func is_north_of_net(p: Vector2) -> bool:
	return p.y < NET_Y


static func is_south_of_net(p: Vector2) -> bool:
	return p.y > NET_Y


static func inclusive_in_rect(p: Vector2, rect: Rect2) -> bool:
	var x1 := rect.position.x
	var y1 := rect.position.y
	var x2 := rect.position.x + rect.size.x
	var y2 := rect.position.y + rect.size.y
	return p.x >= x1 and p.x <= x2 and p.y >= y1 and p.y <= y2


static func north_left_box() -> Rect2:
	return Rect2(0.0, 0.0, HALF, SERVICE_DEPTH)


static func north_right_box() -> Rect2:
	return Rect2(HALF, 0.0, HALF, SERVICE_DEPTH)


static func south_left_box() -> Rect2:
	return Rect2(0.0, NVZ_SOUTH, HALF, SERVICE_DEPTH)


static func south_right_box() -> Rect2:
	return Rect2(HALF, NVZ_SOUTH, HALF, SERVICE_DEPTH)


## Human even score serves from screen-right to the north-left box.
static func serve_target_box(human_serving: bool, server_score: int) -> Rect2:
	var even := (server_score % 2) == 0
	if human_serving:
		return north_left_box() if even else north_right_box()
	return south_right_box() if even else south_left_box()


static func serve_from_screen_right(human_serving: bool, server_score: int) -> bool:
	var even := (server_score % 2) == 0
	if human_serving:
		return even
	return not even


static func box_center(rect: Rect2) -> Vector2:
	return rect.position + rect.size * 0.5


static func volley_legal(hits_completed: int) -> bool:
	return hits_completed >= 3


static func height_at_net(start: Vector2, land: Vector2, start_h: float, end_h: float, apex_extra: float) -> float:
	var span := land.y - start.y
	if is_zero_approx(span):
		return start_h
	var u := (NET_Y - start.y) / span
	if u <= 0.0 or u >= 1.0:
		return -1.0
	return lerpf(start_h, end_h, u) + 4.0 * apex_extra * u * (1.0 - u)


static func crosses_net(start: Vector2, land: Vector2) -> bool:
	return (start.y - NET_Y) * (land.y - NET_Y) < 0.0
