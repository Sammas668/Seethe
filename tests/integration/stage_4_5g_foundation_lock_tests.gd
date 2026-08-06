class_name Stage45GFoundationLockTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_explicit_invalidation_contract(failures)
	_test_missing_contract_is_rejected(failures)
	_test_setup_hash_round_trip(failures)
	_test_result_setup_binding(failures)
	_test_trusted_provenance_record(failures)
	_test_revision_rollback_fingerprint(failures)
	return failures


static func _test_explicit_invalidation_contract(failures: Array[String]) -> void:
	var movement := TacticalInvalidationContract.movement(&"mover", &"player")
	_expect(movement.occupancy_changed, "Movement must invalidate occupancy.", failures)
	_expect(movement.moved_observer_ids == [&"mover"], "Movement must scope the moved observer.", failures)
	var attack := TacticalInvalidationContract.attack(&"attacker", &"target")
	_expect(not attack.visibility_changed, "Ordinary attack must not invalidate visibility.", failures)
	var inventory := TacticalInvalidationContract.inventory([&"item"], [&"owner"])
	_expect(inventory.inventory_changed and not inventory.geometry_changed, "Inventory contract must remain narrow.", failures)


static func _test_missing_contract_is_rejected(failures: Array[String]) -> void:
	var state := TacticalState.new()
	var changes := TacticalChangeSet.new(&"missing_contract_test", state.revision)
	changes.set_commit_validation_policy(false, false)
	changes.stage(
		func() -> bool:
			return true,
		Callable(),
		"Should not apply."
	)
	var result: OperationResult = changes.execute(state)
	_expect(not result.success, "Missing invalidation contract must fail.", failures)
	_expect(result.code == &"tactical_invalidation_contract_missing", "Missing contract returned wrong code.", failures)


static func _test_setup_hash_round_trip(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var setup: MissionSetupSnapshot = session.mission_setup
	_expect(setup.verify_integrity(), "Sandbox setup must verify its SHA-256 identity.", failures)
	var restored := MissionSetupSnapshot.from_dictionary(setup.to_dictionary())
	_expect(restored.verify_integrity(), "Reloaded setup must verify integrity.", failures)
	_expect(restored.finalized_setup_hash() == setup.finalized_setup_hash(), "Setup hash changed after round trip.", failures)
	_expect(not restored.configure_identity(&"tampered", 0), "Finalized setup must reject identity mutation.", failures)


static func _test_result_setup_binding(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var result := session.build_mission_result(&"result.stage_4_5g", [], {}, {}, [], false)
	_expect(result.source_setup_hash == session.mission_setup.finalized_setup_hash(), "MissionResult did not bind source setup hash.", failures)
	result.source_setup_hash = "0".repeat(64)
	var campaign := session.campaign_store.call("current_campaign") as CampaignState
	var errors := MissionResultValidator.validate(result, session.mission_setup, campaign, session.content_catalogue)
	_expect(not errors.is_empty(), "Mismatched setup hash must be rejected.", failures)


static func _test_trusted_provenance_record(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	_expect(state.mission_id == session.mission_setup.mission_id, "Tactical mission authority was not bound.", failures)
	var definition: ItemDefinition = null
	for raw_definition: Variant in session.content_catalogue.item_definitions_by_id.values():
		definition = raw_definition as ItemDefinition
		if definition != null:
			break
	if definition == null:
		failures.append("Catalogue has no item definition for provenance test.")
		return
	var item := TacticalItemInstanceState.new(
		&"instance.stage_4_5g.generated",
		definition,
		1,
		1.0,
		TacticalItemLocationState.ground(Vector2i.ZERO, "Test generated item")
	)
	if not state.add_item(item, session.map_definition, false):
		failures.append("Generated provenance test item could not enter tactical state.")
		return
	var provenance := TacticalGeneratedItemProvenance.new()
	provenance.provenance_id = &"provenance.stage_4_5g.generated"
	provenance.mission_id = state.mission_id
	provenance.source_setup_hash = state.source_setup_hash
	provenance.generated_item_id = item.item_id
	provenance.creation_kind = TacticalGeneratedItemProvenance.CREATION_SCRIPTED_REWARD
	provenance.source_event_id = &"event.stage_4_5g.generated"
	provenance.definition_id = item.definition_id
	provenance.quantity = item.quantity
	provenance.condition = item.condition
	provenance.persistent_modifiers = item.tactical_modifiers.duplicate(true)
	provenance.creation_revision = state.revision
	_expect(state.register_generated_item_provenance(provenance), "Trusted provenance could not be registered with its item.", failures)
	var authority := MissionAuthoritySnapshot.from_tactical_state(state, session.mission_setup)
	_expect(authority.verify_integrity(), "Mission authority snapshot failed integrity.", failures)
	_expect(authority.provenance_for_item(item.item_id) != null, "Authority snapshot omitted generated item provenance.", failures)


static func _test_revision_rollback_fingerprint(failures: Array[String]) -> void:
	var state := TacticalState.new()
	var before := TacticalStateFingerprint.capture(state)
	var changes := TacticalChangeSet.new(
		&"stage_4_5g_forced_rollback",
		state.revision,
		TacticalInvalidationContract.no_visual_change()
	)
	changes.set_commit_validation_policy(false, false)
	changes.stage(
		func() -> bool:
			state.occupancy_revision += 10
			state.visibility_blocker_revision += 10
			state.knowledge_state.revision += 10
			state.environment_state.geometry_revision += 10
			return true,
		Callable(),
		"Tentative mutation failed."
	)
	changes.stage(
		func() -> bool:
			return false,
		Callable(),
		"Forced failure.",
		&"forced_failure"
	)
	var result := changes.execute(state)
	var after := TacticalStateFingerprint.capture(state)
	_expect(not result.success, "Forced rollback transaction unexpectedly succeeded.", failures)
	_expect(before == after, "Rejected transaction changed the authoritative state fingerprint.", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
