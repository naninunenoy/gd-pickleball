class_name CameraRig
extends Node3D

## Fixed portrait composition: the wall, bounce and player stay in view.
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.position = Vector3(WallRally.WIDTH * 0.5, 16.0, 34.5)
	camera.look_at(Vector3(WallRally.WIDTH * 0.5, 1.0, 12.0))
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 46.0
