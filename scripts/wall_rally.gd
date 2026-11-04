class_name WallRally
extends RefCounted

## Deterministic, display-independent wall practice. Positions are in court feet.
enum Phase { READY, OUTBOUND, RETURNING, BOUNCED, MISSED }

const WIDTH := 12.0
const LENGTH := 23.0
const PLAYER_Z := 18.8
const CONTACT_HEIGHT := 2.2
const TAP_BUFFER := 0.18
const WINDOW_OPEN := 0.16
const WINDOW_CLOSE := 0.76

var phase: Phase = Phase.READY
var returns := 0
var best := 0
var starting_best := 0
var wall_hits := 0
var bounces := 0
var phase_time := 0.0
var ball_pos := Vector3(WIDTH * 0.5, CONTACT_HEIGHT, PLAYER_Z - 1.0)
var player_x := WIDTH * 0.5
var target_x := WIDTH * 0.5
var swing_buffer := 0.0
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
	player_x = WIDTH * 0.5
	target_x = player_x
	swing_buffer = 0.0
	last_feedback = ""
	ball_pos = Vector3(player_x + 0.7, CONTACT_HEIGHT, PLAYER_Z - 1.0)


func pace() -> float:
	return maxf(0.72, 1.0 - float(returns) * 0.009)


func bounce_progress() -> float:
	return clampf(phase_time / _duration, 0.0, 1.0) if phase == Phase.BOUNCED else 0.0


func can_return() -> bool:
	var progress := bounce_progress()
	return phase == Phase.BOUNCED and progress >= WINDOW_OPEN and progress <= WINDOW_CLOSE


func tap() -> void:
	if phase == Phase.READY or phase == Phase.MISSED:
		reset()
		_launch()
		return
	swing_buffer = TAP_BUFFER
	if can_return():
		_return_ball()
	else:
		last_feedback = "Too late" if phase == Phase.BOUNCED and bounce_progress() > WINDOW_CLOSE else "Let it bounce"


func advance(delta: float) -> void:
	# Small steps preserve contact/buffer windows even after a slow browser frame.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001 and phase != Phase.READY and phase != Phase.MISSED:
		var step := minf(remaining, 1.0 / 120.0)
		step = minf(step, maxf(_duration - phase_time, 0.000001))
		remaining -= step
		phase_time += step
		swing_buffer = maxf(0.0, swing_buffer - step)
		player_x = move_toward(player_x, target_x, step * 10.0)
		var progress := clampf(phase_time / _duration, 0.0, 1.0)
		ball_pos = _from.lerp(_to, progress)
		ball_pos.y += 4.0 * _apex * progress * (1.0 - progress)
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


func _launch() -> void:
	swing_buffer = 0.0
	bounces = 0
	last_feedback = "To the wall"
	var wall_x := clampf(player_x + sin(float(returns + 1) * 1.7) * 1.8, 2.4, WIDTH - 2.4)
	_segment(Phase.OUTBOUND, Vector3(wall_x, 3.4, 0.2), 0.72 * pace(), 0.55)


func _return_ball() -> void:
	returns += 1
	best = maxi(best, returns)
	_launch()
	last_feedback = "Nice return!" if returns % 5 != 0 else "%d in a row!" % returns


func _finish_segment() -> void:
	ball_pos = _to
	match phase:
		Phase.OUTBOUND:
			wall_hits += 1
			target_x = clampf(WIDTH * 0.5 + sin(float(wall_hits) * 1.37) * 3.1, 2.0, WIDTH - 2.0)
			_segment(Phase.RETURNING, Vector3(target_x, 0.0, 13.6), 0.92 * pace(), 0.8)
			last_feedback = "Let it bounce"
		Phase.RETURNING:
			bounces = 1
			_segment(Phase.BOUNCED, Vector3(target_x, 0.0, LENGTH), 1.12 * pace(), 2.65)
			last_feedback = "Get ready"
		Phase.BOUNCED:
			bounces = 2
			phase = Phase.MISSED
			swing_buffer = 0.0
			last_feedback = "Second bounce"
