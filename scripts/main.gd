extends Node2D

const ICON_HALF_SIZE := 64.0

@onready var status: Label = $UI/Status
@onready var icon: Sprite2D = $Icon

var _velocity := Vector2(220, 160)


func _ready() -> void:
	var version := Engine.get_version_info()
	status.text = "\n".join([
		"GDScript WASM smoke test",
		"Godot %s" % version.get("string", "?"),
		"Click / tap to bounce",
	])
	icon.position = get_viewport_rect().size * 0.5


func _process(delta: float) -> void:
	var bounds := get_viewport_rect().size
	icon.position += _velocity * delta
	icon.rotation += delta

	if icon.position.x < ICON_HALF_SIZE:
		icon.position.x = ICON_HALF_SIZE
		_velocity.x = absf(_velocity.x)
	elif icon.position.x > bounds.x - ICON_HALF_SIZE:
		icon.position.x = bounds.x - ICON_HALF_SIZE
		_velocity.x = -absf(_velocity.x)

	if icon.position.y < ICON_HALF_SIZE:
		icon.position.y = ICON_HALF_SIZE
		_velocity.y = absf(_velocity.y)
	elif icon.position.y > bounds.y - ICON_HALF_SIZE:
		icon.position.y = bounds.y - ICON_HALF_SIZE
		_velocity.y = -absf(_velocity.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_velocity = _velocity.rotated(randf_range(-0.6, 0.6)) * 1.08
		_velocity = _velocity.limit_length(520.0)
	elif event is InputEventScreenTouch and event.pressed:
		_velocity = _velocity.rotated(randf_range(-0.6, 0.6)) * 1.08
		_velocity = _velocity.limit_length(520.0)
