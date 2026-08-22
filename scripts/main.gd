extends Node2D

enum Phase { SERVE_AIM, IN_FLIGHT, POINT_END, MATCH_END }

const POINT_PAUSE := 1.45
const CPU_SERVE_DELAY := 0.8

var map := CourtMap.new()
var phase: Phase = Phase.SERVE_AIM
var human_score := 0
var cpu_score := 0
var human_serving := true
var hits_completed := 0
var last_hitter_human := true
var armed := ShotCatalog.Id.DRIVE
var point_reason := ""
var phase_time := 0.0
var auto_rally := false
var _pressed_shot := -1

var human_left: Athlete
var human_right: Athlete
var cpu_left: Athlete
var cpu_right: Athlete
var ball: RallyBall
var reticle: AimReticle

@onready var court_view: CourtView = $CourtView
@onready var world: Node2D = $World
@onready var score_label: Label = $UI/Score
@onready var status_label: Label = $UI/Status
@onready var shots_label: Label = $UI/Shots
@onready var help_label: Label = $UI/Help
@onready var reason_label: Label = $UI/Reason

var _ui_font: Font


func _ready() -> void:
	auto_rally = "--auto-rally" in OS.get_cmdline_args() or "--auto-rally" in OS.get_cmdline_user_args()
	_ensure_actions()
	_apply_ui_font()
	map.configure(get_viewport_rect().size)
	court_view.map = map
	_spawn_world()
	help_label.text = "\n".join([
		"WASD / stick  aim",
		"IJKL / face buttons  shot",
		"I/Y drive   K/A drop",
		"L/B volley  J/X smash",
		"",
		"Press a shot to hit.",
		"Movement is automatic.",
	])
	_start_match()


func _spawn_world() -> void:
	human_left = _make_athlete(Athlete.Team.HUMAN, Athlete.Side.LEFT)
	human_right = _make_athlete(Athlete.Team.HUMAN, Athlete.Side.RIGHT)
	cpu_left = _make_athlete(Athlete.Team.CPU, Athlete.Side.LEFT)
	cpu_right = _make_athlete(Athlete.Team.CPU, Athlete.Side.RIGHT)
	ball = RallyBall.new()
	ball.map = map
	ball.z_index = 30
	world.add_child(ball)
	reticle = AimReticle.new()
	reticle.map = map
	reticle.z_index = 8
	world.add_child(reticle)


func _make_athlete(team: int, side: int) -> Athlete:
	var athlete := Athlete.new()
	athlete.setup(team, side, map)
	world.add_child(athlete)
	return athlete


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	if view != map.view_size:
		map.configure(view)
		court_view.redraw()
	_poll_input(delta)
	phase_time += delta
	match phase:
		Phase.SERVE_AIM:
			_update_setup(delta)
			if human_serving and (_pressed_shot >= 0 or auto_rally):
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
	_sync_visuals()
	_update_ui()


func _poll_input(delta: float) -> void:
	if not InputMap.has_action("shot_north"):
		_ensure_actions()
	_pressed_shot = -1
	if Input.is_action_just_pressed("shot_north"):
		_pressed_shot = ShotCatalog.Id.DRIVE
	elif Input.is_action_just_pressed("shot_south"):
		_pressed_shot = ShotCatalog.Id.DROP
	elif Input.is_action_just_pressed("shot_east"):
		_pressed_shot = ShotCatalog.Id.VOLLEY
	elif Input.is_action_just_pressed("shot_west"):
		_pressed_shot = ShotCatalog.Id.SMASH
	if _pressed_shot >= 0:
		armed = _pressed_shot
		if phase == Phase.MATCH_END:
			_start_match()
	if Input.is_action_just_pressed("confirm") and phase == Phase.MATCH_END:
		_start_match()
	var can_aim := phase != Phase.MATCH_END and not (phase == Phase.SERVE_AIM and human_serving)
	if can_aim:
		reticle.move(Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down"), delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_start_match()
		get_viewport().set_input_as_handled()


func _apply_ui_font() -> void:
	_ui_font = load("res://fonts/Inter-Regular.ttf")
	if _ui_font == null:
		return
	for label in [score_label, status_label, shots_label, help_label, reason_label]:
		label.add_theme_font_override("font", _ui_font)


func _start_match() -> void:
	human_score = 0
	cpu_score = 0
	human_serving = true
	armed = ShotCatalog.Id.DRIVE
	point_reason = ""
	_begin_point()


func _begin_point() -> void:
	phase = Phase.SERVE_AIM
	phase_time = 0.0
	hits_completed = 0
	last_hitter_human = human_serving
	point_reason = ""
	_snap_to_setup()
	reticle.court_pos = Vector2(10.0, 9.0)
	court_view.serve_box = _serve_box()
	court_view.show_serve_box = true
	court_view.redraw()
	_place_held_ball()


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
	var shot := ShotCatalog.Id.DRIVE
	if _pressed_shot == ShotCatalog.Id.DROP:
		shot = ShotCatalog.Id.DROP
	armed = shot
	var target := MatchRules.serve_land_point(human_serving, _server_score())
	court_view.show_serve_box = false
	court_view.redraw()
	_execute_hit(server, shot, target, false)


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
	if ball.in_air() and defending_human and _pressed_shot == ShotCatalog.Id.VOLLEY and MatchRules.volley_legal(hits_completed):
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
			swing = ShotCatalog.Id.DRIVE
		if swing < 0:
			return
		_try_human_swing(hitter, swing)
		return
	if ball.in_air():
		return
	if ball.waiting_after_bounce() and hitter.can_reach(ball.ground_pos):
		_human_or_ai_hit(hitter, false)


func _try_human_swing(hitter: Athlete, shot: int) -> void:
	if ball.in_air():
		if not MatchRules.volley_legal(hits_completed):
			return
		if shot != ShotCatalog.Id.VOLLEY and shot != ShotCatalog.Id.SMASH:
			return
		if not hitter.can_reach(ball.ground_pos):
			return
		if hitter.in_nvz():
			_end_point(last_hitter_human, "Kitchen volley")
			return
		armed = shot
		_human_or_ai_hit(hitter, true)
		return
	if ball.waiting_after_bounce() and hitter.can_reach(ball.ground_pos):
		armed = shot
		_human_or_ai_hit(hitter, false)


func _human_or_ai_hit(hitter: Athlete, in_air: bool) -> void:
	var shot := ShotCatalog.Id.DRIVE
	var target: Vector2
	if hitter.is_human():
		shot = ShotCatalog.resolve_armed(armed, in_air, ball.height, MatchRules.volley_legal(hits_completed))
		target = reticle.court_pos
	else:
		shot = ShotCatalog.Id.DROP if hitter.in_front() else ShotCatalog.Id.DRIVE
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
	ball.launch(hitter.court_pos, start_h, target, shot, hits_completed == 0)
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
	court_view.show_serve_box = false
	court_view.redraw()
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


func _sync_visuals() -> void:
	reticle.valid = MatchRules.is_in_court(reticle.court_pos) and MatchRules.is_north_of_net(reticle.court_pos)
	reticle.shown = phase != Phase.MATCH_END and not (phase == Phase.SERVE_AIM and human_serving)
	reticle.sync_screen()
	ball.sync_screen()
	for athlete in _everyone():
		athlete.sync_screen()


func _update_ui() -> void:
	score_label.text = "You  %d  -  %d  CPU" % [human_score, cpu_score]
	reason_label.text = point_reason
	if phase == Phase.MATCH_END:
		var winner := "You win" if human_score > cpu_score else "CPU wins"
		status_label.text = "Match over  %s\nPress a shot to rematch" % winner
	elif phase == Phase.SERVE_AIM:
		var who := "Your serve" if human_serving else "CPU serve"
		status_label.text = "%s\nPress a shot button" % who
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
	var lines: PackedStringArray = ["Shots  (press to hit)"]
	lines.append(_shot_row(ShotCatalog.Id.DRIVE, "Y / I", "Drive"))
	lines.append(_shot_row(ShotCatalog.Id.DROP, "A / K", "Drop / Dink"))
	lines.append(_shot_row(ShotCatalog.Id.VOLLEY, "B / L", "Volley"))
	lines.append(_shot_row(ShotCatalog.Id.SMASH, "X / J", "Smash"))
	shots_label.text = "\n".join(lines)


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


func _exit_tree() -> void:
	if auto_rally:
		print("auto_rally end: hits=%d score=%d-%d phase=%d" % [hits_completed, human_score, cpu_score, phase])


func _ensure_actions() -> void:
	_setup_action("aim_left", [_key_event(KEY_A), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_setup_action("aim_right", [_key_event(KEY_D), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_setup_action("aim_up", [_key_event(KEY_W), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_setup_action("aim_down", [_key_event(KEY_S), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_setup_action("shot_north", [_key_event(KEY_I), _key_event(KEY_UP), _joy_button(JOY_BUTTON_Y)])
	_setup_action("shot_south", [_key_event(KEY_K), _key_event(KEY_DOWN), _key_event(KEY_SPACE), _joy_button(JOY_BUTTON_A)])
	_setup_action("shot_west", [_key_event(KEY_J), _key_event(KEY_LEFT), _joy_button(JOY_BUTTON_X)])
	_setup_action("shot_east", [_key_event(KEY_L), _key_event(KEY_RIGHT), _joy_button(JOY_BUTTON_B)])
	_setup_action("confirm", [_key_event(KEY_ENTER)])
	_setup_action("toggle_hitter", [_key_event(KEY_SHIFT), _joy_button(JOY_BUTTON_LEFT_SHOULDER)])
