extends Node3D

const SAVE_PATH := "user://wall_practice.cfg"
const SWIPE_DEADZONE := 14.0 # Reference viewport pixels, independent of phone size.

@export var dominant_hand: WallRally.Hand = WallRally.Hand.RIGHT
@export var save_path := SAVE_PATH

var rally: WallRally = WallRally.new()
var volley_mode := false
var _wall_players := 1
var paused := false
var auto_rally := false
var _touch_until := 0
var _active_touch := -1
var _press_source: StringName = &""
var _press_id := -1
var _press_started_msec := 0
var _press_origin := Vector2.ZERO
var _swipe_direction := Vector2.ZERO
var _last_returns := 0
var _last_wall_hits := 0
var _saved_best := 0
var _miss_time := 0.0
var partner: Athlete

@onready var player: Athlete = $World/Player
@onready var ball: RallyBall = $World/Ball
@onready var court: Court3D = $World/Court
@onready var hud: PlayHud = $HUD


func _ready() -> void:
	auto_rally = "--auto-rally" in OS.get_cmdline_user_args()
	var config := ConfigFile.new()
	config.load(save_path)
	volley_mode = str(config.get_value("practice", "game", "wall")) == "volley"
	_wall_players = clampi(int(config.get_value("practice", "players", 1)), 1, 2)
	rally = VolleyRally.new() if volley_mode else WallRally.new()
	rally.best = maxi(0, int(config.get_value("volley" if volley_mode else "practice", "best", 0)))
	_saved_best = rally.best
	rally.dominant_hand = dominant_hand
	rally.set_player_count(1 if volley_mode else _wall_players)
	_update_players()
	hud.player_count_requested.connect(_change_player_count)
	hud.volley_mode_requested.connect(_change_game_mode)
	_sync_court_mode()
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
	player.sync_practice(rally, delta, 0)
	if is_instance_valid(partner):
		partner.sync_practice(rally, delta, 1)
	ball.sync_practice(rally, delta)
	$CameraRig.sync_volley(rally)
	court.animate(delta)
	hud.sync_state(rally, paused)


func _update_players() -> void:
	if (rally.player_count == 2 or volley_mode) and not is_instance_valid(partner):
		partner = Athlete.new()
		partner.name = "Partner"
		partner.outfit_color = Color("89bbd5")
		partner.selection_color = Color("9ee4ff")
		$World.add_child(partner)
	elif rally.player_count == 1 and not volley_mode and is_instance_valid(partner):
		partner.queue_free()
		partner = null


func _change_player_count(count: int) -> void:
	if volley_mode:
		return
	_cancel_press()
	_save_best()
	rally.set_player_count(count)
	_wall_players = rally.player_count
	_update_players()
	_reset_round_tracking()
	paused = false
	_save_configuration()
	_sync_visuals(0.0)


func _sync_court_mode() -> void:
	court.set_volley_mode(volley_mode)
	$CameraRig.set_volley_mode(volley_mode)
	player.visible = not volley_mode


func _change_game_mode(enabled: bool) -> void:
	_cancel_press()
	_save_best()
	if not volley_mode:
		_wall_players = rally.player_count
	volley_mode = enabled
	var config := ConfigFile.new()
	config.load(save_path)
	rally = VolleyRally.new() if enabled else WallRally.new()
	rally.dominant_hand = dominant_hand
	rally.best = maxi(0, int(config.get_value("volley" if enabled else "practice", "best", 0)))
	rally.set_player_count(1 if enabled else _wall_players)
	_saved_best = rally.best
	_update_players()
	_sync_court_mode()
	_reset_round_tracking()
	paused = false
	_save_configuration()
	_sync_visuals(0.0)


func _begin_press(source: StringName, id: int, position: Vector2 = Vector2.ZERO) -> void:
	if paused:
		paused = false
		_cancel_press()
		return
	if _press_source != &"":
		return
	_press_source = source
	_press_id = id
	_press_started_msec = Time.get_ticks_msec()
	_press_origin = position
	_swipe_direction = Vector2.ZERO
	hud.clear_swipe()
	if volley_mode:
		_tap()
		return
	# One gesture owns both actions. Never hit on down: it may become a hold.
	rally.press()


func _update_swipe(source: StringName, id: int, position: Vector2) -> void:
	if source != _press_source or id != _press_id or not rally.charging:
		return
	var movement := position - _press_origin
	_swipe_direction = movement.normalized() if movement.length() >= SWIPE_DEADZONE else Vector2.ZERO
	if _swipe_direction != Vector2.ZERO:
		hud.show_swipe(_press_origin, position)
	else:
		hud.clear_swipe()


func _finish_press(source: StringName, id: int) -> void:
	if source != _press_source or id != _press_id:
		return
	var held := maxf(0.0, float(Time.get_ticks_msec() - _press_started_msec) / 1000.0)
	var aim := _swipe_direction
	_press_source = &""
	_press_id = -1
	_swipe_direction = Vector2.ZERO
	hud.clear_swipe()
	if volley_mode:
		return
	var starting := rally.phase == WallRally.Phase.READY or rally.phase == WallRally.Phase.MISSED
	if held < WallRally.MIN_POWER_HOLD:
		# A canceled/missed hold must not turn into a tap that restarts play.
		var valid := rally.charging
		rally.cancel_charge()
		if valid:
			rally.tap(aim)
	else:
		rally.release(held, aim)
	if starting and rally.phase == WallRally.Phase.OUTBOUND:
		_reset_round_tracking()


func _cancel_press() -> void:
	_press_source = &""
	_press_id = -1
	_press_started_msec = 0
	_press_origin = Vector2.ZERO
	_swipe_direction = Vector2.ZERO
	if is_instance_valid(hud):
		hud.clear_swipe()
	rally.cancel_charge()


func _reset_round_tracking() -> void:
	_last_returns = 0
	_last_wall_hits = 0
	_miss_time = 0.0


func _tap() -> void:
	# Diagnostic auto-rally uses the model's normal tap action.
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
	# The whole viewport accepts a gesture; release follows its original owner.
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
				_update_swipe(&"touch", event.index, event.position)
				_finish_press(&"touch", event.index)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_until = Time.get_ticks_msec() + 600
		_update_swipe(&"touch", event.index, event.position)
	elif event is InputEventMouseMotion:
		_update_swipe(&"mouse", 0, event.position)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _press_source == &"mouse":
			_update_swipe(&"mouse", 0, event.position)
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
			_begin_press(&"touch", event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() > _touch_until:
			_begin_press(&"mouse", 0, event.position)
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
		if rally.phase != WallRally.Phase.READY and rally.phase != WallRally.Phase.MISSED:
			paused = true
		_save_best()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_best()


func _save_best() -> void:
	if rally.best <= _saved_best:
		return
	_save_configuration()


func _save_configuration() -> void:
	var config := ConfigFile.new()
	config.load(save_path)
	var section := "volley" if volley_mode else "practice"
	config.set_value(section, "best", maxi(rally.best, int(config.get_value(section, "best", 0))))
	config.set_value("practice", "players", _wall_players)
	config.set_value("practice", "game", "volley" if volley_mode else "wall")
	if config.save(save_path) == OK:
		_saved_best = rally.best


func _exit_tree() -> void:
	_save_best()
	if auto_rally:
		print("auto_rally end: returns=%d best=%d wall_hits=%d phase=%d" % [rally.returns, rally.best, rally.wall_hits, rally.phase])
