class_name VolleyRally
extends WallRally

## Kitchen-line volleys and bounced dinks. No hold power.
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
const SWIPE_FULL_LENGTH := 120.0
const DINK_AIM_LIMIT := 0.65
const KITCHEN_DEPTH := 7.0
const DINK_DROP_DISTANCE := 2.2
const DINK_CONTACT_DISTANCE := 3.4
const DINK_CONTACT_HEIGHT := 1.9
const BALL_RADIUS := 0.2
const DINK_BOUNCE_TIME := 0.84
const DINK_PICKUP_OPEN := 0.08
const KITCHEN_HOME_Z := 19.4
const BASELINE_HOME_Z := 22.0
const GROUND_CONTACT_HEIGHT := 2.65
const GROUND_FAR_LANDING_Z := 5.4
const GROUND_NEAR_LANDING_Z := 17.6
const GROUND_BOUNCE_TIME := 1.15

var ground_mode := false
var kitchen_line := true
var bounce_required := false
var opponent_returns := 0
var opponent_receiver := 1
var dink_shot := false
var dink_landing := Vector3.ZERO
var ground_bounces := 0
var _return_queued := false
var _opponent_target := Vector3(6.0, VOLLEY_HEIGHT, 4.7)
var _incoming_target := Vector3(6.0, VOLLEY_HEIGHT, INCOMING_END_Z)
var _last_player_hitter := 0
var _last_opponent_hitter := 1
var _team_z := KITCHEN_HOME_Z


func reset() -> void:
	_player_positions.resize(player_count + 2)
	_paddle_heights.resize(player_count + 2)
	super.reset()
	_team_z = near_home_z()
	for index in range(player_count + 2):
		_player_positions[index] = home_position(index)
	_paddle_heights.fill(GROUND_CONTACT_HEIGHT if ground_mode else VOLLEY_HEIGHT)
	ball_pos = paddle_position(0)
	last_contact_pos = ball_pos
	receive_apex = paddle_position(0)
	target_x = paddle_position(0).x
	opponent_returns = 0
	opponent_receiver = opponent_index()
	_last_player_hitter = 0
	_last_opponent_hitter = opponent_receiver
	_opponent_target = paddle_position(opponent_receiver)
	_incoming_target = Vector3(target_x, VOLLEY_HEIGHT, INCOMING_END_Z)
	dink_shot = false
	bounce_required = false
	dink_landing = Vector3.ZERO
	ground_bounces = 0


func set_player_count(count: int) -> void:
	player_count = clampi(count, 1, 2)
	reset()


func set_court_line(front: bool) -> void:
	kitchen_line = front


func near_home_z() -> float:
	return KITCHEN_HOME_Z if kitchen_line else BASELINE_HOME_Z


func _team_target_z() -> float:
	if kitchen_line and dink_shot and (phase == Phase.RETURNING or phase == Phase.BOUNCED):
		return NET_Z + DINK_CONTACT_DISTANCE + PADDLE_FORWARD
	return near_home_z()


func opponent_index(slot: int = 0) -> int:
	return player_count + slot


func is_opponent(index: int) -> bool:
	return index >= player_count


func player_label(index: int) -> String:
	if player_count == 1 and not is_opponent(index):
		return "YOU"
	return "CPU %d" % (index - player_count + 1) if is_opponent(index) else "P%d" % (index + 1)


func paddle_position(index: int = -1) -> Vector3:
	var selected := active_player if index < 0 else index
	var facing := -1.0 if is_opponent(selected) else 1.0
	return _player_positions[selected] + Vector3(hand_side() * PADDLE_SIDE * facing, _paddle_heights[selected], -PADDLE_FORWARD * facing)


func home_position(index: int) -> Vector3:
	var opponent := is_opponent(index)
	var slot := index - player_count if opponent else index
	var racket_x := 6.0 if not opponent and player_count == 1 else (3.0 if slot == 0 else 9.0)
	var facing := -1.0 if opponent else 1.0
	var depth := (1.0 if ground_mode else 3.6) if opponent else near_home_z()
	return Vector3(racket_x - hand_side() * PADDLE_SIDE * facing, 0.0, depth)


func movement_target(index: int = -1) -> Vector3:
	var selected := active_player if index < 0 else index
	var goal := home_position(selected)
	var racket_x := goal.x + hand_side() * PADDLE_SIDE * (-1.0 if is_opponent(selected) else 1.0)
	if is_opponent(selected):
		if phase == Phase.OUTBOUND and selected == opponent_receiver:
			racket_x = _opponent_target.x
			goal.z = _opponent_target.z - PADDLE_FORWARD
	elif (phase == Phase.RETURNING or phase == Phase.BOUNCED) and selected == active_player:
		racket_x = _incoming_target.x
	if not is_opponent(selected):
		goal.z = _team_target_z()
	if is_opponent(selected) or player_count == 2:
		var slot := selected - player_count if is_opponent(selected) else selected
		racket_x = clampf(racket_x, 2.0 if slot == 0 else 6.0 - TERRITORY_OVERLAP, 6.0 + TERRITORY_OVERLAP if slot == 0 else 10.0)
	goal.x = racket_x - hand_side() * PADDLE_SIDE * (-1.0 if is_opponent(selected) else 1.0)
	return goal


func _receiver_for_course(course_x: float, team_start: int, previous: int) -> int:
	if team_start == 0 and player_count == 1:
		return team_start
	if absf(course_x - WIDTH * 0.5) <= CENTER_SHARE_WIDTH:
		return team_start + 1 - (previous - team_start)
	return team_start + (0 if course_x < WIDTH * 0.5 else 1)


func pace() -> float:
	return maxf(MIN_PACE, 1.0 - float(returns) * PACE_STEP)


func flight_time(start: Vector3, end: Vector3) -> float:
	return Vector2(end.x - start.x, end.z - start.z).length() / (NORMAL_BALL_SPEED * SPEED_SCALE) * pace()


func can_return() -> bool:
	if phase == Phase.BOUNCED:
		return phase_time >= DINK_PICKUP_OPEN and paddle_position().distance_to(ball_pos) <= VOLLEY_REACH
	return phase == Phase.RETURNING and not bounce_required and not inside_kitchen(active_player) and paddle_position().distance_to(ball_pos) <= VOLLEY_REACH


func inside_kitchen(index: int) -> bool:
	var depth := player_position(index).z - NET_Z
	return depth >= -KITCHEN_DEPTH and depth <= 0.0 if is_opponent(index) else depth >= 0.0 and depth <= KITCHEN_DEPTH


func can_power_return() -> bool:
	return can_return()


func can_tap() -> bool:
	return phase == Phase.RETURNING or phase == Phase.BOUNCED


func has_queued_shot() -> bool:
	return _return_queued


func cancel_charge() -> void:
	super.cancel_charge()
	_return_queued = false


func bounce_progress() -> float:
	return clampf(phase_time / _duration, 0.0, 1.0) if phase == Phase.RETURNING or phase == Phase.BOUNCED else 0.0


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
	if phase == Phase.MISSED:
		reset()
		_launch(0.0, aim)
	elif phase == Phase.READY:
		_launch(0.0, aim)
	elif phase == Phase.RETURNING or phase == Phase.OUTBOUND or phase == Phase.BOUNCED:
		_pending_charge = 0.0
		_pending_aim = aim
		if can_return():
			_return_ball()
		else:
			_return_queued = true
			last_feedback = "Ready to volley"


func _launch(_power: float = 0.0, aim: Vector2 = Vector2.ZERO) -> void:
	var short_swipe := aim.length() > 0.0 and aim.length() < DINK_AIM_LIMIT
	dink_shot = short_swipe or (not ground_mode and aim == Vector2.ZERO and ball_pos.y < NET_HEIGHT)
	bounce_required = dink_shot or ground_mode
	cancel_charge()
	bounces = 0
	last_hitter = active_player
	_last_player_hitter = active_player
	last_contact_pos = ball_pos
	contact_age = 0.0
	shot_charge = 0.0
	shot_speed = 1.0
	shot_aim = aim.normalized()
	_opponent_target = Vector3(clampf(ball_pos.x + shot_aim.x * AIM_LATERAL_REACH, 2.0, 10.0), 0.0, paddle_position(opponent_index()).z)
	opponent_receiver = _receiver_for_course(_opponent_target.x, player_count, _last_opponent_hitter)
	if dink_shot:
		_opponent_target.y = DINK_CONTACT_HEIGHT
		_opponent_target.z = NET_Z - DINK_CONTACT_DISTANCE
		dink_landing = Vector3(_opponent_target.x, BALL_RADIUS, NET_Z - DINK_DROP_DISTANCE)
		last_feedback = "Dink to the kitchen"
		_segment(Phase.OUTBOUND, dink_landing, _dink_flight_time(ball_pos, dink_landing), _net_arc(ball_pos, dink_landing))
		return
	if ground_mode:
		_opponent_target.y = GROUND_CONTACT_HEIGHT
		dink_landing = Vector3(_opponent_target.x, BALL_RADIUS, GROUND_FAR_LANDING_Z)
		var arc := _net_arc(ball_pos, dink_landing) + (0.6 if shot_aim.y < -VERTICAL_AIM_THRESHOLD else 0.0)
		last_feedback = "To your opponents"
		_segment(Phase.OUTBOUND, dink_landing, flight_time(ball_pos, dink_landing), arc)
		return
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


func _return_ball() -> void:
	super._return_ball()
	if dink_shot:
		last_feedback = "Dink return!"


func _dink_flight_time(start: Vector3, end: Vector3) -> float:
	return clampf(Vector2(end.x - start.x, end.z - start.z).length() / 7.0, 0.95, 1.35)


func _net_arc(start: Vector3, end: Vector3) -> float:
	var progress := (NET_Z - start.z) / (end.z - start.z)
	var height := lerpf(start.y, end.y, progress)
	return maxf(0.4, (NET_HEIGHT + NET_CLEARANCE - height) / (4.0 * progress * (1.0 - progress)))


func _opponent_return() -> void:
	opponent_returns += 1
	last_hitter = opponent_receiver
	_last_opponent_hitter = opponent_receiver
	last_contact_pos = ball_pos
	contact_age = 0.0
	last_feedback = "Opponent dinks" if dink_shot else "Opponent returns"
	shot_charge = 0.0
	shot_speed = 1.0
	shot_aim = Vector2.ZERO
	bounces = 0
	var course_x := 6.0 if player_count == 1 else clampf(WIDTH - ball_pos.x, 2.0, 10.0)
	var target := Vector3(course_x, VOLLEY_HEIGHT, near_home_z())
	if dink_shot:
		target = Vector3(course_x, BALL_RADIUS, NET_Z + DINK_DROP_DISTANCE)
		dink_landing = target
	elif ground_mode:
		target = Vector3(course_x, BALL_RADIUS, GROUND_NEAR_LANDING_Z)
		dink_landing = target
	bounce_required = dink_shot or ground_mode
	_incoming_target = target
	active_player = _receiver_for_course(course_x, 0, _last_player_hitter)
	var duration := _dink_flight_time(ball_pos, target) if dink_shot else flight_time(ball_pos, target)
	_segment(Phase.RETURNING, target, duration, _net_arc(ball_pos, target))


func _finish_volley_segment() -> void:
	ball_pos = _to
	if phase == Phase.OUTBOUND:
		if bounce_required and bounces == 0:
			bounces = 1
			ground_bounces += 1
			var duration := DINK_BOUNCE_TIME * 0.5 if dink_shot else GROUND_BOUNCE_TIME * 0.5
			_segment(Phase.OUTBOUND, _opponent_target, duration, (_opponent_target.y - BALL_RADIUS) * 0.25)
		else:
			_opponent_return()
	elif phase == Phase.RETURNING and bounce_required:
		bounces = 1
		ground_bounces += 1
		last_feedback = "Let it rise"
		var end_z := NET_Z + DINK_CONTACT_DISTANCE * 2.0 - DINK_DROP_DISTANCE if dink_shot else LENGTH
		var height := DINK_CONTACT_HEIGHT if dink_shot else GROUND_CONTACT_HEIGHT
		_segment(Phase.BOUNCED, Vector3(_incoming_target.x, BALL_RADIUS, end_z), DINK_BOUNCE_TIME if dink_shot else GROUND_BOUNCE_TIME, height - BALL_RADIUS)
	else:
		if phase == Phase.BOUNCED:
			bounces = 2
			ground_bounces += 1
		phase = Phase.MISSED
		cancel_charge()
		last_feedback = "Second bounce" if bounce_required else "The ball passed"


func _move_players(step: float) -> void:
	_team_z = move_toward(_team_z, _team_target_z(), MOVE_SPEED * step)
	for index in range(player_count + 2):
		var goal := movement_target(index)
		if is_opponent(index):
			_player_positions[index] = _player_positions[index].move_toward(goal, MOVE_SPEED * step)
		else:
			_player_positions[index].x = move_toward(_player_positions[index].x, goal.x, MOVE_SPEED * step)
			_player_positions[index].z = _team_z
		var height := GROUND_CONTACT_HEIGHT if ground_mode else VOLLEY_HEIGHT
		if phase == Phase.OUTBOUND and index == opponent_receiver:
			height = _opponent_target.y
		if bounce_required and (phase == Phase.RETURNING or phase == Phase.BOUNCED) and index == active_player:
			height = DINK_CONTACT_HEIGHT if dink_shot else GROUND_CONTACT_HEIGHT
		_paddle_heights[index] = move_toward(_paddle_heights[index], height, 12.0 * step)


func advance(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	if phase == Phase.READY or phase == Phase.MISSED:
		_move_players(remaining)
		if phase == Phase.READY:
			ball_pos = paddle_position()
		return
	while remaining > 0.000001 and phase != Phase.READY and phase != Phase.MISSED:
		var step := minf(remaining, 1.0 / 120.0)
		# Give a late finger-down time to become a release, keeping the ball
		# at its visible endpoint rather than letting it pass behind the camera.
		var segment_end := _duration + LATE_RELEASE_GRACE if phase == Phase.RETURNING and not bounce_required and charging else _duration
		step = minf(step, maxf(segment_end - phase_time, 0.000001))
		remaining -= step
		phase_time += step
		contact_age += step
		_move_players(step)
		var progress := clampf(phase_time / _duration, 0.0, 1.0)
		ball_pos = _from.lerp(_to, progress)
		ball_pos.y += 4.0 * _apex * progress * (1.0 - progress)
		if _return_queued and can_return():
			_return_ball()
		elif phase_time >= _duration - 0.000001:
			if phase == Phase.RETURNING and not bounce_required and charging and phase_time < segment_end - 0.000001:
				continue
			_finish_volley_segment()
