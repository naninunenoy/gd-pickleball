class_name PlayHud
extends CanvasLayer

signal shot_pressed(shot_id: int)
signal pause_pressed

var soft_btn: Button
var hard_btn: Button
var pause_btn: Button

var _root: Control
var _font: Font
var _compact := false
var _short := false
var _lock_until_msec := 0


func _ready() -> void:
	layer = 25
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	soft_btn = _make_button("Soft", Color(0.16, 0.42, 0.30, 0.92))
	hard_btn = _make_button("Hard", Color(0.46, 0.24, 0.16, 0.92))
	pause_btn = _make_button("Pause", Color(0.14, 0.16, 0.16, 0.9))
	soft_btn.pressed.connect(func() -> void: _emit_shot(ShotCatalog.Id.SOFT))
	hard_btn.pressed.connect(func() -> void: _emit_shot(ShotCatalog.Id.HARD))
	pause_btn.pressed.connect(_emit_pause)
	_root.add_child(soft_btn)
	_root.add_child(hard_btn)
	_root.add_child(pause_btn)


func apply_font(font: Font) -> void:
	_font = font
	for btn in [soft_btn, hard_btn, pause_btn]:
		if btn == null or font == null:
			continue
		btn.add_theme_font_override("font", font)


func set_paused(paused: bool) -> void:
	if pause_btn == null:
		return
	pause_btn.text = "Resume" if paused else "Pause"


func set_armed(shot: int) -> void:
	if soft_btn == null:
		return
	_tint(soft_btn, Color(0.16, 0.42, 0.30, 0.92), shot == ShotCatalog.Id.SOFT)
	_tint(hard_btn, Color(0.46, 0.24, 0.16, 0.92), shot == ShotCatalog.Id.HARD)


func covers(screen: Vector2) -> bool:
	for btn in [soft_btn, hard_btn, pause_btn]:
		if btn != null and btn.visible and btn.get_global_rect().has_point(screen):
			return true
	return false


func is_compact() -> bool:
	return _compact


func button_bar_height() -> float:
	return 88.0 if _compact and not _short else 0.0


func layout(view: Vector2) -> void:
	if soft_btn == null:
		return
	_compact = view.x < 920.0 or view.y < 580.0
	_short = view.y < 520.0
	var margin := 14.0 if _compact else 16.0
	var font_size := 22 if _compact else 20
	for btn in [soft_btn, hard_btn, pause_btn]:
		btn.add_theme_font_size_override("font_size", font_size)
	var pause_w := 108.0 if _compact else 96.0
	var pause_h := 48.0 if _compact else 40.0
	_pin_top_right(pause_btn, margin, pause_w, pause_h)
	if _compact and not _short:
		var btn_h := 72.0
		_pin_bottom_split(soft_btn, true, margin, btn_h)
		_pin_bottom_split(hard_btn, false, margin, btn_h)
	else:
		var w := 132.0 if not _compact else 118.0
		var h := 48.0 if not _compact else 52.0
		_pin_top_right_stack(soft_btn, margin, pause_h + 10.0, w, h)
		_pin_top_right_stack(hard_btn, margin, pause_h + 10.0 + h + 8.0, w, h)


func _pin_top_right(btn: Button, margin: float, w: float, h: float) -> void:
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left = -margin - w
	btn.offset_right = -margin
	btn.offset_top = margin
	btn.offset_bottom = margin + h


func _pin_top_right_stack(btn: Button, margin: float, top: float, w: float, h: float) -> void:
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left = -margin - w
	btn.offset_right = -margin
	btn.offset_top = margin + top
	btn.offset_bottom = margin + top + h


func _pin_bottom_split(btn: Button, left: bool, margin: float, height: float) -> void:
	var gap := 10.0
	if left:
		btn.anchor_left = 0.0
		btn.anchor_right = 0.5
		btn.offset_left = margin
		btn.offset_right = -gap * 0.5
	else:
		btn.anchor_left = 0.5
		btn.anchor_right = 1.0
		btn.offset_left = gap * 0.5
		btn.offset_right = -margin
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_top = -margin - height
	btn.offset_bottom = -margin


func _hud_locked() -> bool:
	return Time.get_ticks_msec() < _lock_until_msec


func _lock_hud() -> void:
	_lock_until_msec = Time.get_ticks_msec() + 320


func _emit_shot(shot_id: int) -> void:
	if _hud_locked():
		return
	_lock_hud()
	shot_pressed.emit(shot_id)


func _emit_pause() -> void:
	if _hud_locked():
		return
	_lock_hud()
	pause_pressed.emit()


func _make_button(text: String, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_tint(btn, bg, false)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	return btn


func _tint(btn: Button, bg: Color, armed: bool) -> void:
	var fill := bg.lightened(0.18) if armed else bg
	var normal := _box(fill)
	var hover := _box(fill.lightened(0.1))
	var pressed := _box(fill.lightened(0.18))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	box.set_content_margin_all(10)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(1, 1, 1, 0.12)
	return box
