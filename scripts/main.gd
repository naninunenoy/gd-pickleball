extends Node3D

enum Phase { SERVE_AIM, IN_FLIGHT, POINT_END, MATCH_END }

const POINT_PAUSE := 1.45
const CPU_SERVE_DELAY := 0.8
const DOUBLE_CLICK := 0.2

var phase: Phase = Phase.SERVE_AIM
var human_score := 0
var cpu_score := 0
var human_serving := true
var hits_completed := 0
var last_hitter_human := true
var armed := ShotCatalog.Id.SOFT
var point_reason := ""
var phase_time := 0.0
var auto_rally := false
var paused := false
var _pressed_shot := -1
var _armed_swing := -1
var _click_wait := 0.0

var human_left: Athlete
var human_right: Athlete
var cpu_left: Athlete
var cpu_right: Athlete
var ball: RallyBall
var reticle: AimReticle

@onready var court: Court3D = $World/Court
@onready var world: Node3D = $World
@onready var camera_rig: CameraRig = $CameraRig
@onready var score_label: Label = $UI/Score
@onready var status_label: Label = $UI/Status
@onready var shots_label: Label = $UI/Shots
@onready var help_label: Label = $UI/Help
@onready var reason_label: Label = $UI/Reason
@onready var kitchen_label: Label = $UI/Kitchen
@onready var minimap: Minimap = $UI/Minimap
@onready var pause_layer: CanvasLayer = $Pause
@onready var pause_label: Label = $Pause/Label

var _ui_font: Font


func _ready() -> void:
	auto_rally = "--auto-rally" in OS.get_cmdline_args() or "--auto-rally" in OS.get_cmdline_user_args()
	_ensure_actions()
	_apply_ui_font()
	_spawn_world()
	help_label.text = "\n".join([
		"Mouse  aim",
		"Click  soft",
		"Double-click  hard",
		"Space  pause",
		"",
		"Camera drops at the kitchen line.",
		"Movement is automatic.",
	])
	_start_match()
	if "--camera-preview" in OS.get_cmdline_args() or "--camera-preview" in OS.get_cmdline_user_args():
		_run_camera_preview()


func _spawn_world() -> void:
	human_left = _make_athlete(Athlete.Team.HUMAN, Athlete.Side.LEFT)
	human_right = _make_athlete(Athlete.Team.HUMAN, Athlete.Side.RIGHT)
	cpu_left = _make_athlete(Athlete.Team.CPU, Athlete.Side.LEFT)
	cpu_right = _make_athlete(Athlete.Team.CPU, Athlete.Side.RIGHT)
	ball = RallyBall.new()
	world.add_child(ball)
	reticle = AimReticle.new()
	world.add_child(reticle)


func _make_athlete(team: int, side: int) -> Athlete:
	var athlete := Athlete.new()
	athlete.setup(team, side)
	world.add_child(athlete)
	athlete.sync_world()
	return athlete


func _process(delta: float) -> void:
	_poll_input(delta)
	if paused:
		_sync_visuals(delta, true)
		_update_ui()
		return
	phase_time += delta
	match phase:
		Phase.SERVE_AIM:
			_update_setup(delta)
			if human_serving and (_swing_ready() or auto_rally):
				_serve_now()
			elif not human_serving and phase_time >= CPU_SERVE_DELAY:
				_serve_now()
		Phase.IN_FLIGHT:
			_update_rally(delta)
		Phase.POINT_END:
			if phase_time >= POINT_PAUSE:
				if human_score >= MatchRules.POINTS_TO_WIN or cpu_score >= MatchRules.POINTS_TO_WIN:
					phase = Phase.MATCH_END
					phase_time = 0.0
				else:
					_begin_point()
		Phase.MATCH_END:
			pass
	_sync_visuals(delta, false)
	_update_ui()


func _poll_input(delta: float) -> void:
	if not InputMap.has_action("pause"):
		_ensure_actions()
	if Input.is_action_just_pressed("pause") and phase != Phase.MATCH_END:
		paused = not paused
		_set_paused_visible(paused)
		return
	if paused:
		return
	_pressed_shot = -1
	if Input.is_action_just_pressed("shot_soft"):
		_arm_swing(ShotCatalog.Id.SOFT, true)
	elif Input.is_action_just_pressed("shot_hard"):
		_arm_swing(ShotCatalog.Id.HARD, true)
	if _click_wait > 0.0:
		_click_wait -= delta
		if _click_wait <= 0.0 and _armed_swing >= 0:
			_pressed_shot = _armed_swing
	elif _armed_swing >= 0:
		_pressed_shot = _armed_swing
	if _pressed_shot >= 0:
		armed = _pressed_shot
		if phase == Phase.MATCH_END:
			_start_match()
	if Input.is_action_just_pressed("confirm") and phase == Phase.MATCH_END:
		_start_match()
	_aim_with_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_start_match()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if paused:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if phase == Phase.MATCH_END:
		_start_match()
		return
	if mouse.double_click:
		_arm_swing(ShotCatalog.Id.HARD, true)
	else:
		_arm_swing(ShotCatalog.Id.SOFT, false)


func _arm_swing(shot: int, immediate: bool) -> void:
	armed = shot
	_armed_swing = shot
	_click_wait = 0.0 if immediate else DOUBLE_CLICK
	if immediate:
		_pressed_shot = shot


func _swing_ready() -> bool:
	return _armed_swing >= 0 and _click_wait <= 0.0


func _clear_swing() -> void:
	_armed_swing = -1
	_click_wait = 0.0
	_pressed_shot = -1


func _aim_with_mouse() -> void:
	if phase == Phase.MATCH_END or (phase == Phase.SERVE_AIM and human_serving):
		return
	var hit: Variant = camera_rig.mouse_to_court(get_viewport().get_mouse_position())
	if hit == null:
		return
	var court_pos: Vector2 = hit
	court_pos.x = clampf(court_pos.x, -2.0, 22.0)
	court_pos.y = clampf(court_pos.y, -2.0, MatchRules.NET_Y - 0.35)
	reticle.court_pos = court_pos


func _can_volley_now() -> bool:
	return MatchRules.volley_legal(hits_completed) and ball.in_air() and not MatchRules.is_in_nvz(ball.ground_pos)


func _ball_on_defender_side(defending_human: bool) -> bool:
	if defending_human:
		return MatchRules.is_south_of_net(ball.ground_pos)
	return MatchRules.is_north_of_net(ball.ground_pos)


func _apply_ui_font() -> void:
	_ui_font = load("res://fonts/Inter-Regular.ttf")
	if _ui_font == null:
		return
	for label in [score_label, status_label, shots_label, help_label, reason_label, kitchen_label, pause_label]:
		label.add_theme_font_override("font", _ui_font)


func _start_match() -> void:
	paused = false
	_set_paused_visible(false)
	_clear_swing()
	human_score = 0
	cpu_score = 0
	human_serving = true
	armed = ShotCatalog.Id.SOFT
	point_reason = ""
	_begin_point()


func _begin_point() -> void:
	phase = Phase.SERVE_AIM
	phase_time = 0.0
	hits_completed = 0
	last_hitter_human = human_serving
	point_reason = ""
	_snap_to_setup()
	_clear_swing()
	reticle.court_pos = Vector2(10.0, 8.0)
	court.set_serve_box(_serve_box(), true)
	_place_held_ball()
	_sync_visuals(0.0, true)


func _server_score() -> int:
	return human_score if human_serving else cpu_score


func _serve_box() -> Rect2:
	return MatchRules.serve_target_box(human_serving, _server_score())


func _server() -> Athlete:
	var from_right := MatchRules.serve_from_screen_right(human_serving, _server_score())
	if human_serving:
		return human_right if from_right else human_left
	return cpu_right if from_right else cpu_left


func _receiver() -> Athlete:
	var right_box := _serve_box().position.x >= MatchRules.HALF - 0.01
	if human_serving:
		return cpu_right if right_box else cpu_left
	return human_right if right_box else human_left


func _snap_to_setup() -> void:
	for athlete in _everyone():
		athlete.is_hitter = false
		athlete.court_pos = athlete.home_back()
		athlete.speed = 0.0
	var server := _server()
	var receiver := _receiver()
	server.court_pos = server.serve_stance()
	server.is_hitter = true
	receiver.court_pos = receiver.receive_stance()


func _update_setup(delta: float) -> void:
	_snap_to_setup()
	for athlete in _everyone():
		athlete.move_towards(athlete.court_pos, delta)
	_place_held_ball()


func _place_held_ball() -> void:
	var server := _server()
	var inward := -1.35 if server.is_human() else 1.35
	ball.hold(Vector2(server.court_pos.x, server.court_pos.y + inward), 2.6)


func _serve_now() -> void:
	if phase != Phase.SERVE_AIM:
		return
	var server := _server()
	var shot := ShotCatalog.Id.HARD
	if _armed_swing == ShotCatalog.Id.SOFT or _pressed_shot == ShotCatalog.Id.SOFT:
		shot = ShotCatalog.Id.SOFT
	armed = shot
	var target := MatchRules.serve_land_point(human_serving, _server_score())
	court.set_serve_box(_serve_box(), false)
	_execute_hit(server, shot, target, false)
	_clear_swing()


func _update_rally(delta: float) -> void:
	_move_live_athletes(delta)
	ball.advance(delta)
	if ball.just_net:
		_end_point(not last_hitter_human, "Net")
		return
	if ball.just_first_bounce:
		if not _bounce_is_legal(ball.ground_pos):
			return
	if ball.just_second_bounce:
		_end_point(last_hitter_human, "Double bounce")
		return
	_try_contact()


func _bounce_is_legal(pos: Vector2) -> bool:
	if hits_completed == 1:
		return true
	if not MatchRules.is_in_court(pos):
		_end_point(not last_hitter_human, "Out")
		return false
	return true


func _contact_point(defending_human: bool) -> Vector2:
	if _can_volley_now() and _ball_on_defender_side(defending_human):
		return ball.ground_pos
	return ball.predicted_land()


func _move_live_athletes(delta: float) -> void:
	var defending_human := not last_hitter_human
	var contact := _contact_point(defending_human)
	var hitter := _pick_hitter(defending_human, contact)
	for athlete in _everyone():
		athlete.is_hitter = athlete == hitter
		var target := athlete.home_back()
		if athlete == hitter:
			target = contact
		elif athlete.team == hitter.team:
			target = _partner_home(athlete, hitter)
		else:
			target = athlete.home_nvz() if _approach_nvz() else athlete.home_back()
		athlete.move_towards(target, delta)


func _approach_nvz() -> bool:
	return hits_completed >= 2


func _partner_home(partner: Athlete, hitter: Athlete) -> Vector2:
	var home := partner.home_nvz() if _approach_nvz() else partner.home_back()
	if hitter.side == Athlete.Side.LEFT and hitter.court_pos.x < 4.2 and partner.side == Athlete.Side.RIGHT:
		home.x -= 1.8
	elif hitter.side == Athlete.Side.RIGHT and hitter.court_pos.x > 15.8 and partner.side == Athlete.Side.LEFT:
		home.x += 1.8
	return home


func _pick_hitter(human_team: bool, contact: Vector2) -> Athlete:
	var pair := _team(human_team)
	var left := pair[0]
	var right := pair[1]
	var d_left := left.court_pos.distance_to(contact)
	var d_right := right.court_pos.distance_to(contact)
	if absf(d_left - d_right) < 0.5:
		return left if contact.x <= MatchRules.HALF else right
	return left if d_left < d_right else right


func _try_contact() -> void:
	if phase != Phase.IN_FLIGHT or not ball.is_live():
		return
	var defending_human := not last_hitter_human
	var hitter := _pick_hitter(defending_human, _contact_point(defending_human))
	if defending_human:
		var swing := _pressed_shot
		if auto_rally and swing < 0:
			swing = ShotCatalog.Id.HARD
		if swing < 0:
			return
		_try_human_swing(hitter, swing)
		return
	_try_cpu_swing(hitter)


func _try_human_swing(hitter: Athlete, shot: int) -> void:
	if ball.in_air():
		if not _can_volley_now() or not _ball_on_defender_side(true):
			return
		if not hitter.can_reach(ball.ground_pos):
			return
		if hitter.in_nvz():
			_end_point(last_hitter_human, "Kitchen volley")
			return
		armed = shot
		_human_or_ai_hit(hitter, true)
		_clear_swing()
		return
	if ball.waiting_after_bounce() and hitter.can_reach(ball.ground_pos):
		armed = shot
		_human_or_ai_hit(hitter, false)
		_clear_swing()


func _try_cpu_swing(hitter: Athlete) -> void:
	if ball.in_air():
		if not _can_volley_now() or not _ball_on_defender_side(false):
			return
		if not hitter.can_reach(ball.ground_pos):
			return
		if hitter.in_nvz():
			return
		_human_or_ai_hit(hitter, true)
		return
	if ball.waiting_after_bounce() and hitter.can_reach(ball.ground_pos):
		_human_or_ai_hit(hitter, false)


func _human_or_ai_hit(hitter: Athlete, in_air: bool) -> void:
	var shot := ShotCatalog.Id.HARD
	var target: Vector2
	if hitter.is_human():
		shot = armed
		target = reticle.court_pos
	else:
		shot = ShotCatalog.Id.SOFT if hitter.in_front() else ShotCatalog.Id.HARD
		target = Vector2(10.0, 36.0) + Vector2(randf_range(-2.0, 2.0), randf_range(-2.2, 2.2))
		target.x = clampf(target.x, 1.6, 18.4)
		target.y = clampf(target.y, 31.0, 42.5)
	_execute_hit(hitter, shot, target, in_air)


func _execute_hit(hitter: Athlete, shot: int, target: Vector2, _in_air: bool) -> void:
	if not MatchRules.crosses_net(hitter.court_pos, target):
		last_hitter_human = hitter.is_human()
		_end_point(not hitter.is_human(), "Net")
		return
	var start_h := ShotCatalog.start_height(shot, ball.height)
	ball.launch(hitter.court_pos, start_h, target, shot, hits_completed == 0, _in_air)
	last_hitter_human = hitter.is_human()
	hits_completed += 1
	phase = Phase.IN_FLIGHT
	phase_time = 0.0


func _end_point(human_won: bool, reason: String) -> void:
	if phase == Phase.POINT_END or phase == Phase.MATCH_END:
		return
	phase = Phase.POINT_END
	phase_time = 0.0
	point_reason = reason
	ball.stage = RallyBall.Stage.DEAD
	if human_won:
		human_score += 1
	else:
		cpu_score += 1
	human_serving = human_won
	court.set_serve_box(_serve_box(), false)
	_clear_swing()
	if auto_rally:
		print("point: %s  score %d-%d  hits %d" % [reason, human_score, cpu_score, hits_completed])


func _team(human_team: bool) -> Array[Athlete]:
	var pair: Array[Athlete] = []
	if human_team:
		pair.assign([human_left, human_right])
	else:
		pair.assign([cpu_left, cpu_right])
	return pair


func _everyone() -> Array[Athlete]:
	var all: Array[Athlete] = []
	all.assign([human_left, human_right, cpu_left, cpu_right])
	return all


func _human_closer_to_net() -> Athlete:
	if human_left.court_pos.y <= human_right.court_pos.y:
		return human_left
	return human_right


func _focus_athlete() -> Athlete:
	if phase == Phase.SERVE_AIM:
		if human_serving:
			return _server()
		var receiver := _receiver()
		return receiver if receiver.is_human() else _human_closer_to_net()
	if not last_hitter_human:
		return _pick_hitter(true, _contact_point(true))
	return _human_closer_to_net()


func _sync_visuals(delta: float, snap_camera: bool) -> void:
	var show_aim := phase != Phase.MATCH_END and not (phase == Phase.SERVE_AIM and human_serving)
	reticle.valid = MatchRules.is_in_court(reticle.court_pos) and MatchRules.is_north_of_net(reticle.court_pos)
	reticle.shown = show_aim
	reticle.sync_world()
	ball.sync_world()
	for athlete in _everyone():
		athlete.sync_world()
	var focus := _focus_athlete()
	var on_kitchen := KitchenOccupancy.in_front_view(focus.court_pos, true)
	var is_set := KitchenOccupancy.is_set_athlete(focus)
	var ball_world := CourtMap.to_world(ball.ground_pos, ball.height)
	camera_rig.apply(delta, focus.court_pos, ball_world, on_kitchen, is_set, focus.speed, snap_camera)
	court.set_kitchen_emphasis(not on_kitchen)
	minimap.sync_state(
		_everyone(),
		ball.ground_pos,
		ball.height,
		ball.stage != RallyBall.Stage.IDLE,
		reticle.court_pos,
		show_aim,
		reticle.valid
	)


func _update_ui() -> void:
	score_label.text = "You  %d  -  %d  CPU" % [human_score, cpu_score]
	reason_label.text = point_reason
	if paused:
		status_label.text = "Paused\nSpace to resume"
	elif phase == Phase.MATCH_END:
		var winner := "You win" if human_score > cpu_score else "CPU wins"
		status_label.text = "Match over  %s\nClick to rematch" % winner
	elif phase == Phase.SERVE_AIM:
		if human_serving:
			status_label.text = "Your serve\nClick to serve"
		else:
			status_label.text = "CPU serve"
	elif phase == Phase.POINT_END:
		var who := "you" if human_serving else "CPU"
		status_label.text = "%s\nNext serve: %s" % [point_reason, who]
	elif not MatchRules.volley_legal(hits_completed):
		status_label.text = "Let it bounce\nDouble bounce"
	else:
		var def_human := not last_hitter_human
		var hitter := _pick_hitter(def_human, _contact_point(def_human))
		if def_human and hitter.in_nvz():
			status_label.text = "NVZ\nNo volley"
		else:
			status_label.text = "Volley OK"
	var lines: PackedStringArray = ["Hit"]
	lines.append(_shot_row(ShotCatalog.Id.SOFT, "Click", "Soft"))
	lines.append(_shot_row(ShotCatalog.Id.HARD, "Double", "Hard"))
	shots_label.text = "\n".join(lines)
	var view_name := "kitchen line" if camera_rig.last_on_kitchen else "baseline"
	if camera_rig.last_on_kitchen and camera_rig.last_set:
		view_name = "kitchen SET"
	var ball_h := _ball_height_label()
	kitchen_label.text = "\n".join([
		KitchenOccupancy.rally_phase(human_left, human_right, cpu_left, cpu_right),
		"You  %s" % KitchenOccupancy.describe_team(human_left, human_right),
		"CPU  %s" % KitchenOccupancy.describe_team(cpu_left, cpu_right),
		"View  %s" % view_name,
		ball_h,
	])


func _ball_height_label() -> String:
	if ball == null or ball.stage == RallyBall.Stage.IDLE or ball.stage == RallyBall.Stage.DEAD:
		return "Ball  —"
	if ball.height >= ShotCatalog.SMASH_MIN_HEIGHT:
		return "Ball  high — attack"
	if ball.height < MatchRules.NET_HEIGHT:
		return "Ball  low — reset"
	return "Ball  chest"


func _shot_row(id: int, key: String, name: String) -> String:
	var mark := ">" if armed == id else " "
	return "%s %s  %s" % [mark, key, name]


func _key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	return event


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _setup_action(name: String, events: Array) -> void:
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, 0.22)
	for event in events:
		InputMap.action_add_event(name, event)


func _set_paused_visible(show: bool) -> void:
	pause_layer.visible = show


func _run_camera_preview() -> void:
	paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	_save_preview("baseline")
	phase = Phase.IN_FLIGHT
	hits_completed = 3
	last_hitter_human = true
	for athlete in _everyone():
		athlete.court_pos = athlete.home_nvz()
		athlete.speed = 0.0
		athlete.is_hitter = athlete.is_human() and athlete.side == Athlete.Side.RIGHT
	ball.hold(Vector2(10.0, 24.5), 4.2)
	_sync_visuals(0.0, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_preview("kitchen")
	get_tree().quit()


func _save_preview(label: String) -> void:
	var focus := _focus_athlete()
	print(
		"camera_preview %s on_kitchen=%s set=%s pos=%s fov=%.1f"
		% [label, camera_rig.last_on_kitchen, camera_rig.last_set, camera_rig.camera.global_position, camera_rig.camera.fov]
	)
	print("  focus=%s ball_h=%.2f" % [focus.court_pos, ball.height])
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "/tmp/gd-pickleball-%s.png" % label
		var err := img.save_png(path)
		print("  screenshot %s err=%s" % [path, err])


func _exit_tree() -> void:
	if auto_rally:
		print("auto_rally end: hits=%d score=%d-%d phase=%d" % [hits_completed, human_score, cpu_score, phase])


func _ensure_actions() -> void:
	_setup_action("aim_down", [_key_event(KEY_S), _key_event(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0), _joy_button(JOY_BUTTON_DPAD_DOWN)])
	_setup_action("aim_left", [_key_event(KEY_A), _key_event(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0), _joy_button(JOY_BUTTON_DPAD_LEFT)])
	_setup_action("aim_right", [_key_event(KEY_D), _key_event(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0), _joy_button(JOY_BUTTON_DPAD_RIGHT)])
	_setup_action("aim_up", [_key_event(KEY_W), _key_event(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0), _joy_button(JOY_BUTTON_DPAD_UP)])
	_setup_action("shot_soft", [_key_event(KEY_Z), _joy_button(JOY_BUTTON_A)])
	_setup_action("shot_hard", [_key_event(KEY_X), _joy_button(JOY_BUTTON_B)])
	_setup_action("confirm", [_key_event(KEY_ENTER)])
	_setup_action("pause", [_key_event(KEY_SPACE), _joy_button(JOY_BUTTON_START)])
	_setup_action("toggle_hitter", [_key_event(KEY_SHIFT), _joy_button(JOY_BUTTON_LEFT_SHOULDER)])
