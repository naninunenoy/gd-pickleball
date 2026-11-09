extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)


func _model(ground: bool, count: int, front: bool, hand: WallRally.Hand = WallRally.Hand.RIGHT) -> VolleyRally:
	var rally := VolleyRally.new()
	rally.ground_mode = ground
	rally.kitchen_line = front
	rally.dominant_hand = hand
	rally.set_player_count(count)
	return rally


func _until_return(rally: VolleyRally) -> void:
	for frame in range(1200):
		if rally.can_return() or rally.phase == WallRally.Phase.MISSED:
			return
		rally.advance(1.0 / 120.0)


func _to_cpu(rally: VolleyRally) -> void:
	for segment in range(2):
		if rally.phase != WallRally.Phase.OUTBOUND:
			return
		rally.advance(rally._duration - rally.phase_time)


func _check_rallies() -> void:
	for ground in [false, true]:
		for count in [1, 2]:
			for front in [false, true]:
				for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
					var rally := _model(ground, count, front, hand)
					_expect(rally._player_positions.size() == count + 2 and rally.phase == WallRally.Phase.READY, "both drills prepare two opponents for either near-team size")
					for index in range(count + 2):
						_expect(rally.player_position(index) == rally.home_position(index), "both hands start in their selected home lanes")
					var directions := [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
					rally.tap()
					for hit in range(15):
						_expect(rally.phase == WallRally.Phase.OUTBOUND, "normal input starts an outgoing opponent shot")
						var net_progress := (rally._from.z - VolleyRally.NET_Z) / (rally._from.z - rally._to.z)
						rally.advance(rally._duration * net_progress)
						_expect(rally.ball_pos.y >= VolleyRally.NET_HEIGHT + VolleyRally.NET_CLEARANCE - 0.001, "normal and aimed shots clear the net in both drills")
						_to_cpu(rally)
						_expect(rally.phase == WallRally.Phase.RETURNING and rally.last_hitter >= count and rally.last_hitter < count + 2, "the selected one of two CPU opponents returns")
						_expect(rally.ball_pos.distance_to(rally.paddle_position(rally.last_hitter)) < 0.002, "opponent strikes from its real racket contact")
						if ground:
							_expect(rally.ground_bounces == hit * 2 + 1 and rally.bounce_required, "rally drill makes the opponent collect a real bounce")
						rally.press()
						_until_return(rally)
						_expect(rally.can_return() and rally.returns == hit, "a held gesture never fires before release")
						if ground:
							_expect(rally.phase == WallRally.Phase.BOUNCED and rally.bounces == 1, "rally drill requires the near-side bounce")
						var contact := rally.ball_pos
						var hitter := rally.active_player
						rally.release(2.0, directions[hit % directions.size()])
						_expect(rally.returns == hit + 1 and rally.last_hitter == hitter and rally.last_contact_pos == contact, "one release returns exactly once from actual contact")
						_expect(rally.shot_charge == 0.0 and rally.shot_speed == 1.0, "gesture duration adds no hold power in either drill")
						if count == 2:
							_expect(is_equal_approx(rally.player_position(0).z, rally.player_position(1).z), "both near athletes share their front/back position")
					_expect(rally.best == 15 and rally.wall_hits == 0, "opponent rallies score returns without wall impacts")
					rally.advance(20.0)
					_expect(rally.phase == WallRally.Phase.MISSED and rally.returns == 15, "no input ends the next rally without an automatic player hit")
					rally.tap()
					_expect(rally.phase == WallRally.Phase.OUTBOUND and rally.returns == 0 and rally.best == 15, "retry preserves the record and selected line")


func _check_line_changes() -> void:
	for ground in [false, true]:
		var rally := _model(ground, 2, true)
		var original := rally.player_position(0).z
		rally.set_court_line(false)
		_expect(rally.phase == WallRally.Phase.READY and is_equal_approx(rally.player_position(0).z, original), "line selection does not teleport athletes or serve")
		rally.advance(0.05)
		_expect(rally.player_position(0).z > original and rally.player_position(0).z < VolleyRally.BASELINE_HOME_Z, "both visibly travel toward the baseline")
		_expect(is_equal_approx(rally.player_position(0).z, rally.player_position(1).z), "both move backward at exactly the same pace")
		var before_serve := rally.player_position(0)
		rally.tap()
		_expect(rally.player_position(0) == before_serve, "serving during a line transition does not teleport the team")
		var before_ball := rally.ball_pos
		var before_phase := rally.phase
		rally.tap(Vector2.RIGHT)
		rally.set_court_line(true)
		_expect(rally.ball_pos == before_ball and rally.phase == before_phase and rally.has_queued_shot(), "mid-rally line selection preserves the ball, phase and queued shot")
		for frame in range(1000):
			if rally.returns == 1 or rally.phase == WallRally.Phase.MISSED:
				break
			var prior_z := rally.player_position(0).z
			rally.advance(1.0 / 120.0)
			_expect(absf(rally.player_position(0).z - prior_z) <= WallRally.MOVE_SPEED / 120.0 + 0.001, "line motion is continuous during a live rally")
			_expect(is_equal_approx(rally.player_position(0).z, rally.player_position(1).z), "both remain together while the receiver changes")
		_expect(rally.returns == 1 and not rally.has_queued_shot(), "line switching does not lose the queued return or reset the score")
		for target in [false, true, false]:
			rally.set_court_line(target)
			rally.advance(0.03)
			_expect(is_equal_approx(rally.player_position(0).z, rally.player_position(1).z), "rapid position changes keep the team together")


func _check_dinks() -> void:
	for ground in [false, true]:
		for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
			var rally := _model(ground, 2, true, hand)
			rally.tap(Vector2.UP * 0.3)
			_expect(rally.dink_shot and rally.dink_landing.z > VolleyRally.NET_Z - VolleyRally.KITCHEN_DEPTH, "short swipe still places a dink in the opposing kitchen")
			rally.advance(rally._duration)
			_expect(rally.bounces == 1 and rally.opponent_returns == 0, "opponent waits for the dink bounce")
			_to_cpu(rally)
			_expect(rally.inside_kitchen(rally.last_hitter) and rally.phase == WallRally.Phase.RETURNING, "opponent legally picks up its bounced dink")
			rally.tap()
			rally.advance(rally._duration)
			_expect(rally.phase == WallRally.Phase.BOUNCED and rally.returns == 0 and rally.has_queued_shot(), "early tap waits through the near-side bounce")
			_expect(is_equal_approx(rally.player_position(0).z, rally.player_position(1).z) and rally.inside_kitchen(0) and rally.inside_kitchen(1), "both advance together for a short kitchen pickup")
			rally.advance(0.1)
			_expect(rally.returns == 1 and rally.last_contact_pos.y > VolleyRally.BALL_RADIUS, "normal tap returns the dink after its bounce")
			_expect(rally.dink_shot == not ground, "volley taps keep dinking and rally taps resume deep strokes")
			rally.cancel_charge()
			rally.advance(20.0)
			_expect(rally.phase == WallRally.Phase.MISSED, "one dink input never returns a later ball automatically")
	var missed := _model(false, 2, false)
	missed.tap(Vector2.UP * 0.3)
	missed.advance(20.0)
	_expect(missed.phase == WallRally.Phase.MISSED and missed.bounces == 2, "staying at the baseline can miss a short dink after two bounces")
	var volley := _model(false, 2, true)
	volley.tap()
	_to_cpu(volley)
	_until_return(volley)
	volley.player_pos.z = volley.ball_pos.z + WallRally.PADDLE_FORWARD
	_expect(volley.inside_kitchen(volley.active_player) and not volley.can_return(), "unbounced kitchen volleys remain illegal")


func _check_scene() -> void:
	var path := "user://overview_check_%d.cfg" % Time.get_ticks_msec()
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	_expect(scene.rally.ground_mode and scene.rally.player_count == 2 and not scene.rally.kitchen_line, "fresh game starts the former wall drill as a two-player baseline rally")
	_expect(scene.player.visible and scene.volley_partner.visible and scene.partner.visible and scene.opponent_partner.visible, "both near athletes and both opponents are visible")
	_expect(scene.partner._id_label.text == "CPU 1" and scene.opponent_partner._id_label.text == "CPU 2", "opponent identities are clear in the former wall drill")
	var rig: CameraRig = scene.get_node("CameraRig")
	var overview := rig.camera.transform
	_expect(rig.camera.position == CameraRig.OVERVIEW_POSITION and is_equal_approx(rig.camera.fov, 46.0), "all play uses the original wall overview")
	_expect(rig.camera.get_child_count() == 0 and not scene.hud._reticle.visible, "overview has no first-person hand or crosshair")
	var no_wall := true
	for mesh in scene.court.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh is BoxMesh and mesh.mesh.size.y > 4.0:
			no_wall = false
	_expect(no_wall and scene.court._volley_root.visible, "the practice wall is removed and the net is active")
	_expect(scene.hud.line_button.visible and scene.hud.line_button.size.y >= 44.0, "large line switch is available near the bottom of the phone")
	var old_depth: float = scene.rally.player_position(0).z
	_touch(Vector2(216, 745), true)
	await process_frame
	_touch(Vector2(216, 745), false)
	await process_frame
	_expect(scene.rally.kitchen_line and scene.rally.phase == WallRally.Phase.READY and not scene.rally.charging, "line-button touch changes formation without serving or charging")
	_expect(is_equal_approx(scene.rally.player_position(0).z, old_depth), "line-button input does not snap either player")
	scene.rally.advance(0.08)
	scene._sync_visuals(0.08)
	_expect(scene.rally.player_position(0).z < old_depth and is_equal_approx(scene.rally.player_position(0).z, scene.rally.player_position(1).z), "both visibly approach the kitchen after the button tap")
	scene.rally.advance(0.2)
	_touch(Vector2(216, 480), true)
	await process_frame
	scene._press_started_msec = Time.get_ticks_msec() - 50
	_touch(Vector2(216, 480), false)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND, "a normal court tap serves toward the opponents")
	_touch(Vector2(216, 480), true)
	await process_frame
	scene._press_started_msec = Time.get_ticks_msec() - 50
	_touch(Vector2(216, 480), false)
	await process_frame
	scene._sync_visuals(0.0)
	var ball_before: Vector3 = scene.rally.ball_pos
	_touch(Vector2(216, 745), true)
	await process_frame
	_touch(Vector2(216, 745), false)
	await process_frame
	_expect(not scene.rally.kitchen_line and scene.rally.has_queued_shot() and scene.rally.ball_pos == ball_before and scene.rally.returns == 0, "live line-button touch preserves the queued shot and rally state")
	for frame in range(1200):
		if scene.rally.returns == 1 or scene.rally.phase == WallRally.Phase.MISSED:
			break
		scene.rally.advance(1.0 / 60.0)
		scene._sync_visuals(1.0 / 60.0)
		_expect(is_equal_approx(scene.rally.player_position(0).z, scene.rally.player_position(1).z), "both teammates stay aligned during live button-driven movement")
		_expect(rig.camera.transform.is_equal_approx(overview), "formation changes and opponent returns never move the overview")
	_expect(scene.rally.returns == 1 and scene.rally.best == 1, "rally continues and scores after switching lines during flight")
	scene._toggle_pause()
	scene._sync_visuals(0.0)
	_touch(Vector2(140, 64), true)
	await process_frame
	_touch(Vector2(140, 64), false)
	await process_frame
	_expect(scene.volley_mode and not scene.rally.ground_mode and scene.rally.kitchen_line, "volley drill retains its kitchen-line preference")
	_expect(scene.player.visible and scene.volley_partner.visible and scene.opponent_partner.visible and rig.camera.transform.is_equal_approx(overview), "volley uses the same overview and visible four-player court")
	_touch(Vector2(216, 745), true)
	await process_frame
	_touch(Vector2(216, 745), false)
	await process_frame
	_expect(not scene.rally.kitchen_line and scene.rally.phase == WallRally.Phase.READY, "volley also switches both players to the baseline without serving")
	scene.rally.advance(0.3)
	_expect(is_equal_approx(scene.rally.player_position(0).z, VolleyRally.BASELINE_HOME_Z) and is_equal_approx(scene.rally.player_position(1).z, VolleyRally.BASELINE_HOME_Z), "both reach the baseline together in volley practice")
	scene._change_game_mode(false)
	_expect(not scene.rally.kitchen_line and scene.rally.best == 1, "rally line preference and record are restored separately")
	scene._change_court_line(true)
	scene._change_player_count(1)
	_expect(is_instance_valid(scene.partner) and is_instance_valid(scene.opponent_partner) and not is_instance_valid(scene.volley_partner) and scene.rally._player_positions.size() == 3, "one-player practice still keeps two opponents")
	scene._change_game_mode(true)
	_expect(scene.rally.player_count == 2 and not scene.rally.kitchen_line and scene.rally.best == 0, "drill selection keeps independent player counts, line choices and records")
	scene.free()
	var restored = load("res://scenes/main.tscn").instantiate()
	restored.save_path = path
	root.add_child(restored)
	await process_frame
	_expect(restored.volley_mode and restored.rally.player_count == 2 and not restored.rally.kitchen_line and restored._wall_players == 1 and restored._wall_front, "reopening restores profile-specific formation and counts")
	restored.dominant_hand = WallRally.Hand.LEFT
	restored._change_game_mode(true)
	for index in range(4):
		var athlete: Athlete = restored.player if index == 0 else (restored.volley_partner if index == 1 else (restored.partner if index == 2 else restored.opponent_partner))
		_expect(athlete.paddle_contact_position().distance_to(restored.rally.paddle_position(index)) < 0.002, "overview renders the real prepared racket for every left-handed athlete")
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _touch(pos: Vector2, pressed: bool, canceled: bool = false) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_screen_transform() * pos
	touch.pressed = pressed
	touch.canceled = canceled
	Input.parse_input_event(touch)


func _run() -> void:
	_check_rallies()
	_check_line_changes()
	_check_dinks()
	await _check_scene()
	print("check_slice: %d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
