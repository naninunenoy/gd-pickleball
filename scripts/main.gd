extends Node3D

const SAVE_PATH := "user://wall_practice.cfg"

var rally := WallRally.new()
var paused := false
var auto_rally := false
var _touch_until := 0
var _active_touch := -1
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
	rally.reset()
	hud.tap_pressed.connect(_tap)
	hud.pause_pressed.connect(_toggle_pause)
	_sync_visuals(0.0)


func _process(delta: float) -> void:
	if not paused:
		if auto_rally:
			if rally.phase == WallRally.Phase.READY or rally.can_return():
				_tap()
			elif rally.phase == WallRally.Phase.MISSED:
				_miss_time += delta
				if _miss_time > 0.8:
					_tap()
		rally.advance(delta)
		if rally.returns > _last_returns:
			player.swing()
			if auto_rally:
				print("wall_return: %d best=%d" % [rally.returns, rally.best])
		if rally.wall_hits > _last_wall_hits:
			court.flash_wall()
		if rally.phase == WallRally.Phase.MISSED:
			_save_best()
	_last_returns = rally.returns
	_last_wall_hits = rally.wall_hits
	_sync_visuals(0.0 if paused else delta)


func _sync_visuals(delta: float) -> void:
	player.sync_practice(rally.player_x, delta)
	ball.sync_practice(rally, delta)
	court.animate(delta)
	hud.sync_state(rally, paused)


func _tap() -> void:
	if paused:
		paused = false
		return
	var starting := rally.phase == WallRally.Phase.READY or rally.phase == WallRally.Phase.MISSED
	rally.tap()
	if starting:
		_last_returns = 0
		_last_wall_hits = 0
		_miss_time = 0.0
		player.swing()


func _toggle_pause() -> void:
	paused = not paused
	if paused:
		rally.swing_buffer = 0.0
		_save_best()


func _input(event: InputEvent) -> void:
	# Note touch before GUI dispatch: synthetic mouse events must never double-hit.
	if event is InputEventScreenTouch:
		_touch_until = Time.get_ticks_msec() + 600
		if event.pressed:
			if event.canceled or _active_touch != -1:
				get_viewport().set_input_as_handled()
			else:
				_active_touch = event.index
		elif event.index == _active_touch:
			_active_touch = -1
	elif event is InputEventScreenDrag:
		_touch_until = Time.get_ticks_msec() + 600


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_tap()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() > _touch_until:
			_tap()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_ENTER:
				_tap()
			KEY_P, KEY_ESCAPE:
				_toggle_pause()
			KEY_R:
				_save_best()
				rally.reset()
				paused = false
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_active_touch = -1
		if is_instance_valid(hud):
			hud.reset_touch()
		if rally.phase != WallRally.Phase.READY and rally.phase != WallRally.Phase.MISSED:
			paused = true
			rally.swing_buffer = 0.0
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
