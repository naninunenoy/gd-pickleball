class_name PlayHud
extends CanvasLayer

signal tap_pressed
signal pause_pressed

const CREAM := Color("eff0d7")
const MUTED := Color("acbdac")
const INK := Color("193d33")
const LIME := Color("d5ed9c")

var tap_button: Button
var pause_button: Button
var _score: Label
var _best: Label
var _message: Label
var _hint: Label
var _progress: ProgressBar
var _pause_dim: ColorRect
var _root: Control
var _font: Font
var _last_touch_msec := -1000
var _touch_index := -1
var _pad_color := Color.TRANSPARENT


func _ready() -> void:
	_font = load("res://fonts/Inter-Regular.ttf")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var pad_background := ColorRect.new()
	pad_background.color = Color("173e36")
	pad_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pad_background)
	pad_background.anchor_right = 1.0
	_bottom(pad_background, 252, 252)
	_label("P R A C T I C E   /   0 1", Vector2(24, 36), Vector2(280, 20), 12, MUTED)
	_label("Wall rally", Vector2(24, 59), Vector2(270, 40), 30, CREAM)
	pause_button = _button("Pause", Color("2b5144"), CREAM)
	_pin(pause_button, Vector2(318, 36), Vector2(90, 68))
	_connect_button(pause_button, true)
	_label("RALLY", Vector2(24, 116), Vector2(130, 20), 12, MUTED)
	_score = _label("00", Vector2(20, 130), Vector2(220, 78), 64, CREAM)
	_label("PERSONAL BEST", Vector2(267, 123), Vector2(142, 20), 11, MUTED)
	_best = _label("00", Vector2(266, 146), Vector2(140, 50), 34, CREAM)
	# The pad is anchored above the phone's bottom safe area.
	_message = _label("Find your rhythm.", Vector2(24, 0), Vector2(384, 32), 22, CREAM)
	_bottom(_message, 225, 32)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _label("One bounce. One tap. Keep it going.", Vector2(24, 0), Vector2(384, 28), 13, MUTED)
	_bottom(_hint, 187, 28)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.add_theme_stylebox_override("background", _box(Color("305346"), 3))
	_progress.add_theme_stylebox_override("fill", _box(LIME, 3))
	_root.add_child(_progress)
	_progress.offset_left = 40
	_progress.offset_right = 392
	_bottom(_progress, 151, 5)
	tap_button = _button("TAP TO SERVE", LIME, INK)
	_pin(tap_button, Vector2(24, 0), Vector2(384, 90))
	_bottom(tap_button, 130, 90)
	_connect_button(tap_button, false)
	var foot := _label("SOLO PICKLEBALL  /  WALL SESSION", Vector2(24, 0), Vector2(384, 16), 10, MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom(foot, 26, 16)
	_pause_dim = ColorRect.new()
	_pause_dim.color = Color(0.06, 0.16, 0.13, 0.94)
	_pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_pause_dim)
	_root.move_child(_pause_dim, 0)
	_pause_dim.visible = false


func sync_state(rally: WallRally, paused: bool) -> void:
	_score.text = "%02d" % rally.returns
	_best.text = "%02d" % rally.best
	pause_button.text = "Resume" if paused else "Pause"
	pause_button.add_theme_font_size_override("font_size", 16 if paused else 18)
	_pause_dim.visible = paused
	_progress.value = rally.bounce_progress()
	var ready := rally.can_return()
	var color := LIME if ready or paused or rally.phase == WallRally.Phase.READY or rally.phase == WallRally.Phase.MISSED else Color("b8c9a1")
	if paused:
		_message.text = "Take a breath."
		_hint.text = "Your rally is waiting for you."
		tap_button.text = "TAP TO RESUME"
	elif rally.phase == WallRally.Phase.READY:
		_message.text = "Find your rhythm."
		_hint.text = "One bounce. One tap. Keep it going."
		tap_button.text = "TAP TO SERVE"
	elif rally.phase == WallRally.Phase.MISSED:
		_message.text = "A new best!" if rally.returns > rally.starting_best else "One more rally?"
		_hint.text = "Second bounce. You made %d return%s." % [rally.returns, "" if rally.returns == 1 else "s"]
		tap_button.text = "TAP TO TRY AGAIN"
	elif ready:
		_message.text = "Your moment."
		_hint.text = "Tap anywhere to return the ball."
		tap_button.text = "TAP NOW"
	elif rally.phase == WallRally.Phase.OUTBOUND:
		_message.text = rally.last_feedback
		_hint.text = "Watch the rebound."
		tap_button.text = "TO THE WALL"
	else:
		_message.text = "Let it bounce." if rally.phase == WallRally.Phase.RETURNING else "Get ready."
		_hint.text = "Your player moves automatically."
		tap_button.text = "WAIT FOR THE BOUNCE" if rally.phase == WallRally.Phase.RETURNING else "GET READY"
	# Keep the same button throughout the rally: no small targets or mode switches.
	if color != _pad_color:
		_pad_color = color
		for state in ["normal", "hover", "focus"]:
			tap_button.add_theme_stylebox_override(state, _box(color, 24))


func _connect_button(button: Button, is_pause: bool) -> void:
	# Handle touch directly; GUI mouse synthesis cannot create a second action.
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_last_touch_msec = Time.get_ticks_msec()
			if event.pressed and not event.canceled and _touch_index == -1:
				_touch_index = event.index
				_emit(is_pause)
			elif not event.pressed and event.index == _touch_index:
				_touch_index = -1
			button.accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Time.get_ticks_msec() - _last_touch_msec > 600:
				_emit(is_pause)
			button.accept_event()
	)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_last_touch_msec = Time.get_ticks_msec()
		if not event.pressed and event.index == _touch_index:
			_touch_index = -1


func _emit(is_pause: bool) -> void:
	if is_pause:
		pause_pressed.emit()
	else:
		tap_pressed.emit()


func reset_touch() -> void:
	_touch_index = -1


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


func _button(text: String, color: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 22 if text != "Pause" else 18)
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, _box(color, 24))
	button.add_theme_stylebox_override("pressed", _box(color.lightened(0.1), 24))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text_color)
	_root.add_child(button)
	return button


func _pin(control: Control, pos: Vector2, dimensions: Vector2) -> void:
	control.position = pos
	control.size = dimensions


func _bottom(control: Control, from_bottom: float, height: float) -> void:
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_top = -from_bottom
	control.offset_bottom = -from_bottom + height


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
