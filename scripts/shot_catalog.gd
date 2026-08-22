class_name ShotCatalog
extends RefCounted

enum Id { SOFT, HARD }

const SMASH_MIN_HEIGHT := 5.5
const CONTACT_HEIGHT := 2.8
const HIGH_CONTACT := 6.4


static func label(id: int, _hitter_in_front: bool = false) -> String:
	return "Soft" if id == Id.SOFT else "Hard"


static func flight_time(id: int, in_air: bool = false, height: float = 0.0) -> float:
	if in_air:
		if id == Id.SOFT:
			return 1.35
		return 0.85 if height >= SMASH_MIN_HEIGHT else 1.05
	if id == Id.SOFT:
		return 2.10
	return 1.55


static func apex_extra(id: int, in_air: bool = false, height: float = 0.0) -> float:
	if in_air:
		if id == Id.SOFT:
			return 2.4
		return 0.15 if height >= SMASH_MIN_HEIGHT else 1.1
	if id == Id.SOFT:
		return 6.4
	return 3.1


static func start_height(id: int, current_height: float) -> float:
	if id == Id.HARD and current_height >= SMASH_MIN_HEIGHT:
		return maxf(current_height, HIGH_CONTACT)
	if current_height > CONTACT_HEIGHT:
		return current_height
	return CONTACT_HEIGHT
