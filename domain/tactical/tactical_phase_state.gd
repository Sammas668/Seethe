class_name TacticalPhaseState
extends RefCounted

const PLAYER_PHASE: StringName = &"player"
const ENEMY_PHASE: StringName = &"enemy"
const WORLD_PHASE: StringName = &"world"
# Compatibility alias retained for Stage 4.0/4.1 callers and tests.
const ENEMY_TURN: StringName = ENEMY_PHASE

const MODE_SIDE_BASED: StringName = &"side_based"
const MODE_INITIATIVE: StringName = &"initiative"

var round_number: int = 1
var current_phase: StringName = PLAYER_PHASE
var tactical_mode: StringName = MODE_SIDE_BASED
var initiative_order: Array[StringName] = []
var initiative_totals_by_unit_id: Dictionary = {}
var active_initiative_index: int = -1
var contact_round_active: bool = false
# Squads that become aware during an existing combat join the initiative roster
# immediately for presentation, but do not receive an activation until the
# next round boundary. Their rolled totals are retained here until activation.
var pending_initiative_unit_ids: Array[StringName] = []
var pending_initiative_totals_by_unit_id: Dictionary = {}


func is_player_phase() -> bool:
	return current_phase == PLAYER_PHASE


func is_enemy_phase() -> bool:
	return current_phase == ENEMY_PHASE


func is_enemy_turn() -> bool:
	return is_enemy_phase()


func is_world_phase() -> bool:
	return current_phase == WORLD_PHASE


func is_side_based() -> bool:
	return tactical_mode == MODE_SIDE_BASED


func is_initiative_combat() -> bool:
	return tactical_mode == MODE_INITIATIVE


func active_unit_id() -> StringName:
	if not is_initiative_combat():
		return &""
	if active_initiative_index < 0 or active_initiative_index >= initiative_order.size():
		return &""
	return initiative_order[active_initiative_index]


func is_active_unit(unit_id: StringName) -> bool:
	return not unit_id.is_empty() and active_unit_id() == unit_id


func begin_enemy_phase() -> void:
	if is_side_based():
		current_phase = ENEMY_PHASE


func begin_world_phase() -> void:
	if is_side_based():
		current_phase = WORLD_PHASE


func begin_next_player_phase() -> void:
	if is_side_based():
		round_number += 1
		current_phase = PLAYER_PHASE


func begin_initiative(
		order: Array[StringName],
		totals: Dictionary
) -> void:
	tactical_mode = MODE_INITIATIVE
	initiative_order = order.duplicate()
	initiative_totals_by_unit_id = totals.duplicate()
	pending_initiative_unit_ids.clear()
	pending_initiative_totals_by_unit_id.clear()
	active_initiative_index = 0 if not initiative_order.is_empty() else -1
	contact_round_active = true


func queue_initiative_participants(
		unit_ids: Array[StringName],
		totals: Dictionary
) -> void:
	for unit_id: StringName in unit_ids:
		if (
			unit_id.is_empty()
			or initiative_order.has(unit_id)
			or pending_initiative_unit_ids.has(unit_id)
		):
			continue
		pending_initiative_unit_ids.append(unit_id)
		pending_initiative_totals_by_unit_id[unit_id] = int(
			totals.get(unit_id, 0)
		)
	pending_initiative_unit_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var total_a: int = int(pending_initiative_totals_by_unit_id.get(a, 0))
			var total_b: int = int(pending_initiative_totals_by_unit_id.get(b, 0))
			if total_a != total_b:
				return total_a > total_b
			return String(a) < String(b)
	)


# Compatibility name retained for older callers. New participants are queued
# for the following round rather than acting during a partially completed one.
func append_initiative_participants(
		unit_ids: Array[StringName],
		totals: Dictionary
) -> void:
	queue_initiative_participants(unit_ids, totals)


func has_pending_initiative_participants() -> bool:
	return not pending_initiative_unit_ids.is_empty()


func pending_initiative_total(unit_id: StringName) -> int:
	return int(pending_initiative_totals_by_unit_id.get(unit_id, 0))


func activate_round_order(
		order: Array[StringName],
		totals: Dictionary
) -> void:
	initiative_order = order.duplicate()
	initiative_totals_by_unit_id = totals.duplicate()
	pending_initiative_unit_ids.clear()
	pending_initiative_totals_by_unit_id.clear()
	active_initiative_index = 0 if not initiative_order.is_empty() else -1


func advance_initiative_index() -> bool:
	if initiative_order.is_empty():
		active_initiative_index = -1
		return false
	active_initiative_index += 1
	var wrapped: bool = false
	if active_initiative_index >= initiative_order.size():
		active_initiative_index = 0
		round_number += 1
		contact_round_active = false
		wrapped = true
	return wrapped


func remove_initiative_participant(unit_id: StringName) -> void:
	pending_initiative_unit_ids.erase(unit_id)
	pending_initiative_totals_by_unit_id.erase(unit_id)
	var removed_index: int = initiative_order.find(unit_id)
	if removed_index < 0:
		return
	var active_index_before: int = active_initiative_index
	initiative_order.remove_at(removed_index)
	initiative_totals_by_unit_id.erase(unit_id)
	if initiative_order.is_empty():
		active_initiative_index = -1
		return
	if removed_index < active_index_before:
		active_initiative_index = active_index_before - 1
	elif removed_index == active_index_before:
		# The unit at the same numeric slot is now the next participant. If the
		# removed unit was last, the next participant is the first entry. The
		# TacticalState lifecycle decides whether that also begins a new round.
		active_initiative_index = (
			0 if removed_index >= initiative_order.size() else removed_index
		)
	else:
		active_initiative_index = active_index_before
	active_initiative_index = clampi(
		active_initiative_index,
		0,
		initiative_order.size() - 1
	)


func initiative_total(unit_id: StringName) -> int:
	if initiative_totals_by_unit_id.has(unit_id):
		return int(initiative_totals_by_unit_id.get(unit_id, 0))
	return pending_initiative_total(unit_id)


func end_initiative(next_phase: StringName = PLAYER_PHASE) -> void:
	tactical_mode = MODE_SIDE_BASED
	current_phase = next_phase
	initiative_order.clear()
	initiative_totals_by_unit_id.clear()
	pending_initiative_unit_ids.clear()
	pending_initiative_totals_by_unit_id.clear()
	active_initiative_index = -1
	contact_round_active = false


func snapshot() -> Dictionary:
	return {
		"round_number": round_number,
		"current_phase": current_phase,
		"tactical_mode": tactical_mode,
		"initiative_order": initiative_order.duplicate(),
		"initiative_totals": initiative_totals_by_unit_id.duplicate(),
		"active_index": active_initiative_index,
		"contact_round": contact_round_active,
		"pending_initiative": pending_initiative_unit_ids.duplicate(),
		"pending_totals": pending_initiative_totals_by_unit_id.duplicate(),
	}


func restore(snapshot_value: Dictionary) -> void:
	round_number = int(snapshot_value.get("round_number", 1))
	current_phase = StringName(snapshot_value.get("current_phase", PLAYER_PHASE))
	tactical_mode = StringName(snapshot_value.get("tactical_mode", MODE_SIDE_BASED))
	initiative_order.clear()
	for value: Variant in snapshot_value.get("initiative_order", []):
		initiative_order.append(StringName(value))
	var totals_value: Variant = snapshot_value.get("initiative_totals", {})
	initiative_totals_by_unit_id = (
		totals_value.duplicate() if totals_value is Dictionary else {}
	)
	active_initiative_index = int(snapshot_value.get("active_index", -1))
	contact_round_active = bool(snapshot_value.get("contact_round", false))
	pending_initiative_unit_ids.clear()
	for value: Variant in snapshot_value.get("pending_initiative", []):
		pending_initiative_unit_ids.append(StringName(value))
	var pending_totals_value: Variant = snapshot_value.get("pending_totals", {})
	pending_initiative_totals_by_unit_id = (
		pending_totals_value.duplicate()
		if pending_totals_value is Dictionary
		else {}
	)
