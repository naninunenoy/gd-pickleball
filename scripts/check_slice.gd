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
		_until_return(rally)
		_expect(rally.can_return(), "reachable contact window at return %d" % hit)
		_expect(rally.ball_pos.x >= 2.0 and rally.ball_pos.x <= WallRally.WIDTH - 2.0, "rebound stays within lane")
		rally.tap()
	_expect(rally.returns == 50 and rally.best == 50 and rally.wall_hits == 50, "sustained rally counts 50 returns")
	_expect(is_equal_approx(rally.pace(), 0.72), "difficulty has a bounded speed floor")
	_check_apex_destination()
	_check_handed_contact()
	_check_charged_shots()

	# Exercise the real scene and input dispatch, including GUI consumption.
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._saved_best = 1000000 # Do not alter a developer's saved record in checks.
	_expect(scene.get_node("World").get_child_count() == 3, "world contains court, exactly one player and one ball")
	_expect(scene.rally.phase == WallRally.Phase.READY, "scene waits for tap")
	var small_screen_scale := minf(320.0 / 432.0, 568.0 / 864.0)
	_expect(scene.hud.tap_button.size.y * small_screen_scale >= 44.0, "main pad remains a 44px touch target on small phones")
	_expect(scene.hud.pause_button.size.y * small_screen_scale >= 44.0, "pause remains a 44px touch target on small phones")
	_expect(scene.hud.power_button.size.y * small_screen_scale >= 44.0, "optional POWER remains a 44px touch target on small phones")
	_expect(scene.hud.tap_button.get_global_rect().end.x < scene.hud.power_button.get_global_rect().position.x, "normal tap and optional POWER have separate non-overlapping targets")
	_touch(Vector2(210, 480), true)
	await process_frame
	_expect(not scene.rally.charging and scene.rally.phase == WallRally.Phase.OUTBOUND, "ordinary touch serves immediately on press")
	_touch(Vector2(210, 480), false)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND and is_equal_approx(scene.rally.shot_speed, 1.0), "ordinary touch release does not change the shot")
	# Synthetic mouse input following that touch must not arm another swing.
	_mouse(Vector2(210, 480))
	await process_frame
	_expect(is_zero_approx(scene.rally.swing_buffer), "synthetic mouse after touch is ignored")
	scene.rally.reset()
	_touch(Vector2(350, 775), true)
	await process_frame
	_expect(scene.rally.charging, "optional POWER button begins charging through GUI touch")
	scene._press_started_msec -= 600
	_touch(Vector2(210, 480), false)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND and scene.rally.shot_charge >= 0.8, "release outside the pad uses actual elapsed hold time")
	_until_return(scene.rally)
	_touch(Vector2(200, 775), true)
	await process_frame
	_touch(Vector2(200, 775), false)
	await process_frame
	_expect(scene.rally.returns == 1 and is_equal_approx(scene.rally.shot_speed, 1.0), "ordinary pad returns at normal speed after an optional POWER shot")
	_touch(Vector2(368, 70), true)
	await process_frame
	_touch(Vector2(368, 70), false)
	await process_frame
	_expect(scene.paused, "pause button consumes touch without swinging")
	var frozen: Vector3 = scene.rally.ball_pos
	await process_frame
	_expect(scene.rally.ball_pos == frozen, "pause freezes ball and timer")
	_touch(Vector2(210, 480), true)
	await process_frame
	_touch(Vector2(210, 480), false)
	await process_frame
	_expect(not scene.paused and is_zero_approx(scene.rally.swing_buffer), "court tap resumes without a new swing")
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(scene.paused, "leaving app pauses active rally")
	scene.paused = false
	scene.rally.reset()
	_touch(Vector2(200, 775), true)
	await process_frame
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = root.get_screen_transform() * Vector2(350, 775)
	second.pressed = true
	Input.parse_input_event(second)
	await process_frame
	_expect(not scene.rally.charging and scene.rally.phase == WallRally.Phase.OUTBOUND and is_equal_approx(scene.rally.shot_speed, 1.0), "second finger cannot turn a normal shot into a held shot")
	second.pressed = false
	Input.parse_input_event(second)
	_touch(Vector2(200, 775), false)
	await process_frame
	_touch(Vector2(200, 775), true)
	await process_frame
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	# Simulate a lost touch release while switching apps.
	_touch(Vector2(200, 775), true)
	await process_frame
	_touch(Vector2(200, 775), false)
	await process_frame
	_expect(not scene.paused, "touch ownership resets when switching apps")
	scene.rally.reset()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	_expect(not scene.rally.charging and scene.rally.phase == WallRally.Phase.OUTBOUND, "Space press hits immediately on desktop")
	var key_up := key.duplicate() as InputEventKey
	key_up.pressed = false
	Input.parse_input_event(key_up)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND, "Space release cannot add another shot")
	await _check_simple_taps(scene)
	await _check_scene_charge_controls(scene)
	scene.free()
	for hand in [WallRally.Hand.RIGHT, WallRally.Hand.LEFT]:
		var handed_scene = load("res://scenes/main.tscn").instantiate()
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
		handed_scene.free()
	print("check_slice: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


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
	rally.advance(0.72 + 0.92 + 1.12 * 0.25)
	rally.press()
	rally.advance(0.1)
	var buffered_power := rally.charge_fraction()
	rally.release()
	_expect(rally.returns == 0, "slightly early release buffers a shot")
	rally.advance(0.18)
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


func _check_simple_taps(scene) -> void:
	scene.paused = false
	scene._cancel_press()
	scene.rally.reset()
	scene._sync_visuals(0.0)
	_expect(scene.hud.tap_button.text == "TAP TO SERVE", "main button teaches ordinary taps by default")
	_touch(Vector2(200, 775), true)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND and not scene.rally.charging, "normal pad serves on finger down without holding or releasing")
	scene.rally.advance(0.8)
	_expect(is_equal_approx(scene.rally.shot_speed, 1.0) and not scene.rally.charging, "holding the normal pad never creates a charged shot")
	_touch(Vector2(210, 480), false)
	await process_frame
	_expect(scene.rally.returns == 0 and is_zero_approx(scene.rally.swing_buffer), "normal release cannot arm a second shot")

	scene._cancel_press()
	scene.rally.reset()
	scene.rally.tap()
	scene.rally.advance(0.72 + 0.92 + 1.12 * 0.2)
	scene._sync_visuals(0.0)
	_expect(scene.rally.can_tap() and not scene.rally.can_return(), "normal input cue allows an easier early tap after the bounce")
	_expect(scene.hud.tap_button.text == "TAP TO RETURN", "main button offers normal return before exact contact")
	_touch(Vector2(200, 775), true)
	await process_frame
	_expect(scene.rally.swing_buffer > 0.0 and not scene.rally.charging, "slightly early normal press queues a shot without charging")
	_touch(Vector2(200, 775), false)
	await process_frame
	scene.rally.advance(0.35)
	_expect(scene.rally.returns == 1 and is_equal_approx(scene.rally.shot_speed, 1.0), "ordinary early tap returns at normal speed when ball reaches racket")
	scene._cancel_press()
	scene.rally.reset()
	scene._sync_visuals(0.0)


func _check_scene_charge_controls(scene) -> void:
	scene._cancel_press()
	scene.rally.reset()
	_touch(Vector2(350, 775), true)
	await process_frame
	scene.rally.advance(0.4)
	scene._sync_visuals(0.0)
	_expect(scene.rally.charging and scene.hud._progress.value > 0.5, "held power is visible on the HUD meter")
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
	scene.hud._last_touch_msec = -1000
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
	power_key.shift_pressed = true
	power_key.pressed = true
	Input.parse_input_event(power_key)
	await process_frame
	_expect(scene.rally.charging and scene.rally.phase == WallRally.Phase.READY, "Shift Space explicitly opts into a charged shot")
	scene._press_started_msec -= 750
	var release_key := power_key.duplicate() as InputEventKey
	release_key.pressed = false
	Input.parse_input_event(release_key)
	await process_frame
	_expect(is_equal_approx(scene.rally.shot_speed, WallRally.MAX_SHOT_SPEED), "optional keyboard hold releases a fast shot")


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
