class_name RangeProfile
extends Resource

const KIND_MELEE: StringName = &"melee"
const KIND_RANGED: StringName = &"ranged"

@export var range_kind: StringName = KIND_MELEE
@export var reach_feet: int = 5
@export var range_increment_feet: int = 0
@export var maximum_increments: int = 1


func summary() -> String:
	if range_kind == KIND_RANGED:
		return "%d ft increment" % maxi(5, range_increment_feet)
	return "%d ft reach" % maxi(5, reach_feet)


func validate_profile(owner_id: StringName = &"") -> Array[String]:
	var errors: Array[String] = []
	if range_kind not in [KIND_MELEE, KIND_RANGED]:
		errors.append("Range profile for %s has an unknown kind." % owner_id)
	if reach_feet < 0 or reach_feet % 5 != 0:
		errors.append("Range profile for %s has an invalid reach." % owner_id)
	if range_kind == KIND_RANGED:
		if range_increment_feet < 5 or range_increment_feet % 5 != 0:
			errors.append("Ranged profile for %s has an invalid increment." % owner_id)
		if maximum_increments < 1:
			errors.append("Ranged profile for %s has no legal increments." % owner_id)
	return errors
