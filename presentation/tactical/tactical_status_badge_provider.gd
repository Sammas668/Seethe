class_name TacticalStatusBadgeProvider
extends RefCounted

const BADGE_KIND_NONE: StringName = &"none"
const BADGE_KIND_UNCONSCIOUS: StringName = &"unconscious"
const BADGE_KIND_DYING: StringName = &"dying"
const BADGE_KIND_DEAD: StringName = &"dead"


static func for_unit(unit: TacticalUnitState) -> Dictionary:
	if unit == null:
		return empty_snapshot()
	return snapshot_from_values(
		unit.life_state_id(),
		unit.dying_successes,
		unit.dying_failures,
		unit.restrained
	)


static func for_body_item(
		state: TacticalState,
		body_item: TacticalItemInstanceState
) -> Dictionary:
	if state == null or body_item == null or not body_item.is_body():
		return empty_snapshot()
	return for_unit(state.get_unit(body_item.linked_unit_id))


static func snapshot_from_values(
		life_state: StringName,
		dying_successes: int = 0,
		dying_failures: int = 0,
		restrained: bool = false
) -> Dictionary:
	return {
		"primary_kind": primary_kind_for_life_state(life_state),
		"life_state": life_state,
		"dying_successes": clampi(dying_successes, 0, 3),
		"dying_failures": clampi(dying_failures, 0, 3),
		"stable": life_state == TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS,
		"unconscious": life_state in [
			TacticalUnitState.LIFE_STATE_DYING,
			TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS,
			TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS,
		],
		"restrained": restrained,
	}


static func primary_kind_for_life_state(life_state: StringName) -> StringName:
	match life_state:
		TacticalUnitState.LIFE_STATE_DEAD:
			return BADGE_KIND_DEAD
		TacticalUnitState.LIFE_STATE_DYING:
			return BADGE_KIND_DYING
		TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS:
			return BADGE_KIND_UNCONSCIOUS
		TacticalUnitState.LIFE_STATE_NONLETHAL_UNCONSCIOUS:
			return BADGE_KIND_UNCONSCIOUS
	return BADGE_KIND_NONE


static func empty_snapshot() -> Dictionary:
	return snapshot_from_values(TacticalUnitState.LIFE_STATE_NORMAL)
