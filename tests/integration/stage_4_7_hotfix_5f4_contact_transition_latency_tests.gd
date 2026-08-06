class_name Stage47Hotfix5f4ContactTransitionLatencyTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var state := TacticalState.new()
	var player := TacticalUnitState.new(
		&"contact.player",
		"Player",
		Vector2i(2, 2),
		80,
		&"player"
	)
	var guard := TacticalUnitState.new(
		&"contact.guard",
		"Guard",
		Vector2i(4, 2),
		80,
		&"enemy"
	)
	var unrelated := TacticalUnitState.new(
		&"contact.unrelated",
		"Unrelated",
		Vector2i(8, 8),
		80,
		&"enemy"
	)
	state.units_by_id[player.unit_id] = player
	state.units_by_id[guard.unit_id] = guard
	state.units_by_id[unrelated.unit_id] = unrelated
	state.rebuild_unit_occupancy()

	var squad := TacticalSquadState.new(
		&"squad.contact",
		&"enemy",
		[guard.unit_id]
	)
	squad.make_aware()
	squad.remember_last_seen(player.unit_id, player.grid_position)
	state.squads_by_id[squad.squad_id] = squad
	guard.squad_id = squad.squad_id
	player.reveal_to_squad(squad.squad_id)
	var unrelated_squad := TacticalSquadState.new(
		&"squad.unrelated",
		&"enemy",
		[unrelated.unit_id]
	)
	state.squads_by_id[unrelated_squad.squad_id] = unrelated_squad
	unrelated.squad_id = unrelated_squad.squad_id

	var store := TacticalStateStore.new(state)
	var service := TacticalDetectionService.new()
	service.set("_state_store", store)

	var unchanged := TacticalDetectionResolution.new()
	unchanged.unit_id = player.unit_id
	unchanged.revealed_at_destination_squad_ids.append(squad.squad_id)
	unchanged.last_seen_tile_by_squad_id[squad.squad_id] = player.grid_position
	_expect(
		not bool(service.call("_resolution_changes_authoritative_state", unchanged)),
		"Identical revelation and last-seen values must not create a perception transaction.",
		failures
	)

	var moved := TacticalDetectionResolution.new()
	moved.unit_id = player.unit_id
	moved.last_seen_tile_by_squad_id[squad.squad_id] = Vector2i(3, 2)
	_expect(
		bool(service.call("_resolution_changes_authoritative_state", moved)),
		"A changed last-seen tile must invalidate the no-change fast path.",
		failures
	)

	var contact := TacticalDetectionResolution.new()
	contact.unit_id = player.unit_id
	contact.detected_squad_ids.append(squad.squad_id)
	contact.newly_aware_squad_ids.append(squad.squad_id)
	contact.revealed_at_destination_squad_ids.append(squad.squad_id)
	contact.last_seen_tile_by_squad_id[squad.squad_id] = player.grid_position
	service.call("_prime_perception_signatures_from_resolution", contact)
	var current: OperationResult = service.call(
		"_refresh_current_perception_for_squad",
		squad.squad_id,
		true
	) as OperationResult
	_expect(
		current != null and current.code == &"perception_current_from_contact",
		"The committed contact result must satisfy the first AI perception refresh.",
		failures
	)

	var support := DetectionBatchTransactionSupport.new()
	support.configure(store)
	contact.initiative_totals_by_unit_id[player.unit_id] = 20
	contact.initiative_totals_by_unit_id[guard.unit_id] = 15
	var snapshot: Dictionary = support.snapshot_for_resolutions([contact])
	var squad_snapshots: Dictionary = snapshot.get("squads", {})
	var budgets: Array = snapshot.get("budgets", [])
	_expect(
		squad_snapshots.size() == 1 and squad_snapshots.has(squad.squad_id),
		"Contact rollback must snapshot only the affected squad.",
		failures
	)
	_expect(
		budgets.size() == 2,
		"Contact rollback must snapshot only initiative participants' budgets.",
		failures
	)
	return failures


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
