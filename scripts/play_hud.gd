class_name PlayHud
extends CanvasLayer

signal player_count_requested(count: int)
signal volley_mode_requested(enabled: bool)

const CREAM := Color("eff0d7")
const MUTED := Color("acbdac")
const LIME := Color("d5ed9c")

var build_label: Label
var _score: Label
var _best: Label
var _message: Label
var _hint: Label
var _gesture_hint: Label
var _progress: ProgressBar
var _pause_dim: ColorRect
var _pad_background: ColorRect
var _dink_background: Panel
var _reticle: Node2D
var _root: Control
var _font: Font
var _power_fill: StyleBoxFlat
var _swipe_arrow: Line2D
var mode_button: Button
var game_button: Button
var _title: Label
var _score_caption: Label
var _mode_status: Label
var _displayed_count := 1
var _displayed_volley := false
var _last_touch_msec := -1000
var _preview_dink := false


func _ready() -> void:
	_font = load("res://fonts/Inter-Regular.ttf")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_pad_background = ColorRect.new()
	_pad_background.color = Color("173e36")
	_pad_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pad_background)
	_pad_background.anchor_right = 1.0
	_bottom(_pad_background, 252, 252)
	_dink_background = Panel.new()
	_dink_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dink_background.add_theme_stylebox_override("panel", _box(Color(0.07, 0.2, 0.16, 0.94), 8))
	_root.add_child(_dink_background)
	_pin(_dink_background, Vector2(24, 208), Vector2(384, 86))
	_dink_background.visible = false
	_label("P R A C T I C E   /   0 1", Vector2(24, 36), Vector2(280, 20), 12, MUTED)
	_title = _label("Wall rally", Vector2(24, 59), Vector2(270, 40), 30, CREAM)
	_mode_status = _label("1 PLAYER", Vector2(292, 36), Vector2(116, 60), 14, LIME)
	_mode_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_button = Button.new()
	mode_button.focus_mode = Control.FOCUS_NONE
	mode_button.add_theme_font_override("font", _font)
	mode_button.add_theme_font_size_override("font_size", 16)
	mode_button.add_theme_color_override("font_color", CREAM)
	for state in ["normal", "hover", "focus"]:
		mode_button.add_theme_stylebox_override(state, _box(Color("2b5144"), 12))
	mode_button.add_theme_stylebox_override("pressed", _box(Color("3b6555"), 12))
	_root.add_child(mode_button)
	_pin(mode_button, Vector2(292, 28), Vector2(116, 72))
	mode_button.gui_input.connect(_mode_input)
	game_button = Button.new()
	game_button.focus_mode = Control.FOCUS_NONE
	game_button.add_theme_font_override("font", _font)
	game_button.add_theme_font_size_override("font_size", 17)
	game_button.add_theme_color_override("font_color", CREAM)
	for state in ["normal", "hover", "focus"]:
		game_button.add_theme_stylebox_override(state, _box(Color("2b5144"), 12))
	game_button.add_theme_stylebox_override("pressed", _box(Color("3b6555"), 12))
	_root.add_child(game_button)
	_pin(game_button, Vector2(24, 28), Vector2(244, 72))
	game_button.gui_input.connect(_game_input)
	_score_caption = _label("RALLY", Vector2(24, 116), Vector2(130, 20), 12, MUTED)
	_score = _label("00", Vector2(20, 130), Vector2(220, 78), 64, CREAM)
	_label("PERSONAL BEST", Vector2(267, 123), Vector2(142, 20), 11, MUTED)
	_best = _label("00", Vector2(266, 146), Vector2(140, 50), 34, CREAM)
	# Every HUD element passes input through to the full-screen gesture handler.
	_message = _label("Find your rhythm.", Vector2(24, 0), Vector2(384, 32), 22, CREAM)
	_bottom(_message, 225, 32)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _label("Tap anywhere to serve.", Vector2(24, 0), Vector2(384, 28), 13, MUTED)
	_bottom(_hint, 187, 28)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.add_theme_stylebox_override("background", _box(Color("305346"), 3))
	_power_fill = _box(LIME, 3)
	_progress.add_theme_stylebox_override("fill", _power_fill)
	_root.add_child(_progress)
	_progress.offset_left = 40
	_progress.offset_right = 392
	_bottom(_progress, 151, 5)
	_gesture_hint = _label("Swipe to aim  /  Hold for power", Vector2(24, 0), Vector2(384, 28), 13, MUTED)
	_gesture_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gesture_hint.add_theme_color_override("font_shadow_color", Color("173e36"))
	_gesture_hint.add_theme_constant_override("shadow_offset_x", 1)
	_gesture_hint.add_theme_constant_override("shadow_offset_y", 1)
	_bottom(_gesture_hint, 100, 28)
	build_label = _label(_build_identifier(), Vector2(24, 0), Vector2(384, 22), 16, CREAM)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.add_theme_stylebox_override("normal", _box(Color(0.07, 0.2, 0.16, 0.92), 5))
	_bottom(build_label, 32, 22)
	_pause_dim = ColorRect.new()
	_pause_dim.color = Color(0.06, 0.16, 0.13, 0.94)
	_pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_pause_dim)
	_root.move_child(_pause_dim, 0)
	_pause_dim.visible = false
	_swipe_arrow = Line2D.new()
	_swipe_arrow.width = 3.0
	_swipe_arrow.default_color = LIME
	_swipe_arrow.antialiased = true
	_swipe_arrow.visible = false
	_root.add_child(_swipe_arrow)
	_reticle = Node2D.new()
	_root.add_child(_reticle)
	for points in [PackedVector2Array([Vector2(-5, 0), Vector2(5, 0)]), PackedVector2Array([Vector2(0, -5), Vector2(0, 5)])]:
		var stroke := Line2D.new()
		stroke.points = points
		stroke.width = 1.5
		_reticle.add_child(stroke)
	_reticle.visible = false


func show_swipe(start: Vector2, end: Vector2) -> void:
	var direction := (end - start).normalized()
	_preview_dink = _displayed_volley and (end - start).length() < VolleyRally.SWIPE_FULL_LENGTH * VolleyRally.DINK_AIM_LIMIT
	_swipe_arrow.default_color = Color("9ee9e4") if _preview_dink else LIME
	_swipe_arrow.points = PackedVector2Array([start, end, end - direction.rotated(-0.55) * 16.0, end, end - direction.rotated(0.55) * 16.0])
	_swipe_arrow.visible = true


func clear_swipe() -> void:
	_preview_dink = false
	if is_instance_valid(_swipe_arrow):
		_swipe_arrow.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_msec = Time.get_ticks_msec()


func _mode_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			player_count_requested.emit(3 - _displayed_count)
		mode_button.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Time.get_ticks_msec() - _last_touch_msec > 600:
			player_count_requested.emit(3 - _displayed_count)
		mode_button.accept_event()


func _game_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			volley_mode_requested.emit(not _displayed_volley)
		game_button.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Time.get_ticks_msec() - _last_touch_msec > 600:
			volley_mode_requested.emit(not _displayed_volley)
		game_button.accept_event()


func _build_identifier() -> String:
	if FileAccess.file_exists("res://build_info.json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if info is Dictionary:
			var identifier = info.get("display_id", "DEV")
			if identifier is String and not identifier.is_empty():
				return "BUILD " + identifier
	return "BUILD DEV"


func sync_state(rally: WallRally, paused: bool) -> void:
	if not rally.charging:
		clear_swipe()
	_score.text = "%02d" % rally.returns
	_best.text = "%02d" % rally.best
	_displayed_volley = rally is VolleyRally
	var volley := rally as VolleyRally
	_dink_background.visible = volley != null and volley.dink_shot
	_pad_background.visible = not _displayed_volley
	_reticle.visible = _displayed_volley
	_reticle.position = _root.size * 0.5
	_reticle.modulate = LIME if rally.can_return() else Color(1.0, 1.0, 1.0, 0.55)
	_title.text = ("Doubles volley" if rally.player_count == 2 else "Volley rally") if _displayed_volley else "Wall rally"
	_score_caption.text = "VOLLEYS" if _displayed_volley else "RALLY"
	_gesture_hint.text = "Short swipe: dink  /  Long swipe: drive" if _displayed_volley else "Swipe to aim  /  Hold for power"
	_displayed_count = rally.player_count
	var may_change := (rally.phase == WallRally.Phase.READY or rally.phase == WallRally.Phase.MISSED or paused) and not rally.charging
	mode_button.visible = may_change
	game_button.visible = may_change
	game_button.text = "VOLLEY RALLY\nSWITCH TO WALL" if _displayed_volley else "WALL RALLY\nSWITCH TO VOLLEY"
	mode_button.text = "%d PLAYER%s\nSWITCH" % [rally.player_count, "S" if rally.player_count == 2 else ""]
	if _displayed_volley:
		mode_button.text = ("DOUBLES" if rally.player_count == 2 else "SINGLES") + "\nSWITCH"
	_mode_status.visible = not mode_button.visible
	_mode_status.text = "%d PLAYER%s" % [rally.player_count, "S" if rally.player_count == 2 else ""]
	if rally.player_count == 2:
		_mode_status.text += "\nP%d TO HIT" % (rally.active_player + 1)
	if _displayed_volley:
		_mode_status.text = "2 vs 2\nP%d TO HIT" % (rally.active_player + 1) if rally.player_count == 2 else "1 vs 1\nYOU vs CPU"
	_mode_status.add_theme_color_override("font_color", Color("9ee4ff") if rally.active_player == 1 else LIME)
	_pause_dim.visible = paused
	var held := rally.charging and rally.charge_time >= WallRally.MIN_POWER_HOLD
	_progress.value = rally.charge_fraction() if held else rally.bounce_progress()
	_power_fill.bg_color = Color("ffb06d") if held else LIME
	if _displayed_volley:
		_top(_message, 218, 32)
		_top(_hint, 256, 28)
		_top(_progress, 292, 5)
		_sync_volley(rally, paused)
		return
	_bottom(_message, 225, 32)
	_bottom(_hint, 187, 28)
	_bottom(_progress, 151, 5)
	var ready := rally.can_tap()
	if paused:
		_message.text = "Take a breath."
		_hint.text = "Tap anywhere to resume."
	elif held:
		_message.text = "Power %d%%" % int(round(rally.charge_fraction() * 100.0))
		_hint.text = "Longer hold, faster shot." if rally.phase == WallRally.Phase.READY or rally.phase == WallRally.Phase.MISSED else "Release when the ball is near your racket."
	elif rally.phase == WallRally.Phase.READY:
		_message.text = "Find your rhythm."
		_hint.text = "Tap anywhere to serve."
	elif rally.phase == WallRally.Phase.MISSED:
		_message.text = "A new best!" if rally.returns > rally.starting_best else "One more rally?"
		_hint.text = "Tap anywhere to retry. You made %d return%s." % [rally.returns, "" if rally.returns == 1 else "s"]
	elif rally.has_queued_shot():
		_message.text = "Waiting for the ball."
		_hint.text = "Your shot will hit when the ball arrives."
	elif rally.phase == WallRally.Phase.BOUNCED and rally.last_feedback == "Too late":
		_message.text = "The ball has passed."
		_hint.text = "Try releasing a little earlier."
	elif ready:
		_message.text = "Your moment."
		_hint.text = "Tap now, even as the ball falls." if rally.bounce_progress() >= 0.5 else "Tap anywhere now. No hold needed."
	elif rally.phase == WallRally.Phase.OUTBOUND:
		_message.text = rally.last_feedback
		_hint.text = "Tap anywhere. Hold for optional power."
	else:
		_message.text = "Let it bounce." if rally.phase == WallRally.Phase.RETURNING else "Get ready."
		_hint.text = "Tap anywhere after the bounce."


func _sync_volley(rally: WallRally, paused: bool) -> void:
	var volley := rally as VolleyRally
	if paused:
		_message.text = "Take a breath."
		_hint.text = "Tap anywhere to resume."
	elif rally.charging:
		_message.text = "Dink ready." if _preview_dink else "Release to hit."
		_hint.text = "Short swipe: dink. Long swipe: drive."
	elif rally.phase == WallRally.Phase.READY:
		_message.text = "Ready to volley?"
		_hint.text = "Tap to rally. Short swipe to dink."
	elif rally.phase == WallRally.Phase.MISSED:
		_message.text = "Second bounce." if volley.dink_shot else "The ball passed."
		_hint.text = "Tap anywhere to try again."
	elif rally.has_queued_shot():
		_message.text = "Ready for the ball."
		_hint.text = "Your shot will hit after the bounce." if volley.dink_shot else "Your shot will hit when it arrives."
	elif rally.phase == WallRally.Phase.OUTBOUND:
		_message.text = rally.last_feedback
		_hint.text = "Your opponent returns automatically."
	elif volley.dink_shot and rally.phase == WallRally.Phase.RETURNING:
		_message.text = "Let it bounce."
		_hint.text = "Tap early. Hit after the bounce."
	elif rally.phase == WallRally.Phase.BOUNCED:
		_message.text = "Tap to dink!"
		_hint.text = "Tap to return, or swipe for direction."
	elif rally.can_tap():
		_message.text = "Tap to volley!"
		_hint.text = "Tap or swipe. No hold needed."
	else:
		_message.text = "Here it comes."
		_hint.text = "Tap as the ball approaches."


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_root.add_child(label)
	_pin(label, pos, size)
	return label


func _pin(control: Control, pos: Vector2, dimensions: Vector2) -> void:
	control.position = pos
	control.size = dimensions


func _bottom(control: Control, from_bottom: float, height: float) -> void:
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_top = -from_bottom
	control.offset_bottom = -from_bottom + height


func _top(control: Control, from_top: float, height: float) -> void:
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_top = from_top
	control.offset_bottom = from_top + height


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
