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
	_expect(absf(rally.player_x - rally.target_x) < 0.1, "single player automatically reaches rebound lane")
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
	rally.advance(0.72 + 0.92 + 0.10)
	rally.tap()
	rally.advance(0.12)
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
	_touch(Vector2(210, 480), true)
	await process_frame
	_touch(Vector2(210, 480), false)
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND, "touch on court serves")
	# Synthetic mouse input following that touch must not arm another swing.
	_mouse(Vector2(210, 480))
	await process_frame
	_expect(is_zero_approx(scene.rally.swing_buffer), "synthetic mouse after touch is ignored")
	scene.rally.reset()
	_touch(Vector2(200, 775), true)
	await process_frame
	_touch(Vector2(200, 775), false)
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND, "large bottom pad serves through GUI touch")
	_until_return(scene.rally)
	_touch(Vector2(200, 775), true)
	await process_frame
	_touch(Vector2(200, 775), false)
	_expect(scene.rally.returns == 1, "bottom pad returns a playable ball")
	_touch(Vector2(368, 70), true)
	await process_frame
	_touch(Vector2(368, 70), false)
	_expect(scene.paused, "pause button consumes touch without swinging")
	var frozen: Vector3 = scene.rally.ball_pos
	await process_frame
	_expect(scene.rally.ball_pos == frozen, "pause freezes ball and timer")
	_touch(Vector2(210, 480), true)
	await process_frame
	_touch(Vector2(210, 480), false)
	_expect(not scene.paused and is_zero_approx(scene.rally.swing_buffer), "court tap resumes without a new swing")
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(scene.paused, "leaving app pauses active rally")
	scene.paused = false
	scene.rally.reset()
	_touch(Vector2(200, 775), true)
	await process_frame
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = root.get_screen_transform() * Vector2(210, 480)
	second.pressed = true
	Input.parse_input_event(second)
	await process_frame
	_expect(is_zero_approx(scene.rally.swing_buffer), "second finger cannot add a duplicate swing")
	second.pressed = false
	Input.parse_input_event(second)
	_touch(Vector2(200, 775), false)
	_touch(Vector2(200, 775), true)
	await process_frame
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	# Simulate a lost touch release while switching apps.
	_touch(Vector2(200, 775), true)
	await process_frame
	_touch(Vector2(200, 775), false)
	_expect(not scene.paused, "touch ownership resets when switching apps")
	scene.rally.reset()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	_expect(scene.rally.phase == WallRally.Phase.OUTBOUND, "Space fallback serves on desktop")
	scene.free()
	print("check_slice: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _touch(pos: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_screen_transform() * pos
	touch.pressed = pressed
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
