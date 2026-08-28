class_name CourtMap
extends RefCounted

## Court feet to Godot world: X = sideline, Y = height, Z = baseline axis.
## y = 0 is the CPU baseline, y = 44 is the human baseline.


static func to_world(court: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(court.x, height, court.y)


static func to_court(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z)


static func ray_ground(origin: Vector3, dir: Vector3) -> Variant:
	if absf(dir.y) < 0.0001:
		return null
	var t := -origin.y / dir.y
	if t < 0.0:
		return null
	var hit := origin + dir * t
	return Vector2(hit.x, hit.z)


static func mouse_on_ground(camera: Camera3D, mouse: Vector2) -> Variant:
	if camera == null:
		return null
	return ray_ground(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))


## Landing for a human return. South of the net is clamped so the shot still crosses.
static func clamp_aim(court: Vector2) -> Vector2:
	return Vector2(clampf(court.x, -2.0, 22.0), clampf(court.y, -2.0, MatchRules.NET_Y - 0.35))
