extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)


func _until_return(rally: WallRally) -> void:
	for frame in range(600):
		if rally.can_return() or rally.phase == WallRally.Phase.MISSED:
			return
		rally.advance(1.0 / 120.0)


func _run() -> void:
	var rally := WallRally.new()
	rally.reset()
	_expect(rally.phase == WallRally.Phase.READY, "starts ready")
	rally.tap()
	_expect(rally.phase == WallRally.Phase.OUTBOUND and rally.returns == 0, "tap serves without scoring")
	rally.advance(0.72)
	_expect(rally.wall_hits == 1 and rally.phase == WallRally.Phase.RETURNING, "solid wall rebounds the ball")
	_expect(is_equal_approx(rally.ball_pos.z, 0.2), "rebound begins at wall")
	rally.advance(0.92)
	_expect(rally.bounces == 1 and rally.phase == WallRally.Phase.BOUNCED, "wall return bounces on ground once")
	_expect(not rally.can_return(), "immediate bounce is outside contact window")
	_until_return(rally)
	_expect(rally.can_return(), "bounce rises into the tap window")
	_expect(rally.paddle_position().distance_to(rally.ball_pos) <= WallRally.CONTACT_RADIUS, "prepared racket reaches the rebound near its apex")
	var correct_position := rally.player_pos
	rally.player_pos.x = rally.ball_pos.x
	_expect(not rally.can_return(), "body contact cannot substitute for racket contact")
	rally.player_pos = correct_position
	rally.tap()
	_expect(rally.returns == 1 and rally.best == 1 and rally.phase == WallRally.Phase.OUTBOUND, "one legal tap makes exactly one return")
	_expect(is_zero_approx(rally.swing_buffer), "return consumes buffered tap")
	rally.advance(10.0)
	_expect(rally.phase == WallRally.Phase.MISSED and rally.bounces == 2, "without another tap second bounce ends rally")
	_expect(rally.returns == 1, "returns never happen automatically")
	rally.tap()
	_expect(rally.returns == 0 and rally.best == 1, "retry clears rally but keeps best")
	rally.tap()
	rally.advance(10.0)
	_expect(rally.phase == WallRally.Phase.MISSED and rally.returns == 0, "outbound early tap expires instead of auto-returning")
	rally.tap()
	rally.advance(0.72 + 0.92 + 1.12 * 0.35)
	rally.tap()
	rally.advance(0.18)
	_expect(rally.returns == 1, "short buffer accepts a slightly early tap")
	rally.advance(10.0)
	rally.tap()
	rally.advance(0.72 + 0.92 + 1.12 * 0.85)
	_expect(not rally.can_return(), "late swing falls outside contact window")
	rally.tap()
	rally.advance(0.3)
	_expect(rally.phase == WallRally.Phase.MISSED and rally.returns == 0, "late tap cannot save a second bounce")

	var coarse := WallRally.new()
	var fine := WallRally.new()
	coarse.tap()
	fine.tap()
	coarse.advance(2.1)
	for frame in range(210):
		fine.advance(0.01)
	_expect(coarse.phase == fine.phase and coarse.ball_pos.distance_to(fine.ball_pos) < 0.001, "slow frames preserve wall/bounce segment time")

	rally.reset()
	rally.tap()
	for hit in range(50):
		var lane := rally.ball_pos.x
		rally.advance(0.15)
		_expect(is_equal_approx(rally.ball_pos.x, lane), "unswiped shot stays straight regardless of return count")
		_until_return(rally)
		_expect(is_equal_approx(rally.ball_pos.x, lane), "unswiped wall rebound returns along the same lane")
		_expect(rally.can_return(), "reachable contact window at return %d" % hit)
		_expect(rally.ball_pos.x >= 2.0 and rally.ball_pos.x <= WallRally.WIDTH - 2.0, "rebound stays within lane")
		rally.tap()
	_expect(rally.returns == 50 and rally.best == 50 and rally.wall_hits == 50, "sustained rally counts 50 returns")
	_expect(is_equal_approx(rally.pace(), 0.72), "difficulty has a bounded speed floor")
	_check_apex_destination()
	_check_handed_contact()
	_check_charged_shots()
	_check_power_release_assist()
	_check_descending_contacts()
	_check_swipe_trajectories()
	_check_pair_rally()
	_check_pair_recovery()
	_check_volley_rally()

	# Exercise the real scene and input dispatch, including GUI consumption.
	var scene = load("res://scenes/main.tscn").instantiate()
	var scene_path := "user://solo_check_%d.cfg" % Time.get_ticks_msec()
	scene.save_path = scene_path
	root.add_child(scene)
	await process_frame
	scene._saved_best = 1000000 # Do not alter a developer's saved record in checks.
	_expect(scene.get_node("World").get_child_count() == 3, "world contains court, exactly one player and one ball")
	_expect(scene.rally.phase == WallRally.Phase.READY, "scene waits for tap")
	for control in scene.hud.find_children("*", "Control", true, false):
		if control != scene.hud.mode_button and control != scene.hud.game_button:
			_expect(not control is BaseButton and control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "play HUD passes through all input except the idle mode selector")
	# Header, old pause target, court, former pads and build footer all work alike.
	for position in [Vector2(24, 220), Vector2(280, 104), Vector2(210, 480), Vector2(200, 775), Vector2(350, 775), Vector2(216, 840), Vector2(3, 400)]:
		scene.rally.reset()
		_touch(position, true)
		await process_frame
		_expect(scene.rally.charging and scene.rally.phase == WallRally.Phase.READY, "any screen position starts a gesture without hitting on press")
		scene._press_started_msec = Time.get_ticks_msec() - 50
		_touch(position, false)
		await process_frame
		_expect(not scene.paused and scene.rally.phase == WallRally.Phase.OUTBOUND and is_equal_approx(scene.rally.shot_speed, 1.0), "short tap anywhere serves once at normal speed on release")
	# Synthetic mouse input following that touch must not arm another swing.
	_mouse(Vector2(210, 480))
	await process_frame
	_expect(not scene.rally.charging and is_zero_approx(scene.rally.swing_buffer), "synthetic mouse after touch is ignored")
	scene._toggle_pause()
	var frozen: Vector3 = scene.rally.ball_pos
	await process_frame
	_expect(scene.rally.ball_pos == frozen, "pause freezes ball and timer")
	_touch(Vector2(216, 840), true)
	await process_frame
	_touch(Vector2(216, 840), false)
	await process_frame
	_expect(not scene.paused and not scene.rally.charging and not scene.rally.has_queued_shot(), "tap anywhere resumes without a new swing")

	scene.rally.reset()
	_touch(Vector2(200, 775), true)
	await process_frame
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = root.get_screen_transform() * Vector2(350, 775)
	second.pressed = true
	Input.parse_input_event(second)
	await process_frame
	second.pressed = false
	Input.parse_input_event(second)
	await process_frame
	_expect(scene.rally.charging and scene.rally.phase == WallRally.Phase.READY and scene._press_id == 0, "second finger cannot steal or release the primary gesture")
	scene._press_started_msec = Time.get_ticks_msec() - 50
	_touch(Vector2(200, 775), false)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND and is_equal_approx(scene.rally.shot_speed, 1.0), "primary finger alone decides a normal tap")
	_touch(Vector2(24, 220), true)
	await process_frame
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(scene.paused and not scene.rally.charging, "leaving app cancels gesture and pauses active rally")
	# Simulate a lost touch release while switching apps.
	_touch(Vector2(24, 220), true)
	await process_frame
	_touch(Vector2(24, 220), false)
	await process_frame
	_expect(not scene.paused, "touch ownership resets when switching apps")

	scene.rally.reset()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	_expect(scene.rally.charging and scene.rally.phase == WallRally.Phase.READY, "Space starts the same gesture without firing on press")
	scene._press_started_msec = Time.get_ticks_msec() - 50
	var key_up := key.duplicate() as InputEventKey
	key_up.pressed = false
	Input.parse_input_event(key_up)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND and is_equal_approx(scene.rally.shot_speed, 1.0), "short Space release fires one normal shot")
	await _check_simple_taps(scene)
	await _check_descending_touch(scene)
	await _check_scene_charge_controls(scene)
	await _check_scene_swipes(scene)
	scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path))
	await _check_pair_scene()
	await _check_volley_scene()
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		var handed_scene = load("res://scenes/main.tscn").instantiate()
		var hand_path := "user://hand_check_%d_%d.cfg" % [int(hand), Time.get_ticks_msec()]
		handed_scene.save_path = hand_path
		handed_scene.dominant_hand = hand
		root.add_child(handed_scene)
		await process_frame
		handed_scene._saved_best = 1000000
		_expect(handed_scene.rally.dominant_hand == hand, "scene passes internal handedness to simulation")
		_expect(handed_scene.player.paddle_contact_position().distance_to(handed_scene.rally.ball_pos) < 0.001, "held ball sits on the rendered racket")
		handed_scene._tap()
		_until_return(handed_scene.rally)
		handed_scene._sync_visuals(0.0)
		_expect(handed_scene.player.paddle_contact_position().distance_to(handed_scene.ball._sphere.global_position) <= WallRally.CONTACT_RADIUS, "rendered racket reaches incoming ball for either hand")
		_expect(handed_scene.ball._landing.position.distance_to(Vector3(handed_scene.rally.receive_apex.x, 0.055, handed_scene.rally.receive_apex.z)) < 0.001, "ground marker shows predicted apex strike point")
		var contact: Vector3 = handed_scene.rally.ball_pos
		handed_scene._tap()
		handed_scene._sync_visuals(0.0)
		_expect(handed_scene.player.paddle_contact_position().distance_to(contact) < 0.001, "swing begins at the real rendered contact point")
		_expect(handed_scene.ball._impact.visible and handed_scene.ball._impact.position == contact, "successful return flashes at the actual racket contact for either hand")
		handed_scene.rally.advance(0.1)
		handed_scene._sync_visuals(0.0)
		_expect(handed_scene.ball._impact_ring.scale.x > 1.0, "hit ring expands after contact")
		handed_scene.rally.advance(RallyBall.IMPACT_DURATION)
		handed_scene._sync_visuals(0.0)
		_expect(not handed_scene.ball._impact.visible, "hit effect expires after its brief lifetime")
		handed_scene.rally.reset()
		handed_scene.rally.tap()
		handed_scene.rally.press()
		handed_scene.rally.advance(0.72 + 0.92 + 1.12 * 0.65)
		var assisted_contact: Vector3 = handed_scene.rally.ball_pos
		handed_scene.rally.release()
		handed_scene._sync_visuals(0.0)
		_expect(handed_scene.rally.returns == 1 and handed_scene.player.paddle_contact_position().distance_to(assisted_contact) < 0.001, "either hand extends its rendered racket to the assisted late strike")
		_expect(handed_scene.ball._sphere.position == assisted_contact, "assisted strike does not rewind or teleport the ball")
		handed_scene.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(hand_path))
	print("check_slice: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_volley_rally() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		var volley := VolleyRally.new()
		volley.dominant_hand = hand
		volley.set_player_count(1)
		_expect(volley.phase == WallRally.Phase.READY and volley.ball_pos == volley.paddle_position(0), "volley starts on the player's racket for either hand")
		volley.tap()
		var distance := Vector2(volley._to.x - volley._from.x, volley._to.z - volley._from.z).length()
		_expect(is_equal_approx(distance / volley._duration, WallRally.NORMAL_BALL_SPEED * 0.65) and volley._duration > 0.8 and volley._duration < 1.0, "volley gives roughly 0.9 seconds per initial flight at reduced speed")
		volley.advance(volley._duration)
		_expect(volley.phase == WallRally.Phase.RETURNING and volley.opponent_returns == 1 and volley.ball_pos.distance_to(volley.paddle_position(1)) < 0.001, "CPU volleys automatically from its real racket contact")
		for hit in range(40):
			_until_return(volley)
			_expect(volley.can_return() and volley.bounces == 0 and volley.wall_hits == 0, "player can volley without touching ground or wall")
			var contact := volley.ball_pos
			volley.tap()
			_expect(volley.returns == hit + 1 and volley.last_hitter == 0 and volley.ball_pos == contact and volley.last_contact_pos == contact, "one tap returns once from the actual player contact")
			_expect(volley.shot_aim == Vector2.ZERO and is_equal_approx(volley.shot_speed, 1.0) and is_equal_approx(volley.ball_pos.x, 6.0), "still taps keep the straight lane without hold power")
		_expect(volley.best == 40 and is_equal_approx(volley.pace(), 0.9), "long volley rallies limit acceleration to a gentle 90-percent duration floor")
		volley.advance(10.0)
		_expect(volley.phase == WallRally.Phase.MISSED and volley.returns == 40 and volley.bounces == 0, "missing a volley ends the rally without a ground bounce")
		volley.tap()
		_expect(volley.returns == 0 and volley.best == 40 and volley.phase == WallRally.Phase.OUTBOUND, "tap retries volley while preserving its best")
	_check_volley_strokes()
	for progress in [0.0, 0.1, 0.5, 0.9, 0.99]:
		var assisted := VolleyRally.new()
		assisted.set_player_count(1)
		assisted.tap()
		assisted.advance(assisted._duration)
		var incoming := assisted._duration
		assisted.advance(incoming * progress)
		assisted.press()
		assisted.release(0.04)
		assisted.advance(incoming * (1.0 - progress))
		_expect(assisted.returns == 1 and not assisted.has_queued_shot(), "early and late released taps each make one return at the relaxed tempo")
		assisted.advance(10.0)
		_expect(assisted.phase == WallRally.Phase.MISSED and assisted.returns == 1, "one FPS gesture cannot return the next ball automatically")
	var late := VolleyRally.new()
	late.set_player_count(1)
	late.tap()
	late.advance(late._duration)
	late.advance(late._duration * 0.99)
	late.press()
	late.advance(0.08)
	_expect(late.charging and late.can_return() and late.ball_pos.z <= VolleyRally.INCOMING_END_Z, "late finger-down retains a visible reachable ball during release grace")
	late.release(0.08)
	_expect(late.returns == 1 and late.phase == WallRally.Phase.OUTBOUND and is_equal_approx(late.shot_speed, 1.0), "late release makes one normal volley")
	late.advance(late._duration)
	late.advance(late._duration * 0.99)
	late.press()
	late.advance(0.3)
	late.release()
	_expect(late.phase == WallRally.Phase.MISSED and late.returns == 1 and not late.charging, "release grace expires and a stale gesture cannot restart a missed volley")
	var coarse := VolleyRally.new()
	var fine := VolleyRally.new()
	coarse.set_player_count(1)
	fine.set_player_count(1)
	coarse.tap()
	fine.tap()
	coarse.advance(0.8)
	for step in range(80):
		fine.advance(0.01)
	_expect(coarse.phase == fine.phase and coarse.ball_pos.distance_to(fine.ball_pos) < 0.001, "volley preserves trajectory time on slow frames")


func _check_volley_strokes() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(1, -1).normalized(), Vector2(-1, 1).normalized()]:
			var reference_duration := 0.0
			for held in [0.04, 1.5]:
				var aimed := VolleyRally.new()
				aimed.dominant_hand = hand
				aimed.set_player_count(1)
				aimed.press()
				aimed.advance(held)
				_expect(aimed.phase == WallRally.Phase.READY and aimed.charge_time == 0.0, "holding a volley gesture neither charges nor fires")
				aimed.release(held, direction)
				if held < 1.0:
					reference_duration = aimed._duration
				_expect(is_equal_approx(aimed._duration, reference_duration) and aimed.shot_charge == 0.0 and aimed.shot_speed == 1.0, "short and long gestures produce identical volley speed")
				var start := aimed.ball_pos
				aimed.advance(0.001)
				if direction.y < -VolleyRally.VERTICAL_AIM_THRESHOLD:
					_expect(aimed.ball_pos.y > start.y, "up swipe launches upward immediately from contact")
				elif direction.y > VolleyRally.VERTICAL_AIM_THRESHOLD:
					_expect(aimed.ball_pos.y < start.y, "down swipe launches downward immediately instead of rising toward a lower target")
				var net_progress := (start.z - VolleyRally.NET_Z) / (start.z - aimed._to.z)
				aimed.advance(aimed._duration * net_progress - aimed.phase_time)
				_expect(aimed.ball_pos.y >= VolleyRally.NET_HEIGHT + VolleyRally.NET_CLEARANCE - 0.001, "lift and downward strokes clear the net for either hand")
				aimed.advance(aimed._duration - aimed.phase_time)
				_expect(aimed.phase == WallRally.Phase.RETURNING and aimed.ball_pos.distance_to(aimed.paddle_position(1)) < 0.001, "CPU reaches the actual aimed contact at the relaxed volley speed")
				_expect(is_equal_approx(aimed.ball_pos.x, 6.0 + direction.x * VolleyRally.AIM_LATERAL_REACH), "horizontal swipes retain their selected side")
				var net_time := aimed._duration * (VolleyRally.NET_Z - aimed.ball_pos.z) / (VolleyRally.INCOMING_END_Z - aimed.ball_pos.z)
				aimed.advance(net_time)
				_expect(aimed.ball_pos.y >= VolleyRally.NET_HEIGHT + VolleyRally.NET_CLEARANCE - 0.001, "CPU returns even a low downward stroke over the net")
				aimed.tap()
				aimed.advance(aimed._duration - aimed.phase_time)
				_expect(aimed.returns == 1 and aimed.phase == WallRally.Phase.OUTBOUND and aimed.bounces == 0, "early taps still return lifted and downward shots without a bounce")
				aimed.release(2.0, Vector2.ZERO)
				_expect(aimed.returns == 1 and not aimed.has_queued_shot(), "duplicate releases cannot queue another volley")
	var queued := VolleyRally.new()
	queued.set_player_count(1)
	queued.tap()
	queued.press()
	queued.release(0.04, Vector2.DOWN)
	_expect(queued.has_queued_shot() and queued.returns == 0, "a fast early swipe may wait through the outgoing flight")
	queued.advance(queued._duration)
	_expect(queued.has_queued_shot(), "CPU contact preserves the queued swipe direction")
	queued.advance(queued._duration)
	_expect(queued.returns == 1 and queued.shot_aim == Vector2.DOWN and queued.shot_charge == 0.0 and not queued.has_queued_shot(), "early swipe fires once at contact without hold power")
	var contact := queued.ball_pos
	queued.advance(0.001)
	_expect(queued.ball_pos.y < contact.y, "a buffered downward swipe also starts downward at its actual return contact")
	queued.press()
	queued.release(1.0, Vector2.UP)
	queued.cancel_charge()
	queued.advance(10.0)
	_expect(queued.phase == WallRally.Phase.MISSED and queued.returns == 1 and not queued.has_queued_shot(), "cancellation clears a queued swipe without another hit")


func _check_volley_scene() -> void:
	var path := "user://volley_check_%d.cfg" % Time.get_ticks_msec()
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.rally.best = 7
	scene._change_player_count(2)
	_touch(Vector2(140, 64), true)
	await process_frame
	_touch(Vector2(140, 64), false)
	await process_frame
	_expect(scene.volley_mode and scene.rally is VolleyRally and scene.rally.player_count == 1 and scene.rally.phase == WallRally.Phase.READY, "game selector enters fixed 1v1 volley without serving")
	_expect(is_instance_valid(scene.partner) and scene.court._volley_root.visible and not scene.court._wall_parts[0].visible and not scene.hud.mode_button.visible, "volley displays a net and opponent without wall or pair controls")
	_expect(scene.rally.best == 0 and scene.partner._id_label.text == "CPU" and scene.player._id_label.text == "YOU", "volley has a separate best and clear opponent identity")
	var rig: CameraRig = scene.get_node("CameraRig")
	_expect(not scene.player.visible and scene.partner.visible and rig._first_person.visible, "FPS hides the local full-body athlete and shows a foreground racket")
	_expect(is_equal_approx(rig.camera.position.y, 5.4) and is_equal_approx(rig.camera.fov, CameraRig.FIRST_PERSON_FOV), "volley camera is at eye height with first-person framing")
	_expect(not scene.hud._pad_background.visible and scene.hud._message.anchor_top == 0.0 and scene.hud._reticle.visible, "FPS HUD leaves the approaching ball unobscured")
	for depth in [4.7, 11.5, 18.3, VolleyRally.INCOMING_END_Z]:
		var projected := rig.camera.unproject_position(Vector3(6.0, VolleyRally.VOLLEY_HEIGHT, depth))
		_expect(root.get_visible_rect().has_point(projected), "incoming FPS ball stays on screen from opponent through late contact")
	_touch(Vector2(216, 480), true)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.READY and scene.rally.charging, "volley touch starts a gesture without hitting on finger down")
	scene._update_swipe(&"touch", 0, Vector2(316, 480))
	scene.rally.advance(0.8)
	scene._sync_visuals(0.0)
	_expect(scene.hud._swipe_arrow.visible and scene.hud._message.text == "Release to hit." and scene.hud._progress.value == 0.0, "volley shows swipe preview without a charge meter")
	scene._press_started_msec -= 1000
	_touch(Vector2(316, 480), false)
	await process_frame
	scene._sync_visuals(0.0)
	_expect(scene.rally.shot_aim == Vector2.RIGHT and is_equal_approx(scene.rally.shot_speed, 1.0) and scene.rally.shot_charge == 0.0 and not scene.hud._swipe_arrow.visible, "long volley gesture chooses direction on release without adding power")
	_expect(not scene.hud.game_button.visible and scene.hud._gesture_hint.text.contains("Tap to hit"), "playing volley retains full-screen normal taps alongside optional gestures")
	_expect(rig._view_paddle.position.x < CameraRig.PADDLE_REST.x, "FPS racket swings toward the actual straight-shot contact")
	scene.rally.advance(scene.rally._duration)
	scene._sync_visuals(0.0)
	_expect(scene.partner.paddle_contact_position().distance_to(scene.rally.last_contact_pos) < 0.001 and is_equal_approx(scene.partner._body.rotation.y, PI), "opponent faces the player and swings at the real contact")
	_expect(scene.ball._impact.visible and not scene.ball._landing.visible, "CPU volley has a strike effect without a ground-bounce marker")
	_until_return(scene.rally)
	_touch(Vector2(216, 480), true)
	await process_frame
	scene._sync_visuals(0.0)
	_expect(scene.rally.returns == 0 and scene.rally.charging, "incoming volley waits for release so a tap cannot compete with a hold")
	scene._press_started_msec = Time.get_ticks_msec() - 50
	_touch(Vector2(216, 480), false)
	await process_frame
	_expect(scene.rally.returns == 1 and scene.rally.phase == WallRally.Phase.OUTBOUND and not scene.rally.has_queued_shot() and is_equal_approx(scene.rally.shot_speed, 1.0) and scene.rally.shot_aim == Vector2.ZERO, "one short volley tap returns once at normal speed without directional drift")
	scene._toggle_pause()
	scene._sync_visuals(0.0)
	_touch(Vector2(140, 64), true)
	await process_frame
	_touch(Vector2(140, 64), false)
	await process_frame
	_expect(not scene.volley_mode and not scene.rally is VolleyRally and scene.rally.player_count == 2 and scene.rally.best == 7, "returning to wall restores pair practice and its separate record")
	_expect(not scene.court._volley_root.visible and scene.court._wall_parts[0].visible and is_equal_approx(scene.partner._body.rotation.y, 0.0), "wall court and same-side partner are restored")
	_expect(scene.player.visible and not rig._first_person.visible and not scene.hud._reticle.visible and scene.hud._pad_background.visible and is_equal_approx(rig.camera.fov, 46.0), "switching back restores wall camera, local body and HUD")
	scene._change_game_mode(true)
	_expect(scene.rally.best == 1, "returning to volley restores the volley record")
	scene.dominant_hand = WallRally.Hand.LEFT
	scene._change_game_mode(true)
	_expect(rig._view_paddle.position.x < 0.0 and rig._view_paddle.scale.x < 0.0, "internal left-handed setting mirrors the FPS racket")
	scene.free()
	var restored = load("res://scenes/main.tscn").instantiate()
	restored.save_path = path
	root.add_child(restored)
	await process_frame
	_expect(restored.volley_mode and restored.rally is VolleyRally and restored.rally.best == 1 and restored._wall_players == 2, "reopening restores volley selection and keeps the wall player-count preference")
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_pair_rally() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		var duo := WallRally.new()
		duo.dominant_hand = hand
		duo.set_player_count(2)
		var lane := duo.ball_pos.x
		duo.tap()
		duo.advance(0.3)
		_expect(is_equal_approx(duo.ball_pos.x, lane), "pair serve without swiping stays straight for either hand")
		duo.reset()
		duo.tap(Vector2.RIGHT)
		_expect(duo.active_player == 1 and duo.last_hitter == 0 and duo.returns == 0, "rightward serve selects the right-side player without scoring")
		var predicted := duo.receive_apex
		duo.press()
		duo.advance(0.8)
		_expect(duo.active_player == 1 and duo.charging and duo.receive_apex.is_equal_approx(predicted), "receiver and prediction remain fixed through wall rebound during a hold")
		_until_return(duo)
		var contact := duo.ball_pos
		duo.release(0.75, Vector2.LEFT)
		_expect(duo.returns == 1 and duo.last_hitter == 1 and duo.active_player == 0, "leftward return selects the left-side player")
		_expect(duo.last_contact_pos == contact and duo.ball_pos == contact, "handoff preserves the previous hitter's physical contact")
		for hit in range(40):
			_until_return(duo)
			_expect(duo.can_return(), "automatic receiver reaches aimed balls throughout a fast pair rally")
			var hitter := duo.active_player
			duo.press()
			duo.release(0.75, Vector2.RIGHT if hit % 2 == 0 else Vector2.LEFT)
			_expect(duo.last_hitter == hitter, "return belongs to the receiving player before switching")
		_expect(duo.returns == 41 and is_equal_approx(duo.pace(), 0.72), "pair mode sustains maximum-speed rallies for either hand")
		duo.press()
		duo.set_player_count(1)
		_expect(duo.player_count == 1 and duo.active_player == 0 and not duo.charging and not duo.has_queued_shot(), "mode change clears holds and pending shots and restores solo")
		_expect(duo.returns == 0 and duo.best == 41 and duo.dominant_hand == hand, "mode change preserves best and handedness")
	var straight := WallRally.new()
	straight.set_player_count(2)
	straight.tap()
	_expect(straight.active_player == 0, "straight serve may select the same player again")
	_until_return(straight)
	straight.tap()
	_expect(straight.last_hitter == 0 and straight.active_player == 0, "pair play follows the course rather than compulsory alternation")
	straight.set_player_count(2)
	straight.tap(Vector2.RIGHT)
	straight.advance(0.72 + 0.92 + 1.12 * 0.75)
	straight.tap()
	_expect(straight.returns == 1 and straight.last_hitter == 1 and straight.active_player == 1, "selected partner can return a falling ball and remain the receiver on a straight shot")


func _check_pair_recovery() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		var pair := WallRally.new()
		pair.dominant_hand = hand
		pair.set_player_count(2)
		pair.tap(Vector2.RIGHT)
		for index in range(2):
			_expect(pair.movement_target(index) == pair.home_position(index), "both players recover home while the shot is outbound")
		pair.advance(0.3)
		_expect(pair.wall_hits == 0 and pair.player_position(1).is_equal_approx(pair.home_position(1)), "receiver cannot anticipate and run to the future rebound before wall contact")
		pair.advance(0.43)
		_expect(pair.phase == WallRally.Phase.RETURNING and pair.active_player == 1 and pair.movement_target(1) != pair.home_position(1), "assigned receiver approaches only after the wall rebound")
		_until_return(pair)
		# Reproduce a hitter already standing in the partner's half. Proximity
		# must not let that athlete keep claiming this territory's next ball.
		pair._player_positions[0] = pair.player_position(1)
		pair._paddle_heights[0] = pair.paddle_height
		pair.active_player = 0
		var contact := pair.ball_pos
		var before := pair.player_position(0).distance_to(pair.home_position(0))
		pair.tap()
		_expect(pair.last_hitter == 0 and pair.active_player == 1 and pair.last_contact_pos == contact, "out-of-position hitter yields the partner's territory even when closest")
		pair.press()
		pair.advance(0.2)
		_expect(pair.player_position(0).distance_to(pair.home_position(0)) < before, "hitter actually moves toward their own home after contact")
		_expect(pair.active_player == 1 and pair.charging, "recovery does not reassign a held gesture")
		pair.advance(0.5)
		_expect(pair.phase == WallRally.Phase.OUTBOUND and pair.player_position(0).is_equal_approx(pair.home_position(0)) and pair.player_position(1).is_equal_approx(pair.home_position(1)), "both players return home before the wall instead of camping at the next strike point")
		pair.cancel_charge()
		_until_return(pair)
		pair.tap(Vector2.LEFT)
		_expect(pair.active_player == 0, "partner-side stroke gives the next ball back to that side's owner")
		# Central strokes are shared; ordinary strokes into the same half remain
		# the responsibility of that half's player.
		pair.reset()
		pair.tap(Vector2(0.4, -1.0))
		_expect(absf(pair.receive_apex.x - 6.0) < 0.2 and pair.active_player == 1, "middle return is yielded to the partner")
		_until_return(pair)
		pair.tap()
		_expect(pair.last_hitter == 1 and pair.active_player == 0, "consecutive middle balls are shared without a counter-based flight pattern")
		for hit in range(24):
			_until_return(pair)
			var left_racket := pair.player_position(0).x + pair.hand_side() * WallRally.PADDLE_SIDE
			var right_racket := pair.player_position(1).x + pair.hand_side() * WallRally.PADDLE_SIDE
			_expect(left_racket <= 6.5 and right_racket >= 5.5, "players remain in their own halves with limited middle coverage")
			pair.press()
			pair.release(0.75, Vector2.RIGHT if hit % 2 == 0 else Vector2.LEFT)
		_expect(pair.returns == 25, "territory recovery preserves fast rallies for either striking hand")


func _check_pair_scene() -> void:
	var path := "user://pair_check_%d.cfg" % Time.get_ticks_msec()
	var pair = load("res://scenes/main.tscn").instantiate()
	pair.save_path = path
	root.add_child(pair)
	await process_frame
	pair.set_process(false)
	_touch(Vector2(350, 64), true)
	await process_frame
	_touch(Vector2(350, 64), false)
	await process_frame
	_expect(pair.rally.player_count == 2 and is_instance_valid(pair.partner) and pair.rally.phase == WallRally.Phase.READY and not pair.rally.charging, "idle mode selector adds the partner without serving")
	_expect(pair.player._id_label.text == "P1" and pair.partner._id_label.text == "P2" and pair.player._id_label.visible and pair.partner._id_label.visible, "two-player identities are visible on both athletes")
	_mouse(Vector2(350, 64))
	await process_frame
	_expect(pair.rally.player_count == 2 and pair.rally.phase == WallRally.Phase.READY, "synthetic mouse cannot toggle mode a second time")
	var persisted := ConfigFile.new()
	persisted.load(path)
	_expect(int(persisted.get_value("practice", "players", 0)) == 2, "chosen player count is saved")
	_touch(Vector2(216, 480), true)
	await process_frame
	pair._press_started_msec = Time.get_ticks_msec() - 50
	var serve: Vector3 = pair.rally.ball_pos
	_touch(Vector2(316, 480), false)
	await process_frame
	pair._sync_visuals(0.0)
	_expect(pair.rally.active_player == 1 and not pair.hud.mode_button.visible and pair.hud._mode_status.text.contains("P2 TO HIT"), "rightward touch serve selects and identifies P2 while hiding mode controls")
	_expect(pair.player.paddle_contact_position().distance_to(serve) < 0.001 and not pair.player._selection_ring.visible and pair.partner._selection_ring.visible, "P1 keeps the serve swing while P2 receives the selection ring")
	pair.rally.advance(0.72 + 0.92 + 1.12 * 0.65)
	_touch(Vector2(216, 480), true)
	await process_frame
	pair._press_started_msec -= 750
	var contact: Vector3 = pair.rally.ball_pos
	_touch(Vector2(116, 480), false)
	await process_frame
	pair._sync_visuals(0.0)
	_expect(pair.rally.last_hitter == 1 and pair.rally.active_player == 0 and pair.rally.returns == 1, "held P2 leftward return hands the next ball to P1 exactly once")
	_expect(pair.partner.paddle_contact_position().distance_to(contact) < 0.001 and pair.player._selection_ring.visible and not pair.partner._selection_ring.visible, "P2 swing stays at actual contact after P1 becomes active")
	pair._toggle_pause()
	pair._sync_visuals(0.0)
	_touch(Vector2(350, 64), true)
	await process_frame
	_touch(Vector2(350, 64), false)
	await process_frame
	_expect(pair.rally.player_count == 1 and not is_instance_valid(pair.partner) and pair.rally.phase == WallRally.Phase.READY and not pair.rally.charging, "paused mode selection restores solo without swinging")
	pair._change_player_count(2)
	var record: int = pair.rally.best
	pair.free()
	var restored = load("res://scenes/main.tscn").instantiate()
	restored.save_path = path
	root.add_child(restored)
	await process_frame
	_expect(restored.rally.player_count == 2 and is_instance_valid(restored.partner) and restored.rally.best == record, "reopening restores pair preference and best record")
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_swipe_trajectories() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		for aim in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, 1)]:
			var rally := WallRally.new()
			rally.dominant_hand = hand
			rally.reset()
			var origin := rally.ball_pos
			rally.tap(aim)
			rally.advance(0.72)
			_expect(signf(rally.ball_pos.x - origin.x) == signf(aim.x), "swipe sends the actual ball left/right for either hand")
			_expect(is_equal_approx(rally.ball_pos.y, 3.4) if aim.y == 0.0 else signf(rally.ball_pos.y - 3.4) == -signf(aim.y), "up/down swipe changes wall impact height")
			_expect(rally.ball_pos.x >= 2.0 and rally.ball_pos.x <= 10.0 and rally.ball_pos.y >= 1.999 and rally.ball_pos.y <= 4.801, "aimed shots stay on the wall")
			_expect(signf(rally.target_x - rally.ball_pos.x) in [0.0, signf(aim.x)], "wall rebound preserves lateral shot direction within lane limits")
			_until_return(rally)
			_expect(rally.can_return(), "aimed rebound still reaches the prepared racket for either hand")
			var contact := rally.ball_pos
			rally.tap(-aim)
			_expect(rally.returns == 1 and rally.ball_pos == contact and rally.shot_aim.is_equal_approx((-aim).normalized()), "return changes direction without moving the contact point")
		# Opposite aimed rebounds require the longest footwork at maximum speed.
		var fast := WallRally.new()
		fast.dominant_hand = hand
		fast.reset()
		fast.press()
		fast.release(0.75, Vector2.LEFT)
		for hit in range(40):
			_until_return(fast)
			_expect(fast.can_return(), "either hand reaches alternating aimed rebounds at maximum rally speed")
			fast.press()
			fast.release(0.75, Vector2.RIGHT if hit % 2 == 0 else Vector2.LEFT)
		_expect(fast.returns == 40 and is_equal_approx(fast.pace(), 0.72), "aimed fast rally reaches difficulty cap without unreachable rebounds")

	var normal := WallRally.new()
	normal.tap()
	normal.advance(0.72 + 0.92 + 1.12 * 0.2)
	normal.tap(Vector2.LEFT)
	normal.advance(0.35)
	_expect(normal.returns == 1 and normal.shot_aim == Vector2.LEFT and is_equal_approx(normal.shot_speed, 1.0), "early normal tap preserves swipe direction until contact")
	var power := WallRally.new()
	power.tap()
	power.press()
	power.advance(0.75)
	power.release(0.75, Vector2.RIGHT)
	power.advance(1.6)
	_expect(power.returns == 1 and power.shot_aim == Vector2.RIGHT and is_equal_approx(power.shot_speed, WallRally.MAX_SHOT_SPEED), "early strong release preserves direction and speed together")
	power.advance(10.0)
	power.tap()
	_expect(power.shot_aim == Vector2.ZERO, "retry without swiping returns to straight shots")
	power.press()
	power.release(0.75, Vector2.LEFT)
	power.cancel_charge()
	_expect(power._pending_aim == Vector2.ZERO and not power.has_queued_shot(), "cancellation clears a queued swipe")


func _check_scene_swipes(scene) -> void:
	var start := Vector2(216, 480)
	for held in [0.05, 0.8]:
		for aim in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			scene._cancel_press()
			scene.rally.reset()
			_touch(start, true)
			await process_frame
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = root.get_screen_transform() * (start + aim * 100.0)
			Input.parse_input_event(drag)
			await process_frame
			_expect(scene.hud._swipe_arrow.visible and scene.rally.phase == WallRally.Phase.READY, "swipe previews direction without hitting before release")
			scene._press_started_msec = Time.get_ticks_msec() - int(held * 1000.0)
			_touch(start + aim * 100.0, false)
			await process_frame
			var speed := 1.0 if held < WallRally.MIN_POWER_HOLD else WallRally.MAX_SHOT_SPEED
			_expect(scene.rally.shot_aim.is_equal_approx(aim) and is_equal_approx(scene.rally.shot_speed, speed), "short and held gestures aim independently of shot speed")
			_expect(not scene.hud._swipe_arrow.visible and not scene.rally.has_queued_shot(), "release consumes the arrow and gesture exactly once")
	scene._cancel_press()
	scene.rally.reset()
	_touch(start, true)
	await process_frame
	scene._press_started_msec = Time.get_ticks_msec() - 50
	_touch(start + Vector2(4, 3), false)
	await process_frame
	_expect(scene.rally.shot_aim == Vector2.ZERO, "small finger jitter keeps ordinary tap direction")
	# Only the owning finger may aim, including the final release position.
	scene.rally.reset()
	_touch(start, true)
	await process_frame
	var other := InputEventScreenDrag.new()
	other.index = 1
	other.position = root.get_screen_transform() * (start + Vector2(100, 0))
	Input.parse_input_event(other)
	await process_frame
	_expect(scene._swipe_direction == Vector2.ZERO and not scene.hud._swipe_arrow.visible, "secondary finger cannot change aim")
	scene._press_started_msec = Time.get_ticks_msec() - 50
	_touch(start - Vector2(100, 0), false)
	await process_frame
	_expect(scene.rally.shot_aim == Vector2.LEFT, "release position aims even without an intermediate drag event")
	# Mouse drag uses the same aiming path; keyboard shots stay straight.
	scene.rally.reset()
	scene._touch_until = 0
	var mouse := InputEventMouseButton.new()
	mouse.position = root.get_screen_transform() * start
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await process_frame
	scene._press_started_msec = Time.get_ticks_msec() - 50
	mouse = mouse.duplicate() as InputEventMouseButton
	mouse.position = root.get_screen_transform() * (start + Vector2(100, 0))
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await process_frame
	_expect(scene.rally.shot_aim == Vector2.RIGHT, "desktop drag controls actual shot direction")
	scene.rally.reset()
	_touch(start, true)
	await process_frame
	scene._update_swipe(&"touch", 0, start + Vector2(100, 0))
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(scene._swipe_direction == Vector2.ZERO and not scene.hud._swipe_arrow.visible, "focus loss clears swipe preview and direction")
	_touch(start, false)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.READY, "canceled swipe cannot fire on release")


func _check_charged_shots() -> void:
	var short := WallRally.new()
	short.press()
	short.advance(0.05)
	_expect(short.charging and short.phase == WallRally.Phase.READY, "holding before serve does not launch a ball")
	short.release()
	var long := WallRally.new()
	long.press()
	long.advance(2.0)
	_expect(is_equal_approx(long.charge_fraction(), 1.0), "power caps at full charge without auto-firing")
	long.release()
	_expect(long.shot_speed > short.shot_speed and is_equal_approx(long.shot_speed, WallRally.MAX_SHOT_SPEED), "longer hold produces a faster bounded shot")
	short.advance(0.2)
	long.advance(0.2)
	_expect(long.ball_pos.z < short.ball_pos.z - 1.0, "charged ball actually travels farther in equal outbound time")
	short.advance(0.72 / short.shot_speed - short.phase_time)
	long.advance(0.72 / long.shot_speed - long.phase_time)
	short.advance(0.2)
	long.advance(0.2)
	_expect(long.ball_pos.z > short.ball_pos.z + 1.0, "wall rebound retains the charged speed")
	_expect(long.receive_apex == short.receive_apex, "speed change preserves the predicted strike geometry")

	var rally := WallRally.new()
	rally.tap()
	rally.advance(0.72)
	rally.press()
	rally.advance(0.92 + 0.56)
	_expect(rally.can_return() and rally.returns == 0, "holding through contact never returns automatically")
	rally.release()
	_expect(rally.returns == 1 and is_equal_approx(rally.shot_speed, WallRally.MAX_SHOT_SPEED), "release at contact applies the held power")
	rally.release()
	_expect(rally.returns == 1, "a duplicate release cannot add another return")

	rally.reset()
	rally.tap()
	rally.advance(0.72 + 0.92)
	rally.press()
	rally.advance(0.1)
	var buffered_power := rally.charge_fraction()
	rally.release()
	_expect(rally.returns == 0, "slightly early release buffers a shot")
	rally.advance(0.5)
	_expect(rally.returns == 1 and is_equal_approx(rally.shot_charge, buffered_power), "early-release buffer preserves its selected power")

	rally.reset()
	rally.press()
	rally.advance(0.2)
	rally.press()
	_expect(is_equal_approx(rally.charge_fraction(), 0.2 / WallRally.MAX_CHARGE_TIME), "duplicate press does not reset charging time")
	rally.cancel_charge()
	rally.release()
	_expect(rally.phase == WallRally.Phase.READY and not rally.charging, "canceled charge cannot launch on release")
	rally.tap()
	rally.press()
	rally.advance(10.0)
	_expect(rally.phase == WallRally.Phase.MISSED and not rally.charging, "second bounce cancels a held shot")
	rally.release()
	_expect(rally.phase == WallRally.Phase.MISSED, "releasing a missed hold cannot accidentally restart")
	rally.press()
	rally.release()
	_expect(rally.phase == WallRally.Phase.OUTBOUND, "fresh press and release retries after a miss")

	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		rally = WallRally.new()
		rally.dominant_hand = hand
		rally.tap()
		for hit in range(30):
			_until_return(rally)
			_expect(rally.can_return() and rally.player_pos.distance_to(rally.movement_target()) < 0.001, "either hand reaches the apex for mixed shot speeds")
			var held: float = [0.0, 0.3, 0.75][hit % 3]
			rally.press()
			rally.release(held)
			_expect(is_equal_approx(rally.shot_speed, lerpf(1.0, WallRally.MAX_SHOT_SPEED, held / WallRally.MAX_CHARGE_TIME)), "each released duration sets the next shot speed")
		_expect(rally.returns == 30, "mixed charged shots sustain a rally for either hand")


func _release_fixture(hand: int, speed: float, progress: float) -> WallRally:
	var rally := WallRally.new()
	rally.dominant_hand = hand
	rally.press()
	rally.release(WallRally.MAX_CHARGE_TIME if speed > 1.0 else 0.0)
	rally.press()
	rally.advance((0.72 + 0.92 + 1.12 * progress) / speed)
	return rally


func _check_power_release_assist() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		for speed in [1.0, WallRally.MAX_SHOT_SPEED]:
			for progress in [0.35, 0.65]:
				var rally := _release_fixture(hand, speed, progress)
				_expect(rally.can_power_return(), "POWER accepts release before and after the apex")
				_expect(rally.can_return() == (progress >= 0.5), "normal taps also reach descending balls without changing rising contact")
				var contact := rally.ball_pos
				rally.release()
				_expect(rally.returns == 1 and is_equal_approx(rally.shot_speed, WallRally.MAX_SHOT_SPEED), "early/late release returns immediately with held power for either hand and speed")
				_expect(rally.ball_pos == contact and rally.last_contact_pos == contact, "assistance strikes from the real current ball position")
		var wrong_side := _release_fixture(hand, 1.0, 0.65)
		wrong_side.player_pos.x = wrong_side.ball_pos.x
		_expect(not wrong_side.can_power_return(), "POWER assistance still rejects body-centered contact")

	var early := WallRally.new()
	early.tap()
	early.advance(0.72 + 0.92)
	early.press()
	early.advance(0.02)
	var power := early.charge_fraction()
	early.release()
	_expect(early.returns == 0 and early.has_queued_shot(), "release just after the first bounce queues instead of being lost")
	early.advance(0.5)
	_expect(early.returns == 1 and is_equal_approx(early.shot_charge, power), "longer release buffer preserves early input and shot power")
	var full_early := WallRally.new()
	full_early.tap()
	full_early.press()
	full_early.advance(WallRally.MAX_CHARGE_TIME)
	full_early.release()
	_expect(full_early.has_queued_shot() and full_early.returns == 0, "releasing at full power before the bounce retains the shot")
	full_early.advance(1.6)
	_expect(full_early.returns == 1 and is_equal_approx(full_early.shot_speed, WallRally.MAX_SHOT_SPEED), "early full-power release waits for this ball instead of expiring")

	var canceled := _release_fixture(WallRally.Hand.RIGHT, 1.0, 0.02)
	canceled.release()
	canceled.cancel_charge()
	canceled.advance(1.5)
	_expect(canceled.returns == 0 and not canceled._pending_power, "canceling an assisted queued shot prevents a later hit")
	var late := _release_fixture(WallRally.Hand.RIGHT, 1.0, 0.9)
	_expect(not late.can_power_return(), "a ball beyond racket reach is still a miss")
	late.release()
	_expect(is_zero_approx(late.swing_buffer) and late.last_feedback == "Too late", "a passed ball is reported as late instead of falsely queued")
	late.advance(0.5)
	_expect(late.phase == WallRally.Phase.MISSED and late.returns == 0, "assistance cannot hit after a second bounce")

	var normal := _release_fixture(WallRally.Hand.RIGHT, 1.0, 0.2)
	normal.release()
	normal.tap()
	normal.advance(0.14)
	_expect(normal.returns == 0 and not normal._pending_power, "switching to a normal tap does not inherit POWER reach")
	normal.advance(0.25)
	_expect(normal.returns == 1 and is_equal_approx(normal.shot_speed, 1.0), "normal tap keeps its original speed and contact behavior")


func _check_descending_contacts() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		for speed in [1.0, WallRally.MAX_SHOT_SPEED]:
			for progress in [0.55, 0.65, 0.75, 0.8]:
				for strong in [false, true]:
					var rally := _release_fixture(hand, speed, progress)
					if not strong:
						rally.cancel_charge()
					_expect(rally.can_return() and rally.can_power_return() and rally.can_tap(), "falling ball is available to normal and strong shots for either hand and speed")
					var contact := rally.ball_pos
					if strong:
						rally.release(0.75, Vector2.LEFT)
					else:
						rally.tap(Vector2.LEFT)
					_expect(rally.returns == 1 and rally.phase == WallRally.Phase.OUTBOUND and not rally.has_queued_shot(), "descending input makes exactly one immediate return")
					_expect(rally.ball_pos == contact and rally.last_contact_pos == contact and rally.shot_aim == Vector2.LEFT, "descending strike keeps the current ball position and swipe direction")
					_expect(is_equal_approx(rally.shot_speed, WallRally.MAX_SHOT_SPEED if strong else 1.0), "descending normal taps do not require power")
		for progress in [0.65, 0.8]:
			var wrong_side := _release_fixture(hand, 1.0, progress)
			wrong_side.player_pos.x = wrong_side.ball_pos.x
			_expect(not wrong_side.can_return() and not wrong_side.can_power_return(), "descending reach still rejects body-centered contact")
		for strong in [false, true]:
			var late := _release_fixture(hand, 1.0, 0.9)
			if strong:
				late.release()
			else:
				late.cancel_charge()
				late.tap()
			_expect(late.returns == 0 and not late.has_queued_shot(), "ball beyond arm reach cannot be returned")
			late.advance(0.5)
			_expect(late.phase == WallRally.Phase.MISSED and late.returns == 0, "descending assistance still ends at the second bounce")


func _check_descending_touch(scene) -> void:
	# A real short gesture begins after the apex and lifts 120 ms later.
	# The release remains a normal shot, even with swipe input while falling.
	scene.set_process(false)
	for progress in [0.6, 0.7]:
		scene.paused = false
		scene._cancel_press()
		scene.rally.reset()
		scene.rally.tap()
		scene.rally.advance(0.72 + 0.92 + 1.12 * progress)
		scene._sync_visuals(0.0)
		_expect(scene.hud._message.text == "Your moment.", "HUD keeps offering normal taps after the apex")
		_touch(Vector2(216, 480), true)
		await process_frame
		scene.rally.advance(0.1)
		_expect(scene.rally.returns == 0 and scene.rally.charging, "descending finger-down does not fire before tap/hold classification")
		scene._press_started_msec = Time.get_ticks_msec() - 120
		var contact: Vector3 = scene.rally.ball_pos
		_touch(Vector2(116, 480), false)
		await process_frame
		scene._sync_visuals(0.0)
		_expect(scene.rally.returns == 1 and is_equal_approx(scene.rally.shot_speed, 1.0) and scene.rally.shot_aim == Vector2.LEFT, "short descending touch returns normally and preserves swipe aim")
		_expect(scene.player.paddle_contact_position().distance_to(contact) < 0.001 and scene.ball._impact.visible, "rendered racket and impact extend to the falling ball")
		_touch(Vector2(116, 480), false)
		await process_frame
		_expect(scene.rally.returns == 1 and not scene.rally.has_queued_shot(), "descending tap release cannot add another return")
	scene._cancel_press()
	scene.rally.reset()
	scene.set_process(true)


func _check_simple_taps(scene) -> void:
	scene.paused = false
	scene._cancel_press()
	scene.rally.reset()
	scene.rally.tap()
	scene.rally.advance(0.72 + 0.92 + 1.12 * 0.2)
	_touch(Vector2(24, 40), true)
	await process_frame
	_expect(scene.rally.charging and scene.rally.returns == 0, "short tap does not hit on down or compete with a potential hold")
	scene._press_started_msec = Time.get_ticks_msec() - 50
	_touch(Vector2(24, 40), false)
	await process_frame
	_expect(scene.rally.swing_buffer > 0.0 and not scene.rally.charging, "short release keeps normal early-tap assistance")
	scene.rally.advance(0.35)
	_expect(scene.rally.returns == 1 and is_equal_approx(scene.rally.shot_speed, 1.0), "ordinary early tap returns once at normal speed")
	_touch(Vector2(24, 40), false)
	await process_frame
	_expect(scene.rally.returns == 1 and not scene.rally.has_queued_shot(), "duplicate release cannot add a second shot")

	# Begin holding far outside contact, pass through the normal tap window,
	# and release later within assisted racket reach: only the release strikes.
	scene._cancel_press()
	scene.rally.reset()
	scene.rally.tap()
	_touch(Vector2(216, 840), true)
	await process_frame
	_expect(not scene.rally.can_power_return() and scene.rally.charging, "hold may begin before the ball is in range")
	scene.rally.advance(0.72 + 0.92 + 1.12 * 0.65 - scene.rally.phase_time)
	_expect(scene.rally.returns == 0 and scene.rally.can_power_return(), "holding through contact never fires a normal shot")
	scene._press_started_msec -= 750
	_touch(Vector2(24, 40), false)
	await process_frame
	_expect(scene.rally.returns == 1 and is_equal_approx(scene.rally.shot_speed, WallRally.MAX_SHOT_SPEED), "hold release alone judges contact and makes one strong return")
	_touch(Vector2(24, 40), false)
	await process_frame
	_expect(scene.rally.returns == 1 and not scene.rally.has_queued_shot(), "strong release cannot also queue a normal shot")
	scene._cancel_press()
	scene.rally.reset()


func _check_scene_charge_controls(scene) -> void:
	scene._cancel_press()
	scene.rally.reset()
	_touch(Vector2(350, 775), true)
	await process_frame
	scene.rally.advance(0.4)
	scene._sync_visuals(0.0)
	_expect(scene.rally.charging and scene.hud._progress.value > 0.5, "holding anywhere shows power on the HUD meter")
	_touch(Vector2(210, 480), false, true)
	await process_frame
	_expect(not scene.rally.charging and scene.rally.phase == WallRally.Phase.READY, "canceled touch clears a held shot without firing")
	_touch(Vector2(350, 775), true)
	await process_frame
	scene._press_started_msec -= 750
	_touch(Vector2(210, 480), false)
	await process_frame
	_expect(is_equal_approx(scene.rally.shot_speed, WallRally.MAX_SHOT_SPEED), "touch release reads wall-clock hold duration")
	scene._sync_visuals(0.0)
	_expect(scene.ball._impact.visible, "successful serve has a visible impact effect")
	var frozen_age: float = scene.rally.contact_age
	scene._toggle_pause()
	await process_frame
	_expect(scene.rally.contact_age == frozen_age and scene.ball._impact.visible, "pause freezes the hit effect with the simulation")
	_touch(Vector2(210, 480), true)
	await process_frame
	_touch(Vector2(210, 480), false)
	await process_frame
	_expect(not scene.paused and not scene.rally.charging, "resume gesture does not begin or release a shot")
	_touch(Vector2(350, 775), true)
	await process_frame
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(scene.paused and not scene.rally.charging and scene._press_source == &"", "app switch cancels charge and input ownership")
	_touch(Vector2(200, 775), false)
	await process_frame
	_expect(scene.rally.returns == 0, "release after focus loss cannot hit the ball")
	scene.paused = false
	scene._cancel_press()
	scene.rally.reset()
	scene._touch_until = 0
	var down := InputEventMouseButton.new()
	down.position = root.get_screen_transform() * Vector2(350, 775)
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	_expect(scene.rally.charging and scene.rally.phase == WallRally.Phase.READY, "desktop mouse down charges without hitting")
	scene._press_started_msec -= 400
	var up := down.duplicate() as InputEventMouseButton
	up.position = root.get_screen_transform() * Vector2(100, 300)
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND and scene.rally.shot_charge >= 0.5, "desktop mouse up outside the original area releases the charged shot")
	scene._cancel_press()
	scene.rally.reset()
	var power_key := InputEventKey.new()
	power_key.physical_keycode = KEY_SPACE
	power_key.pressed = true
	Input.parse_input_event(power_key)
	await process_frame
	_expect(scene.rally.charging and scene.rally.phase == WallRally.Phase.READY, "holding Space charges without a separate key or modifier")
	scene._press_started_msec -= 750
	var release_key := power_key.duplicate() as InputEventKey
	release_key.pressed = false
	Input.parse_input_event(release_key)
	await process_frame
	_expect(is_equal_approx(scene.rally.shot_speed, WallRally.MAX_SHOT_SPEED), "keyboard hold releases a fast shot")


func _check_apex_destination() -> void:
	var peak := WallRally.trajectory_apex(Vector3(7.0, 0.0, WallRally.BOUNCE_Z), Vector3(7.0, 0.0, WallRally.LENGTH), WallRally.BOUNCE_APEX)
	_expect(peak.distance_to(Vector3(7.0, 2.65, 18.3)) < 0.001, "predicts highest point of the first bounce")
	peak = WallRally.trajectory_apex(Vector3(2.0, 1.0, 10.0), Vector3(10.0, 3.0, 20.0), 2.0)
	_expect(peak.distance_to(Vector3(7.0, 4.125, 16.25)) < 0.001, "apex prediction handles unequal endpoint heights")
	_expect(WallRally.trajectory_apex(Vector3.ZERO, Vector3(1.0, 3.0, 4.0), 0.0) == Vector3(1.0, 3.0, 4.0), "linear ascending path peaks at its end")
	_expect(WallRally.trajectory_apex(Vector3(1.0, 3.0, 4.0), Vector3.ZERO, 0.0) == Vector3(1.0, 3.0, 4.0), "linear descending path peaks at its start")
	_expect(WallRally.trajectory_apex(Vector3.ZERO, Vector3(1.0, 10.0, 4.0), 0.1) == Vector3(1.0, 10.0, 4.0), "apex time stays inside the actual trajectory")
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		var rally := WallRally.new()
		rally.dominant_hand = hand
		rally.tap()
		rally.advance(0.72)
		var prediction := rally.receive_apex
		var destination := rally.movement_target()
		_expect(rally.phase == WallRally.Phase.RETURNING, "apex destination is known before the ground bounce")
		_expect(destination.distance_to(Vector3(prediction.x - rally.hand_side() * WallRally.PADDLE_SIDE, 0.0, prediction.z + WallRally.PADDLE_FORWARD)) < 0.001, "destination leaves the apex at the dominant-hand racket")
		rally.advance(0.4)
		_expect(rally.player_pos.distance_to(destination) < 0.001, "player arrives at the destination before the bounce")
		rally.advance(0.52)
		for progress in [0.1, 0.3, 0.5, 0.8]:
			rally.advance(maxf(0.0, 1.12 * progress - rally.phase_time))
			_expect(rally.movement_target() == destination and rally.receive_apex == prediction, "destination stays fixed as the ball rises and falls")
			_expect(rally.player_pos.distance_to(destination) < 0.001, "player waits at the apex destination instead of chasing the ball")
			_expect(rally.paddle_position().distance_to(prediction) < 0.001, "racket stays prepared at predicted peak height")
			if progress == 0.5:
				_expect(rally.ball_pos.distance_to(prediction) < 0.001 and rally.can_return(), "actual ball reaches the predicted racket position at its peak")
		rally.reset()
		rally.tap()
		rally.advance(0.72 + 0.92 + 0.56)
		var prepared_stance := rally.player_pos
		rally.tap()
		rally.advance(0.3)
		_expect(rally.movement_target() == prepared_stance and rally.player_pos == prepared_stance, "return keeps the prepared stance until a new rebound is known")
		rally.reset()
		_expect(rally.movement_target().distance_to(rally.player_pos) < 0.001, "retry clears the previous movement destination")


func _check_handed_contact() -> void:
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		var rally := WallRally.new()
		rally.dominant_hand = hand
		rally.reset()
		_expect(rally.ball_pos == rally.paddle_position(), "serve starts on the dominant-hand racket")
		var side := rally.hand_side()
		_expect(side * (rally.ball_pos.x - rally.player_pos.x) > 1.0, "racket is beside the body on the dominant side")
		rally.tap()
		# Sample the approach, peak and departure through the prepared racket.
		for hit in range(50):
			var progress: float = [0.47, 0.5, 0.53][hit % 3]
			for frame in range(600):
				if rally.phase == WallRally.Phase.BOUNCED and rally.bounce_progress() >= progress:
					break
				rally.advance(1.0 / 120.0)
			_expect(rally.can_return(), "either hand reaches the prepared apex contact throughout a rally")
			_expect(rally.paddle_position().distance_to(rally.ball_pos) <= WallRally.CONTACT_RADIUS, "ball passes within racket reach near its peak")
			_expect(rally.player_pos.distance_to(rally.movement_target()) < 0.001, "player stays at the fixed apex destination during sustained rallies")
			_expect(is_equal_approx(side * (rally.ball_pos.x - rally.player_pos.x), WallRally.PADDLE_SIDE), "rebound stays on the striking-hand side")
			_expect(rally.player_pos.x > 0.0 and rally.player_pos.x < WallRally.WIDTH, "forehand footwork stays inside the court")
			var contact := rally.ball_pos
			rally.tap()
			_expect(rally.ball_pos == contact and rally.last_contact_pos == contact, "return preserves ball position instead of teleporting it to racket")
		_expect(rally.returns == 50, "both handedness settings sustain 50 physical racket contacts")
		rally.reset()
		_expect(rally.dominant_hand == hand, "retry preserves handedness")


func _touch(pos: Vector2, pressed: bool, canceled: bool = false) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_screen_transform() * pos
	touch.pressed = pressed
	touch.canceled = canceled
	Input.parse_input_event(touch)


func _mouse(pos: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.position = root.get_screen_transform() * pos
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
