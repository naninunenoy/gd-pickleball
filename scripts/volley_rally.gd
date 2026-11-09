class_name VolleyRally
extends WallRally

## Tap/swipe volleys with a relaxed tempo. No hold power or ground bounce.
const NET_Z := 11.5
const NET_HEIGHT := 2.85
const VOLLEY_HEIGHT := 4.4
const VOLLEY_REACH := 2.8
const INCOMING_END_Z := 19.4
const LATE_RELEASE_GRACE := 0.2
const AIM_LATERAL_REACH := 4.0
const UP_ANGLE := 12.0
const DOWN_ANGLE := -5.0
const NORMAL_ANGLE := 4.0
const VERTICAL_AIM_THRESHOLD := 0.3
const SPEED_SCALE := 0.65
const MIN_PACE := 0.9
const PACE_STEP := 0.003
# Slow time without changing the launch angle or pulling down shots into the net.
const GRAVITY := 8.0 * SPEED_SCALE * SPEED_SCALE
const NET_CLEARANCE := 0.25

var opponent_returns := 0
var _return_queued := false
var _opponent_target := Vector3(6.0, VOLLEY_HEIGHT, 4.7)


func reset() -> void:
	player_count = 1
	super.reset()
	_player_positions[0] = Vector3(6.0 - hand_side() * PADDLE_SIDE, 0.0, 19.4)
	_player_positions[1] = Vector3(6.0 + hand_side() * PADDLE_SIDE, 0.0, 3.6)
	_paddle_heights.fill(VOLLEY_HEIGHT)
	ball_pos = paddle_position(0)
	last_contact_pos = ball_pos
	receive_apex = paddle_position(0)
	target_x = 6.0
	opponent_returns = 0
	_opponent_target = paddle_position(1)


func set_player_count(_count: int) -> void:
	player_count = 1
	reset()


func paddle_position(index: int = -1) -> Vector3:
	var selected := 0 if index < 0 else index
	var facing := -1.0 if selected == 1 else 1.0
	return _player_positions[selected] + Vector3(hand_side() * PADDLE_SIDE * facing, _paddle_heights[selected], -PADDLE_FORWARD * facing)


func movement_target(index: int = -1) -> Vector3:
	if index == 1:
		var racket_x := _opponent_target.x if phase == Phase.OUTBOUND else 6.0
		return Vector3(racket_x + hand_side() * PADDLE_SIDE, 0.0, 3.6)
	return _player_positions[0]


func pace() -> float:
	return maxf(MIN_PACE, 1.0 - float(returns) * PACE_STEP)


func flight_time(start: Vector3, end: Vector3) -> float:
	return Vector2(end.x - start.x, end.z - start.z).length() / (NORMAL_BALL_SPEED * SPEED_SCALE) * pace()


func can_return() -> bool:
	return phase == Phase.RETURNING and paddle_position(0).distance_to(ball_pos) <= VOLLEY_REACH


func can_power_return() -> bool:
	return can_return()


func can_tap() -> bool:
	return phase == Phase.RETURNING


func has_queued_shot() -> bool:
	return _return_queued


func cancel_charge() -> void:
	super.cancel_charge()
	_return_queued = false


func bounce_progress() -> float:
	return clampf(phase_time / _duration, 0.0, 1.0) if phase == Phase.RETURNING else 0.0


func press() -> void:
	if charging:
		return
	cancel_charge()
	super.press()


func release(_held_seconds: float = -1.0, aim: Vector2 = Vector2.ZERO) -> void:
	if not charging:
		return
	cancel_charge()
	_request_shot(aim)


func tap(aim: Vector2 = Vector2.ZERO) -> void:
	if not charging:
		_request_shot(aim)


func _request_shot(aim: Vector2) -> void:
	if phase == Phase.READY or phase == Phase.MISSED:
		reset()
		_launch(0.0, aim)
	elif phase == Phase.RETURNING or phase == Phase.OUTBOUND:
		_pending_charge = 0.0
		_pending_aim = aim
		if can_return():
			_return_ball()
		else:
			_return_queued = true
			last_feedback = "Ready to volley"


func _launch(_power: float = 0.0, aim: Vector2 = Vector2.ZERO) -> void:
	cancel_charge()
	active_player = 0
	last_hitter = 0
	last_contact_pos = ball_pos
	contact_age = 0.0
	shot_charge = 0.0
	shot_speed = 1.0
	shot_aim = aim.normalized()
	_opponent_target = Vector3(clampf(ball_pos.x + shot_aim.x * AIM_LATERAL_REACH, 2.0, 10.0), 0.0, paddle_position(1).z)
	var duration := flight_time(ball_pos, _opponent_target)
	var distance := Vector2(_opponent_target.x - ball_pos.x, _opponent_target.z - ball_pos.z).length()
	var angle := NORMAL_ANGLE
	if shot_aim.y < -VERTICAL_AIM_THRESHOLD:
		angle = UP_ANGLE
	elif shot_aim.y > VERTICAL_AIM_THRESHOLD:
		angle = DOWN_ANGLE
	# Aim sets launch slope, not a height on the opponent's side. The net
	# limits a low downward stroke while keeping its initial slope negative.
	var net_progress := (ball_pos.z - NET_Z) / (ball_pos.z - _opponent_target.z)
	var net_time := duration * net_progress
	var minimum_slope := (NET_HEIGHT + NET_CLEARANCE - ball_pos.y + 0.5 * GRAVITY * net_time * net_time) / (distance * net_progress)
	var slope := maxf(tan(deg_to_rad(angle)), minimum_slope)
	_opponent_target.y = ball_pos.y + slope * distance - 0.5 * GRAVITY * duration * duration
	last_feedback = "To your opponent"
	_segment(Phase.OUTBOUND, _opponent_target, duration, GRAVITY * duration * duration / 8.0)


func advance(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	if phase == Phase.READY or phase == Phase.MISSED:
		return
	while remaining > 0.000001 and phase != Phase.READY and phase != Phase.MISSED:
		var step := minf(remaining, 1.0 / 120.0)
		# Give a late finger-down time to become a release, keeping the ball
		# at its visible endpoint rather than letting it pass behind the camera.
		var segment_end := _duration + LATE_RELEASE_GRACE if phase == Phase.RETURNING and charging else _duration
		step = minf(step, maxf(segment_end - phase_time, 0.000001))
		remaining -= step
		phase_time += step
		contact_age += step
		_player_positions[1] = _player_positions[1].move_toward(movement_target(1), MOVE_SPEED * step)
		var height := _opponent_target.y if phase == Phase.OUTBOUND else VOLLEY_HEIGHT
		_paddle_heights[1] = move_toward(_paddle_heights[1], height, 12.0 * step)
		var progress := clampf(phase_time / _duration, 0.0, 1.0)
		ball_pos = _from.lerp(_to, progress)
		ball_pos.y += 4.0 * _apex * progress * (1.0 - progress)
		if _return_queued and can_return():
			_return_ball()
		elif phase_time >= _duration - 0.000001:
			ball_pos = _to
			if phase == Phase.OUTBOUND:
				opponent_returns += 1
				last_hitter = 1
				last_contact_pos = ball_pos
				contact_age = 0.0
				last_feedback = "Opponent returns"
				shot_charge = 0.0
				shot_speed = 1.0
				shot_aim = Vector2.ZERO
				var target := Vector3(6.0, VOLLEY_HEIGHT, INCOMING_END_Z)
				var net_progress := (NET_Z - ball_pos.z) / (target.z - ball_pos.z)
				var net_height := lerpf(ball_pos.y, target.y, net_progress)
				var arc := maxf(0.4, (NET_HEIGHT + NET_CLEARANCE - net_height) / (4.0 * net_progress * (1.0 - net_progress)))
				_segment(Phase.RETURNING, target, flight_time(ball_pos, target), arc)
			else:
				if charging and phase_time < segment_end - 0.000001:
					continue
				phase = Phase.MISSED
				cancel_charge()
				last_feedback = "The ball passed"
