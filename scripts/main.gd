extends Node3D

const SAVE_PATH := "user://wall_practice.cfg"

@export var dominant_hand: WallRally.Hand = WallRally.Hand.RIGHT

var rally := WallRally.new()
var paused := false
var auto_rally := false
var _touch_until := 0
var _active_touch := -1
var _press_source: StringName = &""
var _press_id := -1
var _press_started_msec := 0
var _last_returns := 0
var _last_wall_hits := 0
var _saved_best := 0
var _miss_time := 0.0

@onready var player: Athlete = $World/Player
@onready var ball: RallyBall = $World/Ball
@onready var court: Court3D = $World/Court
@onready var hud: PlayHud = $HUD


func _ready() -> void:
	auto_rally = "--auto-rally" in OS.get_cmdline_user_args()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		rally.best = maxi(0, int(config.get_value("practice", "best", 0)))
	_saved_best = rally.best
	rally.dominant_hand = dominant_hand
	rally.reset()
	hud.press_started.connect(_begin_press)
	hud.pause_pressed.connect(_toggle_pause)
	_sync_visuals(0.0)


func _process(delta: float) -> void:
	if not paused:
		if auto_rally and not rally.charging:
			if rally.phase == WallRally.Phase.READY or rally.can_return():
				_tap()
			elif rally.phase == WallRally.Phase.MISSED:
				_miss_time += delta
				if _miss_time > 0.8:
					_tap()
		rally.advance(delta)
		if auto_rally and rally.returns > _last_returns:
			print("wall_return: %d best=%d" % [rally.returns, rally.best])
		if rally.wall_hits > _last_wall_hits:
			court.flash_wall()
		if rally.phase == WallRally.Phase.MISSED:
			_save_best()
	_last_returns = rally.returns
	_last_wall_hits = rally.wall_hits
	_sync_visuals(0.0 if paused else delta)


func _sync_visuals(delta: float) -> void:
	player.sync_practice(rally, delta)
	ball.sync_practice(rally, delta)
	court.animate(delta)
	hud.sync_state(rally, paused)


func _begin_press(source: StringName, id: int) -> void:
	if paused:
		paused = false
		_cancel_press()
		return
	if _press_source != &"":
		return
	_press_source = source
	_press_id = id
	_press_started_msec = Time.get_ticks_msec()
	rally.press()


func _finish_press(source: StringName, id: int) -> void:
	if source != _press_source or id != _press_id:
		return
	var held := maxf(0.0, float(Time.get_ticks_msec() - _press_started_msec) / 1000.0)
	_press_source = &""
	_press_id = -1
	var starting := rally.phase == WallRally.Phase.READY or rally.phase == WallRally.Phase.MISSED
	rally.release(held)
	if starting and rally.phase == WallRally.Phase.OUTBOUND:
		_reset_round_tracking()


func _cancel_press() -> void:
	_press_source = &""
	_press_id = -1
	_press_started_msec = 0
	rally.cancel_charge()


func _reset_round_tracking() -> void:
	_last_returns = 0
	_last_wall_hits = 0
	_miss_time = 0.0


func _tap() -> void:
	# Instant short shot for the diagnostic auto-rally, not a user press event.
	var starting := rally.phase == WallRally.Phase.READY or rally.phase == WallRally.Phase.MISSED
	rally.tap()
	if starting and rally.phase == WallRally.Phase.OUTBOUND:
		_reset_round_tracking()


func _toggle_pause() -> void:
	_cancel_press()
	paused = not paused
	if paused:
		_save_best()


func _input(event: InputEvent) -> void:
	# A release belongs to its original press even after dragging off the pad.
	if event is InputEventScreenTouch:
		_touch_until = Time.get_ticks_msec() + 600
		if event.canceled:
			if _press_source == &"touch" and event.index == _press_id:
				_cancel_press()
			if event.index == _active_touch:
				_active_touch = -1
			get_viewport().set_input_as_handled()
		elif event.pressed:
			if _active_touch != -1:
				get_viewport().set_input_as_handled()
			else:
				_active_touch = event.index
		elif event.index == _active_touch:
			_active_touch = -1
			if _press_source == &"touch" and event.index == _press_id:
				_finish_press(&"touch", event.index)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_until = Time.get_ticks_msec() + 600
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _press_source == &"mouse":
			_finish_press(&"mouse", 0)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and not event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if _press_source == &"key" and int(key) == _press_id:
			_finish_press(&"key", int(key))
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_begin_press(&"touch", event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() > _touch_until:
			_begin_press(&"mouse", 0)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_SPACE, KEY_ENTER:
				_begin_press(&"key", int(key))
			KEY_P, KEY_ESCAPE:
				_toggle_pause()
			KEY_R:
				_cancel_press()
				_save_best()
				rally.reset()
				paused = false
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_press()
		_active_touch = -1
		if is_instance_valid(hud):
			hud.reset_touch()
		if rally.phase != WallRally.Phase.READY and rally.phase != WallRally.Phase.MISSED:
			paused = true
		_save_best()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_best()


func _save_best() -> void:
	if rally.best <= _saved_best:
		return
	var config := ConfigFile.new()
	config.set_value("practice", "best", rally.best)
	if config.save(SAVE_PATH) == OK:
		_saved_best = rally.best


func _exit_tree() -> void:
	_save_best()
	if auto_rally:
		print("auto_rally end: returns=%d best=%d wall_hits=%d phase=%d" % [rally.returns, rally.best, rally.wall_hits, rally.phase])
