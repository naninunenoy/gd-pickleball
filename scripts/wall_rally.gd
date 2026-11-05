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
const MOVE_SPEED := 16.0
const BOUNCE_Z := 13.6
const BOUNCE_APEX := 2.65
const TAP_BUFFER := 0.18
const WINDOW_OPEN := 0.16
const WINDOW_CLOSE := 0.76
const MAX_CHARGE_TIME := 0.75
const MAX_SHOT_SPEED := 1.6

var phase: Phase = Phase.READY
var dominant_hand: Hand = Hand.RIGHT
var returns := 0
var best := 0
var starting_best := 0
var wall_hits := 0
var bounces := 0
var phase_time := 0.0
var ball_pos := Vector3(WIDTH * 0.5 + PADDLE_SIDE, CONTACT_HEIGHT, PLAYER_Z - PADDLE_FORWARD)
var player_pos := Vector3(WIDTH * 0.5, 0.0, PLAYER_Z)
var paddle_height := CONTACT_HEIGHT
var last_contact_pos := ball_pos
var contact_age := 1.0
var target_x := WIDTH * 0.5
var receive_apex := Vector3(WIDTH * 0.5, BOUNCE_APEX, (BOUNCE_Z + LENGTH) * 0.5)
var swing_buffer := 0.0
var charging := false
var charge_time := 0.0
var shot_charge := 0.0
var shot_speed := 1.0
var _pending_charge := 0.0
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
	player_pos = Vector3(WIDTH * 0.5, 0.0, PLAYER_Z)
	paddle_height = CONTACT_HEIGHT
	target_x = paddle_position().x
	receive_apex = trajectory_apex(Vector3(target_x, 0.0, BOUNCE_Z), Vector3(target_x, 0.0, LENGTH), BOUNCE_APEX)
	cancel_charge()
	shot_charge = 0.0
	shot_speed = 1.0
	last_feedback = ""
	ball_pos = paddle_position()
	last_contact_pos = ball_pos
	contact_age = 1.0


func hand_side() -> float:
	return 1.0 if dominant_hand == Hand.RIGHT else -1.0


func paddle_position() -> Vector3:
	return player_pos + Vector3(hand_side() * PADDLE_SIDE, paddle_height, -PADDLE_FORWARD)


static func trajectory_apex(start: Vector3, end: Vector3, arc_height: float) -> Vector3:
	var progress := 1.0 if end.y > start.y else 0.0
	if arc_height > 0.000001:
		progress = clampf(0.5 + (end.y - start.y) / (8.0 * arc_height), 0.0, 1.0)
	var highest := start.lerp(end, progress)
	highest.y += 4.0 * arc_height * progress * (1.0 - progress)
	return highest


func movement_target() -> Vector3:
	# Keep the prepared stance until the next wall rebound supplies a new apex.
	if wall_hits > 0:
		return Vector3(receive_apex.x - hand_side() * PADDLE_SIDE, 0.0, receive_apex.z + PADDLE_FORWARD)
	return Vector3(target_x - hand_side() * PADDLE_SIDE, 0.0, PLAYER_Z)


func _move_to_contact(step: float) -> void:
	var height := CONTACT_HEIGHT
	if phase == Phase.RETURNING or phase == Phase.BOUNCED:
		# Prepare at the predicted apex; do not chase the live ball after bouncing.
		height = clampf(receive_apex.y, 1.0, 3.0)
	player_pos = player_pos.move_toward(movement_target(), MOVE_SPEED * step)
	paddle_height = move_toward(paddle_height, height, 12.0 * step)


func pace() -> float:
	return maxf(0.72, 1.0 - float(returns) * 0.009)


func bounce_progress() -> float:
	return clampf(phase_time / _duration, 0.0, 1.0) if phase == Phase.BOUNCED else 0.0


func can_return() -> bool:
	var progress := bounce_progress()
	return phase == Phase.BOUNCED and progress >= WINDOW_OPEN and progress <= WINDOW_CLOSE and paddle_position().distance_to(ball_pos) <= CONTACT_RADIUS


func charge_fraction() -> float:
	return clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)


func press() -> void:
	if charging:
		return
	charging = true
	charge_time = 0.0
	swing_buffer = 0.0
	_pending_charge = 0.0


func release(held_seconds: float = -1.0) -> void:
	if not charging:
		return
	var power := charge_fraction() if held_seconds < 0.0 else clampf(held_seconds / MAX_CHARGE_TIME, 0.0, 1.0)
	cancel_charge()
	_strike(power)


func cancel_charge() -> void:
	charging = false
	charge_time = 0.0
	swing_buffer = 0.0
	_pending_charge = 0.0


func tap() -> void:
	# Instant, uncharged input for diagnostic auto-rallies and model checks.
	if not charging:
		_strike(0.0)


func _strike(power: float) -> void:
	if phase == Phase.READY or phase == Phase.MISSED:
		reset()
		_launch(power)
		return
	_pending_charge = power
	swing_buffer = TAP_BUFFER
	if can_return():
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
		if swing_buffer > 0.0 and can_return():
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


func _launch(power: float = 0.0) -> void:
	swing_buffer = 0.0
	bounces = 0
	last_feedback = "To the wall"
	last_contact_pos = ball_pos
	contact_age = 0.0
	shot_charge = clampf(power, 0.0, 1.0)
	shot_speed = lerpf(1.0, MAX_SHOT_SPEED, shot_charge)
	_pending_charge = 0.0
	var wall_x := clampf(ball_pos.x + sin(float(returns + 1) * 1.7) * 1.8, 2.4, WIDTH - 2.4)
	_segment(Phase.OUTBOUND, Vector3(wall_x, 3.4, 0.2), 0.72 * pace() / shot_speed, 0.55)


func _return_ball() -> void:
	returns += 1
	best = maxi(best, returns)
	_launch(_pending_charge)
	last_feedback = "Nice return!" if returns % 5 != 0 else "%d in a row!" % returns


func _finish_segment() -> void:
	ball_pos = _to
	match phase:
		Phase.OUTBOUND:
			wall_hits += 1
			target_x = clampf(WIDTH * 0.5 + sin(float(wall_hits) * 1.37) * 3.1, 2.0, WIDTH - 2.0)
			receive_apex = trajectory_apex(Vector3(target_x, 0.0, BOUNCE_Z), Vector3(target_x, 0.0, LENGTH), BOUNCE_APEX)
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
