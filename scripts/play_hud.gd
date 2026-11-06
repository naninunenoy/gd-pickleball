class_name PlayHud
extends CanvasLayer

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
var _root: Control
var _font: Font
var _power_fill: StyleBoxFlat
var _swipe_arrow: Line2D


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
	_label("RALLY", Vector2(24, 116), Vector2(130, 20), 12, MUTED)
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
	_bottom(_gesture_hint, 100, 28)
	build_label = _label(_build_identifier(), Vector2(24, 0), Vector2(384, 22), 16, CREAM)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


func show_swipe(start: Vector2, end: Vector2) -> void:
	var direction := (end - start).normalized()
	_swipe_arrow.points = PackedVector2Array([start, end, end - direction.rotated(-0.55) * 16.0, end, end - direction.rotated(0.55) * 16.0])
	_swipe_arrow.visible = true


func clear_swipe() -> void:
	if is_instance_valid(_swipe_arrow):
		_swipe_arrow.visible = false


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
	_pause_dim.visible = paused
	var held := rally.charging and rally.charge_time >= WallRally.MIN_POWER_HOLD
	_progress.value = rally.charge_fraction() if held else rally.bounce_progress()
	_power_fill.bg_color = Color("ffb06d") if held else LIME
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


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
