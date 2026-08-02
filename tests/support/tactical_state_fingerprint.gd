class_name TacticalStateFingerprint
extends RefCounted


static func capture(state: TacticalState, dice_roller: TacticalDiceRoller = null) -> String:
	if state == null:
		return ""
	var units: Array[Dictionary] = []
	for unit: TacticalUnitState in state.get_units():
		units.append({
			"unit_id": String(unit.unit_id),
			"position": unit.grid_position,
			"hp": unit.current_hp,
			"nonlethal": unit.nonlethal_damage,
			"combat_state": String(unit.combat_state),
			"budget": {
				"maximum": unit.action_budget.maximum_turn_capacity_feet,
				"remaining": unit.action_budget.remaining_turn_capacity_feet,
				"spent": unit.action_budget.normal_capacity_spent_feet,
				"quick": unit.action_budget.quick_action_available,
				"reaction": unit.action_budget.reaction_snapshot(),
				"ordinary_attack": unit.action_budget.ordinary_attack_available,
				"ended": unit.action_budget.ended_activation,
			},
		})
	var items: Array[Dictionary] = []
	for item: TacticalItemInstanceState in state.get_items():
		items.append(item.to_dictionary())
	var payload: Dictionary = {
		"revision": state.revision,
		"occupancy_revision": state.occupancy_revision,
		"visibility_blocker_revision": state.visibility_blocker_revision,
		"knowledge_revision": state.knowledge_state.revision,
		"environment_geometry_revision": state.geometry_revision(),
		"occupancy_signature": state.authoritative_occupancy_signature(),
		"visibility_signature": state.authoritative_visibility_blocker_signature(),
		"units": units,
		"items": items,
		"knowledge": state.knowledge_snapshot(),
		"pending": _pending_payload(state.pending_movement_reaction),
		"mission_id": String(state.mission_id),
		"source_setup_hash": state.source_setup_hash,
		"provenance": [],
	}
	var provenance_entries: Array[Dictionary] = []
	for provenance: TacticalGeneratedItemProvenance in state.generated_item_provenance_records():
		provenance_entries.append(provenance.to_dictionary())
	payload["provenance"] = provenance_entries
	if dice_roller != null:
		payload["rng"] = dice_roller.snapshot_state()
	return CanonicalDataHasher.sha256_hex(payload)


static func _pending_payload(pending: PendingMovementReactionState) -> Dictionary:
	if pending == null:
		return {}
	return {
		"movement_action_id": String(pending.movement_action_id),
		"mover_unit_id": String(pending.mover_unit_id),
		"full_path": pending.full_path.duplicate(),
		"committed_prefix": pending.committed_prefix.duplicate(),
		"next_step_index": pending.next_step_index,
		"current_position": pending.current_position,
		"pending_timing_kind": String(pending.pending_timing_kind),
		"continuation_kind": String(pending.continuation_kind),
		"source_revision": pending.source_revision,
	}
