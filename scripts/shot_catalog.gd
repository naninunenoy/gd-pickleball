class_name ShotCatalog
extends RefCounted

enum Id { DRIVE, DROP, VOLLEY, SMASH }

const SMASH_MIN_HEIGHT := 5.5
const CONTACT_HEIGHT := 2.8
const HIGH_CONTACT := 6.4

static func label(id: int, hitter_in_front: bool = false) -> String:
	match id:
		Id.DROP:
			return "ディング" if hitter_in_front else "ドロップ"
		Id.VOLLEY:
			return "ボレー"
		Id.SMASH:
			return "スマッシュ"
		_:
			return "ドライブ"


static func flight_time(id: int) -> float:
	match id:
		Id.DRIVE:
			return 0.86
		Id.DROP:
			return 1.18
		Id.VOLLEY:
			return 0.50
		Id.SMASH:
			return 0.42
	return 0.86


static func apex_extra(id: int) -> float:
	match id:
		Id.DRIVE:
			return 3.1
		Id.DROP:
			return 6.4
		Id.VOLLEY:
			return 1.1
		Id.SMASH:
			return 0.15
	return 3.1


static func start_height(id: int, current_height: float) -> float:
	if id == Id.SMASH:
		return maxf(current_height, HIGH_CONTACT)
	if id == Id.VOLLEY:
		return maxf(current_height, 3.2)
	return maxf(current_height, CONTACT_HEIGHT)


static func resolve_armed(id: int, in_air: bool, height: float, volley_ok: bool) -> int:
	if in_air:
		if id == Id.VOLLEY and volley_ok:
			return Id.VOLLEY
		if id == Id.SMASH and height >= SMASH_MIN_HEIGHT and volley_ok:
			return Id.SMASH
		return Id.DRIVE
	if id == Id.VOLLEY:
		return Id.DRIVE
	if id == Id.SMASH and height < SMASH_MIN_HEIGHT:
		return Id.DRIVE
	if id == Id.SMASH:
		return Id.SMASH
	return id
