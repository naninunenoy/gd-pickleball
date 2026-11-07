class_name VolleyRally
extends WallRally

## Straight, tap-only volleys against one automatic opponent. No ground bounce.
const NET_Z := 11.5
const NET_HEIGHT := 2.85
const VOLLEY_HEIGHT := 3.2
const FLIGHT_TIME := 1.4
const VOLLEY_REACH := 2.8
const INCOMING_END_Z := 19.4

var opponent_returns := 0
var _return_queued := false


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


func set_player_count(_count: int) -> void:
	player_count = 1
	reset()


func paddle_position(index: int = -1) -> Vector3:
	var selected := 0 if index < 0 else index
	var facing := -1.0 if selected == 1 else 1.0
	return _player_positions[selected] + Vector3(hand_side() * PADDLE_SIDE * facing, _paddle_heights[selected], -PADDLE_FORWARD * facing)


func movement_target(index: int = -1) -> Vector3:
	return _player_positions[0 if index < 0 else index]


func pace() -> float:
	return 1.0 # Keep the first volley drill at a fixed, predictable rhythm.


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
	tap()


func release(_held_seconds: float = -1.0, _aim: Vector2 = Vector2.ZERO) -> void:
	pass # A volley is decided on tap-down; holding and lifting never hit again.


func tap(_aim: Vector2 = Vector2.ZERO) -> void:
	if phase == Phase.READY or phase == Phase.MISSED:
		reset()
		_launch()
	elif phase == Phase.RETURNING:
		if can_return():
			_return_ball()
		else:
			_return_queued = true
			last_feedback = "Ready to volley"


func _launch(_power: float = 0.0, _aim: Vector2 = Vector2.ZERO) -> void:
	cancel_charge()
	active_player = 0
	last_hitter = 0
	last_contact_pos = ball_pos
	contact_age = 0.0
	shot_charge = 0.0
	shot_speed = 1.0
	shot_aim = Vector2.ZERO
	last_feedback = "To your opponent"
	_segment(Phase.OUTBOUND, paddle_position(1), FLIGHT_TIME * pace(), 0.4)


func advance(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001 and phase != Phase.READY and phase != Phase.MISSED:
		var step := minf(remaining, 1.0 / 120.0)
		step = minf(step, maxf(_duration - phase_time, 0.000001))
		remaining -= step
		phase_time += step
		contact_age += step
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
				_segment(Phase.RETURNING, Vector3(6.0, VOLLEY_HEIGHT, INCOMING_END_Z), FLIGHT_TIME * pace(), 0.4)
			else:
				phase = Phase.MISSED
				cancel_charge()
				last_feedback = "The ball passed"
