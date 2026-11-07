class_name CameraRig
extends Node3D

## Fixed portrait composition: the wall, bounce and player stay in view.
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	set_volley_mode(false)
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 46.0


func set_volley_mode(enabled: bool) -> void:
	camera.position = Vector3(6.0, 20.0, 32.0) if enabled else Vector3(6.0, 16.0, 34.5)
	camera.look_at(Vector3(6.0, 0.0, 11.5) if enabled else Vector3(6.0, 1.0, 12.0))
