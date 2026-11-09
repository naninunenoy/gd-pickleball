class_name CameraRig
extends Node3D

## One fixed overview for both opponent-rally drills.
const OVERVIEW_POSITION := Vector3(6.0, 16.0, 34.5)
const OVERVIEW_TARGET := Vector3(6.0, 1.0, 12.0)
const OVERVIEW_FOV := 46.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	set_volley_mode(false)


func set_volley_mode(_enabled: bool) -> void:
	camera.position = OVERVIEW_POSITION
	camera.look_at(OVERVIEW_TARGET)
	camera.fov = OVERVIEW_FOV
