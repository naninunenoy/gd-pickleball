class_name WallRally
extends RefCounted

## Deterministic, display-independent wall practice. Positions are in court feet.
enum Phase { READY, OUTBOUND, RETURNING, BOUNCED, MISSED }
enum Hand { RIGHT, LEFT }

const WIDTH := 12.0
const LENGTH := 23.0
const PLAYER_Z := 18.8
const CONTACT_HEIGHT := 2.2
const PADDLE_SIDE := 1.15
const PADDLE_FORWARD := 1.1
const CONTACT_RADIUS := 0.42
const POWER_CONTACT_RADIUS := 1.8
const DESCENDING_CONTACT_REACH := 3.0
const MOVE_SPEED := 16.0
const BOUNCE_Z := 13.6
const BOUNCE_APEX := 2.65
const NORMAL_TAP_BUFFER := 0.35
const WINDOW_OPEN := 0.16
const WINDOW_CLOSE := 0.84
const MIN_POWER_HOLD := 0.2
const MAX_CHARGE_TIME := 0.75
const MAX_SHOT_SPEED := 1.6
const SWIPE_LATERAL_REACH := 4.5
const SWIPE_HEIGHT_REACH := 1.4
const TERRITORY_OVERLAP := 0.5
const CENTER_SHARE_WIDTH := 0.2

var phase: Phase = Phase.READY
var dominant_hand: Hand = Hand.RIGHT
var player_count := 1
var active_player := 0
var last_hitter := 0
var _player_positions: Array[Vector3] = [Vector3(WIDTH * 0.5, 0.0, PLAYER_Z), Vector3(9.0, 0.0, PLAYER_Z)]
var _paddle_heights: Array[float] = [CONTACT_HEIGHT, CONTACT_HEIGHT]
var returns := 0
var best := 0
var starting_best := 0
var wall_hits := 0
var bounces := 0
var phase_time := 0.0
var ball_pos := Vector3(WIDTH * 0.5 + PADDLE_SIDE, CONTACT_HEIGHT, PLAYER_Z - PADDLE_FORWARD)
var player_pos: Vector3:
	get:
		return _player_positions[active_player]
	set(value):
		_player_positions[active_player] = value
var paddle_height: float:
	get:
		return _paddle_heights[active_player]
	set(value):
		_paddle_heights[active_player] = value
var last_contact_pos := ball_pos
var contact_age := 1.0
var target_x := WIDTH * 0.5
var receive_apex := Vector3(WIDTH * 0.5, BOUNCE_APEX, (BOUNCE_Z + LENGTH) * 0.5)
var swing_buffer := 0.0
var charging := false
var charge_time := 0.0
var shot_charge := 0.0
var shot_speed := 1.0
var shot_aim := Vector2.ZERO
var _pending_charge := 0.0
var _pending_power := false
var _pending_aim := Vector2.ZERO
var last_feedback := ""
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _duration := 1.0
var _apex := 0.0


func reset() -> void:
	phase = Phase.READY
	returns = 0
	starting_best = best
	wall_hits = 0
	bounces = 0
	phase_time = 0.0
	active_player = 0
	last_hitter = 0
	_player_positions[0] = Vector3(_home_x(0) if player_count == 2 else WIDTH * 0.5, 0.0, PLAYER_Z)
	_player_positions[1] = Vector3(_home_x(1), 0.0, PLAYER_Z)
	_paddle_heights.fill(CONTACT_HEIGHT)
	target_x = paddle_position().x
	receive_apex = trajectory_apex(Vector3(target_x, 0.0, BOUNCE_Z), Vector3(target_x, 0.0, LENGTH), BOUNCE_APEX)
	cancel_charge()
	shot_charge = 0.0
	shot_speed = 1.0
	shot_aim = Vector2.ZERO
	last_feedback = ""
	ball_pos = paddle_position()
	last_contact_pos = ball_pos
	contact_age = 1.0


func hand_side() -> float:
	return 1.0 if dominant_hand == Hand.RIGHT else -1.0


func set_player_count(count: int) -> void:
	player_count = clampi(count, 1, 2)
	reset()


func player_position(index: int) -> Vector3:
	return _player_positions[index]


func paddle_position(index: int = -1) -> Vector3:
	var selected := active_player if index < 0 else index
	return _player_positions[selected] + Vector3(hand_side() * PADDLE_SIDE, _paddle_heights[selected], -PADDLE_FORWARD)


static func trajectory_apex(start: Vector3, end: Vector3, arc_height: float) -> Vector3:
	var progress := 1.0 if end.y > start.y else 0.0
	if arc_height > 0.000001:
		progress = clampf(0.5 + (end.y - start.y) / (8.0 * arc_height), 0.0, 1.0)
	var highest := start.lerp(end, progress)
	highest.y += 4.0 * arc_height * progress * (1.0 - progress)
	return highest


func movement_target(index: int = -1) -> Vector3:
	var selected := active_player if index < 0 else index
	if player_count == 2:
		if phase == Phase.READY or phase == Phase.MISSED:
			return _player_positions[selected]
		if phase == Phase.OUTBOUND or selected != active_player:
			# Recover first. Do not chase a future rebound before it hits the wall.
			return home_position(selected)
		var goal := _feet_for_apex(receive_apex)
		var racket_x := goal.x + hand_side() * PADDLE_SIDE
		var left := 2.0 if selected == 0 else WIDTH * 0.5 - TERRITORY_OVERLAP
		var right := WIDTH * 0.5 + TERRITORY_OVERLAP if selected == 0 else WIDTH - 2.0
		goal.x = clampf(racket_x, left, right) - hand_side() * PADDLE_SIDE
		return goal
	# Keep the prepared stance until the next wall rebound supplies a new apex.
	if wall_hits > 0:
		return Vector3(receive_apex.x - hand_side() * PADDLE_SIDE, 0.0, receive_apex.z + PADDLE_FORWARD)
	return Vector3(target_x - hand_side() * PADDLE_SIDE, 0.0, PLAYER_Z)


func _move_to_contact(step: float) -> void:
	for index in range(player_count):
		var height := CONTACT_HEIGHT
		if index == active_player and (phase == Phase.RETURNING or phase == Phase.BOUNCED):
			# Prepare at the predicted apex; do not chase the falling ball.
			height = clampf(receive_apex.y, 1.0, 3.0)
		_player_positions[index] = _player_positions[index].move_toward(movement_target(index), MOVE_SPEED * step)
		_paddle_heights[index] = move_toward(_paddle_heights[index], height, 12.0 * step)


func _feet_for_apex(apex: Vector3) -> Vector3:
	return Vector3(apex.x - hand_side() * PADDLE_SIDE, 0.0, apex.z + PADDLE_FORWARD)


func _home_x(index: int) -> float:
	# Home racket lanes stay inside the court for either striking hand.
	return (3.0 if index == 0 else 9.0) - hand_side() * PADDLE_SIDE


func home_position(index: int) -> Vector3:
	return Vector3(_home_x(index), 0.0, PLAYER_Z)


func _predict_rebound() -> void:
	var slope := (_to.x - _from.x) / maxf(_from.z - _to.z, 0.1)
	target_x = clampf(_to.x + slope * (BOUNCE_Z - _to.z), 2.0, WIDTH - 2.0)
	receive_apex = trajectory_apex(Vector3(target_x, 0.0, BOUNCE_Z), Vector3(target_x, 0.0, LENGTH), BOUNCE_APEX)


func _select_receiver() -> void:
	var from_center := receive_apex.x - WIDTH * 0.5
	# Ownership follows the ball's side, not whoever is currently camping there.
	# Share ambiguous middle balls with the partner without forcing wide turns.
	if absf(from_center) <= CENTER_SHARE_WIDTH:
		active_player = 1 - last_hitter
	else:
		active_player = 0 if from_center < 0.0 else 1


func pace() -> float:
	return maxf(0.72, 1.0 - float(returns) * 0.009)


func bounce_progress() -> float:
	return clampf(phase_time / _duration, 0.0, 1.0) if phase == Phase.BOUNCED else 0.0


func can_return() -> bool:
	return _can_reach(CONTACT_RADIUS)


func can_power_return() -> bool:
	return _can_reach(POWER_CONTACT_RADIUS)


func _can_reach(rising_reach: float) -> bool:
	if phase != Phase.BOUNCED:
		return false
	var progress := bounce_progress()
	var paddle := paddle_position()
	# The prepared apex pose is not the arm's full reach. Both shot types can
	# extend to a falling ball, keeping contact on the dominant-hand side.
	var reach := DESCENDING_CONTACT_REACH if progress >= 0.5 else rising_reach
	return progress >= WINDOW_OPEN and progress <= WINDOW_CLOSE and absf(paddle.x - ball_pos.x) <= CONTACT_RADIUS and paddle.distance_to(ball_pos) <= reach


func has_queued_shot() -> bool:
	return _pending_power or swing_buffer > 0.0


func can_tap() -> bool:
	return can_return() or (phase == Phase.BOUNCED and phase_time + NORMAL_TAP_BUFFER >= _duration * 0.5 and ball_pos.z <= receive_apex.z)


func charge_fraction() -> float:
	return clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)


func press() -> void:
	if charging:
		return
	charging = true
	charge_time = 0.0
	swing_buffer = 0.0
	_pending_charge = 0.0
	_pending_power = false
	_pending_aim = Vector2.ZERO


func release(held_seconds: float = -1.0, aim: Vector2 = Vector2.ZERO) -> void:
	if not charging:
		return
	var power := charge_fraction() if held_seconds < 0.0 else clampf(held_seconds / MAX_CHARGE_TIME, 0.0, 1.0)
	cancel_charge()
	_strike(power, 0.0, true, aim)


func cancel_charge() -> void:
	charging = false
	charge_time = 0.0
	swing_buffer = 0.0
	_pending_charge = 0.0
	_pending_power = false
	_pending_aim = Vector2.ZERO


func tap(aim: Vector2 = Vector2.ZERO) -> void:
	# An early normal tap waits briefly for racket contact.
	if not charging:
		_strike(0.0, NORMAL_TAP_BUFFER, false, aim)


func _strike(power: float, buffer_time: float, power_release: bool = false, aim: Vector2 = Vector2.ZERO) -> void:
	if phase == Phase.READY or phase == Phase.MISSED:
		reset()
		_launch(power, aim)
		return
	var reachable := can_power_return() if power_release else can_return()
	if not reachable and phase == Phase.BOUNCED and ball_pos.z > receive_apex.z:
		cancel_charge()
		last_feedback = "Too late"
		return
	_pending_charge = power
	_pending_power = power_release
	_pending_aim = aim
	swing_buffer = buffer_time
	if reachable:
		_return_ball()
	else:
		last_feedback = "Too late" if phase == Phase.BOUNCED and bounce_progress() > WINDOW_CLOSE else "Let it bounce"


func advance(delta: float) -> void:
	if phase == Phase.READY or phase == Phase.MISSED:
		if charging:
			charge_time = minf(MAX_CHARGE_TIME, charge_time + maxf(delta, 0.0))
		return
	# Small steps preserve contact/buffer windows even after a slow browser frame.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001 and phase != Phase.READY and phase != Phase.MISSED:
		var step := minf(remaining, 1.0 / 120.0)
		step = minf(step, maxf(_duration - phase_time, 0.000001))
		remaining -= step
		phase_time += step
		if charging:
			charge_time = minf(MAX_CHARGE_TIME, charge_time + step)
		swing_buffer = maxf(0.0, swing_buffer - step)
		contact_age += step
		var progress := clampf(phase_time / _duration, 0.0, 1.0)
		ball_pos = _from.lerp(_to, progress)
		ball_pos.y += 4.0 * _apex * progress * (1.0 - progress)
		_move_to_contact(step)
		if has_queued_shot() and (can_power_return() if _pending_power else can_return()):
			_return_ball()
		elif phase_time >= _duration - 0.000001:
			_finish_segment()


func _segment(next_phase: Phase, target: Vector3, duration: float, apex: float) -> void:
	phase = next_phase
	phase_time = 0.0
	_from = ball_pos
	_to = target
	_duration = duration
	_apex = apex


func _launch(power: float = 0.0, aim: Vector2 = Vector2.ZERO) -> void:
	swing_buffer = 0.0
	bounces = 0
	last_feedback = "To the wall"
	last_contact_pos = ball_pos
	last_hitter = active_player
	contact_age = 0.0
	shot_charge = clampf(power, 0.0, 1.0)
	shot_speed = lerpf(1.0, MAX_SHOT_SPEED, shot_charge)
	shot_aim = aim.normalized()
	_pending_charge = 0.0
	_pending_power = false
	_pending_aim = Vector2.ZERO
	var wall_x := clampf(ball_pos.x + shot_aim.x * SWIPE_LATERAL_REACH, 2.0, WIDTH - 2.0)
	var wall_height := 3.4 - shot_aim.y * SWIPE_HEIGHT_REACH
	_segment(Phase.OUTBOUND, Vector3(wall_x, wall_height, 0.2), 0.72 * pace() / shot_speed, 0.55)
	if player_count == 2:
		# Assign input once per shot; both players recover home until wall impact.
		_predict_rebound()
		_select_receiver()


func _return_ball() -> void:
	returns += 1
	best = maxi(best, returns)
	_launch(_pending_charge, _pending_aim)
	last_feedback = "Nice return!" if returns % 5 != 0 else "%d in a row!" % returns


func _finish_segment() -> void:
	ball_pos = _to
	match phase:
		Phase.OUTBOUND:
			wall_hits += 1
			_predict_rebound()
			_segment(Phase.RETURNING, Vector3(target_x, 0.0, BOUNCE_Z), 0.92 * pace() / shot_speed, 0.8)
			last_feedback = "Let it bounce"
		Phase.RETURNING:
			bounces = 1
			_segment(Phase.BOUNCED, Vector3(target_x, 0.0, LENGTH), 1.12 * pace() / shot_speed, BOUNCE_APEX)
			last_feedback = "Get ready"
		Phase.BOUNCED:
			bounces = 2
			phase = Phase.MISSED
			cancel_charge()
			last_feedback = "Second bounce"
