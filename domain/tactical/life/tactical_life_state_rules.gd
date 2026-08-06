class_name TacticalLifeStateRules
extends RefCounted

const STATE_NORMAL: StringName = &"normal"
const STATE_DISABLED: StringName = &"disabled"
const STATE_DYING: StringName = &"dying"
const STATE_STABLE_UNCONSCIOUS: StringName = &"stable_unconscious"
const STATE_NONLETHAL_UNCONSCIOUS: StringName = &"nonlethal_unconscious"
const STATE_DEAD: StringName = &"dead"

const DYING_SUCCESS_TARGET: int = 3
const DYING_FAILURE_TARGET: int = 3


static func death_threshold_hp(constitution_score: int) -> int:
	return -maxi(1, constitution_score)


static func dying_check_dc(current_hp: int) -> int:
	return maxi(10, 10 - current_hp)


static func required_natural_roll(dc: int, modifier: int) -> int:
	return clampi(dc - modifier, 2, 20)


static func resolve_state(
		current_hp: int,
		constitution_score: int,
		stable: bool,
		dead: bool,
		nonlethal_damage: int
) -> StringName:
	if dead or current_hp <= death_threshold_hp(constitution_score):
		return STATE_DEAD
	if current_hp < 0:
		return STATE_STABLE_UNCONSCIOUS if stable else STATE_DYING
	# Nonlethal unconsciousness overrides Disabled when the accumulated
	# nonlethal total is already greater than the remaining non-negative HP.
	if nonlethal_damage > current_hp:
		return STATE_NONLETHAL_UNCONSCIOUS
	if current_hp == 0:
		return STATE_DISABLED
	return STATE_NORMAL


static func is_unconscious_state(state_id: StringName) -> bool:
	return state_id in [
		STATE_DYING,
		STATE_STABLE_UNCONSCIOUS,
		STATE_NONLETHAL_UNCONSCIOUS,
	]


static func is_downed_state(state_id: StringName) -> bool:
	return is_unconscious_state(state_id) or state_id == STATE_DEAD
