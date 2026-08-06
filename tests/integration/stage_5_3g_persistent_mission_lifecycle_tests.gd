class_name Stage53GPersistentMissionLifecycleTests
extends RefCounted

const EXTRACTION_ZONE_ID: StringName = &"extraction.player.start"
const GRAIN_CRATE_ID: StringName = &"instance.ground.grain_crate"
const BANDAGES_ID: StringName = &"instance.ground.bandages"
const EVENT_JOURNAL_SCRIPT: Script = preload(
	"res://application/tactical/events/tactical_event_journal.gd"
)


class FailingRepository:
	extends RefCounted

	var last_save_error: String = "Forced Stage 5.3G persistence failure."

	func save_campaign(_campaign: CampaignState) -> bool:
		return false


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_atomic_return_with_multiple_carriers_and_death(failures)
	_test_full_backpack_extraction_preserves_every_item(failures)
	_test_missing_character_remains_unavailable(failures)
	_test_recovery_selection_rebuilds_captures_xp_and_history(failures)
	_test_pending_result_round_trip_migration(failures)
	return failures


static func _test_atomic_return_with_multiple_carriers_and_death(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var scout: TacticalUnitState = state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	var archer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var grain: TacticalItemInstanceState = state.get_item(GRAIN_CRATE_ID)
	var bandages: TacticalItemInstanceState = state.get_item(BANDAGES_ID)
	_expect(
		marauder != null and scout != null and archer != null and enemy != null,
		"Stage 5.3G fixture is missing a required tactical unit.",
		failures
	)
	_expect(
		grain != null and bandages != null,
		"Stage 5.3G fixture is missing authored mission loot.",
		failures
	)
	if (
		marauder == null
		or scout == null
		or archer == null
		or enemy == null
		or grain == null
		or bandages == null
	):
		return

	grain.location = TacticalItemLocationState.unit_grid(
		marauder.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		Vector2i(3, 2)
	)
	bandages.location = TacticalItemLocationState.unit_grid(
		scout.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		Vector2i(4, 2)
	)
	scout.current_hp = maxi(1, scout.maximum_hp - 3)
	archer.grid_position = Vector2i(20, 20)
	archer.current_hp = -10
	archer.dead = true
	archer.combat_state = TacticalUnitState.COMBAT_STATE_DEFEATED
	enemy.current_hp = -10
	enemy.dead = true
	enemy.combat_state = TacticalUnitState.COMBAT_STATE_DEFEATED
	state.rebuild_ground_item_index()

	var journal: RefCounted = EVENT_JOURNAL_SCRIPT.new()
	journal.call("append_event", {
		"event_type": &"attack_resolved",
		"source_actor_id": TacticalSandboxFactory.MARAUDER_ID,
		"target_actor_ids": [TacticalSandboxFactory.ENEMY_ID],
		"metadata": {
			"target_became_defeated": true,
			"target_life_state": TacticalUnitState.LIFE_STATE_DEAD,
		},
		"visibility": &"player",
	})
	journal.call("append_event", {
		"event_type": &"first_aid",
		"source_actor_id": TacticalSandboxFactory.SCOUT_ID,
		"target_actor_ids": [TacticalSandboxFactory.MARAUDER_ID],
		"roll_records": [{"outcome": &"success"}],
		"visibility": &"player",
	})

	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		EXTRACTION_ZONE_ID
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.stage_5_3g.atomic_return",
		session.mission_setup,
		state,
		manifest
	)
	MissionCharacterOutcomeService.populate(
		result,
		session.mission_setup,
		state,
		journal
	)
	result.mission_statistics["allies_stabilised"] = 1
	MissionExperienceAwardService.apply_awards(result, session.mission_setup)
	MissionCharacterOutcomeService.refresh_history(result, session.mission_setup)

	var marauder_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var scout_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.SCOUT_ID
	)
	var archer_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.ARCHER_ID
	)
	_expect(
		marauder_result != null and marauder_result.loot_item_ids.has(GRAIN_CRATE_ID),
		"The first extracted carrier did not retain the Grain Crate as new loot.",
		failures
	)
	_expect(
		scout_result != null and scout_result.loot_item_ids.has(BANDAGES_ID),
		"The second extracted carrier did not retain the Bandages as new loot.",
		failures
	)
	_expect(
		scout_result != null
		and scout_result.outcome_state == MissionCharacterResult.OUTCOME_EXTRACTED_WOUNDED
		and scout_result.current_hp == scout.current_hp,
		"An extracted wounded troop did not retain its persistent health outcome.",
		failures
	)
	_expect(
		archer_result != null
		and archer_result.outcome_state == MissionCharacterResult.OUTCOME_DEAD_UNRECOVERED,
		"A dead unrecovered carrier was not recorded as permanently lost.",
		failures
	)
	_expect(
		marauder_result != null and marauder_result.statistic(&"kills") == 1,
		"Personal kill contribution was not preserved on the mission result.",
		failures
	)
	_expect(
		scout_result != null and scout_result.statistic(&"allies_stabilised") == 1,
		"Successful First Aid was not preserved on the supporting troop's history.",
		failures
	)
	_expect(
		marauder_result != null
		and marauder_result.xp_awarded > 0
		and not marauder_result.xp_award_breakdown.is_empty(),
		"An eligible returning troop did not receive itemised mission XP.",
		failures
	)
	_expect(
		archer_result != null and archer_result.xp_awarded == 0,
		"A dead unrecovered troop incorrectly received mission XP.",
		failures
	)

	var round_trip: MissionResult = MissionResult.from_dictionary(result.to_dictionary())
	_expect(
		round_trip != null
		and round_trip.get_character_result(TacticalSandboxFactory.MARAUDER_ID).mission_statistics
		== marauder_result.mission_statistics
		and round_trip.get_character_result(TacticalSandboxFactory.MARAUDER_ID).xp_award_breakdown
		== marauder_result.xp_award_breakdown,
		"Pending mission-summary save/load lost character statistics or XP provenance.",
		failures
	)

	var authority: MissionAuthoritySnapshot = MissionAuthoritySnapshot.from_tactical_state(
		state,
		session.mission_setup
	)
	var envelope := MissionCommitEnvelope.new(session.mission_setup, result, authority)
	var initial_campaign: CampaignState = CampaignState.from_dictionary(
		session.screen_facade.current_campaign().to_dictionary()
	)
	var precommit_data: Dictionary = initial_campaign.to_dictionary()
	var store := CampaignStateStore.new()
	store.configure(initial_campaign, null, session.content_catalogue)
	var commit_service := CampaignResultCommitService.new()
	commit_service.configure(store, session.content_catalogue)
	var committed: OperationResult = commit_service.commit_envelope(envelope)
	_expect(
		committed.success,
		"The atomic mission lifecycle result failed to commit: %s" % committed.message,
		failures
	)
	if not committed.success:
		return
	var campaign: CampaignState = store.current_campaign()
	var returned_grain: CampaignItemState = campaign.get_item(GRAIN_CRATE_ID)
	var returned_bandages: CampaignItemState = campaign.get_item(BANDAGES_ID)
	_expect(
		returned_grain != null
		and returned_grain.location != null
		and returned_grain.location.belongs_to_character(TacticalSandboxFactory.MARAUDER_ID),
		"The Grain Crate lost its stable ID or carrier location during campaign commit.",
		failures
	)
	_expect(
		returned_bandages != null
		and returned_bandages.location != null
		and returned_bandages.location.belongs_to_character(TacticalSandboxFactory.SCOUT_ID),
		"The Bandages lost their stable ID or carrier location during campaign commit.",
		failures
	)
	var committed_scout: PersistentCharacterState = campaign.get_character(
		TacticalSandboxFactory.SCOUT_ID
	)
	var committed_archer: PersistentCharacterState = campaign.get_character(
		TacticalSandboxFactory.ARCHER_ID
	)
	_expect(
		committed_scout != null
		and committed_scout.health_condition_id(scout.maximum_hp) == &"wounded"
		and committed_scout.history_entries.has(scout_result.history_entry),
		"Persistent health or mission history did not survive the return transaction.",
		failures
	)
	_expect(
		committed_archer != null and committed_archer.is_dead,
		"The dead troop was not permanently marked for Memorial presentation.",
		failures
	)
	var post_commit_round_trip: CampaignState = CampaignState.from_dictionary(
		campaign.to_dictionary()
	)
	_expect(
		post_commit_round_trip.has_applied_result(result.result_id)
		and post_commit_round_trip.get_item(GRAIN_CRATE_ID) != null
		and post_commit_round_trip.get_character(TacticalSandboxFactory.ARCHER_ID).is_dead,
		"Post-commit save/load lost result, loot or death state.",
		failures
	)

	var revision_after_first_commit: int = campaign.revision
	var duplicate: OperationResult = commit_service.commit_envelope(envelope)
	_expect(
		duplicate.success
		and duplicate.code in [&"already_applied", &"mission_already_resolved"]
		and store.current_campaign().revision == revision_after_first_commit,
		"Reloading or retrying the same result applied mission state more than once.",
		failures
	)

	var failing_store := CampaignStateStore.new()
	failing_store.configure(
		CampaignState.from_dictionary(precommit_data),
		FailingRepository.new(),
		session.content_catalogue
	)
	var failing_commit_service := CampaignResultCommitService.new()
	failing_commit_service.configure(failing_store, session.content_catalogue)
	var before_failed_save: Dictionary = failing_store.current_campaign().to_dictionary()
	var failed_commit: OperationResult = failing_commit_service.commit_envelope(envelope)
	_expect(
		not failed_commit.success
		and failed_commit.code == &"campaign_save_failed"
		and failing_store.current_campaign().to_dictionary() == before_failed_save,
		"A rejected persistence attempt partially mutated the authoritative campaign.",
		failures
	)


static func _test_full_backpack_extraction_preserves_every_item(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var filler_definition: ItemDefinition = session.content_catalogue.item_definition(&"item.bandage")
	if marauder == null or filler_definition == null:
		failures.append("The full-Backpack fixture could not resolve its troop or filler item.")
		return
	var added_ids: Array[StringName] = []
	for y: int in range(TacticalInventoryState.BACKPACK_HEIGHT):
		for x: int in range(TacticalInventoryState.BACKPACK_WIDTH):
			var item_id := StringName("item.stage_5_3g.backpack.%02d.%02d" % [x, y])
			var filler := TacticalItemInstanceState.new(
				item_id,
				filler_definition,
				1,
				1.0,
				TacticalItemLocationState.unit_grid(
					marauder.unit_id,
					TacticalInventoryState.KIND_BACKPACK,
					Vector2i(x, y)
				)
			)
			filler.weight_override_lb = 0.0
			filler.footprint_override = Vector2i.ONE
			if not state.can_place_item(
				marauder,
				filler,
				TacticalInventoryState.KIND_BACKPACK,
				Vector2i(x, y)
			):
				continue
			if state.add_item(filler, session.map_definition):
				added_ids.append(item_id)
	var probe := TacticalItemInstanceState.new(
		&"item.stage_5_3g.backpack.probe",
		filler_definition,
		1,
		1.0,
		TacticalItemLocationState.unit_grid(
			marauder.unit_id,
			TacticalInventoryState.KIND_BACKPACK,
			Vector2i.ZERO
		)
	)
	probe.weight_override_lb = 0.0
	probe.footprint_override = Vector2i.ONE
	var open_cell_exists: bool = false
	for y: int in range(TacticalInventoryState.BACKPACK_HEIGHT):
		for x: int in range(TacticalInventoryState.BACKPACK_WIDTH):
			if state.can_place_item(
				marauder,
				probe,
				TacticalInventoryState.KIND_BACKPACK,
				Vector2i(x, y)
			):
				open_cell_exists = true
				break
		if open_cell_exists:
			break
	_expect(
		not added_ids.is_empty() and not open_cell_exists,
		"The full-Backpack fixture did not actually fill every remaining cell.",
		failures
	)
	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		EXTRACTION_ZONE_ID
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.stage_5_3g.full_backpack",
		session.mission_setup,
		state,
		manifest
	)
	var character_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	)
	for item_id: StringName in added_ids:
		_expect(
			manifest.extracted_item_ids.has(item_id)
			and character_result != null
			and character_result.equipment_item_ids.has(item_id),
			"A full Backpack dropped item %s during extraction." % item_id,
			failures
		)


static func _test_missing_character_remains_unavailable(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var scout: TacticalUnitState = state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	if scout == null:
		failures.append("The missing-character fixture has no Scout.")
		return
	scout.grid_position = Vector2i(20, 20)
	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		EXTRACTION_ZONE_ID
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.stage_5_3g.missing",
		session.mission_setup,
		state,
		manifest
	)
	MissionCharacterOutcomeService.populate(result, session.mission_setup, state, null)
	MissionExperienceAwardService.apply_awards(result, session.mission_setup)
	MissionCharacterOutcomeService.refresh_history(result, session.mission_setup)
	var scout_result: MissionCharacterResult = result.get_character_result(
		TacticalSandboxFactory.SCOUT_ID
	)
	_expect(
		scout_result != null
		and scout_result.outcome_state == MissionCharacterResult.OUTCOME_ALIVE_UNRECOVERED
		and scout_result.injury_entries.has("Missing / Unrecovered")
		and scout_result.xp_awarded == 0,
		"An alive troop left outside extraction was not recorded as missing without XP.",
		failures
	)

	var store := CampaignStateStore.new()
	store.configure(
		CampaignState.from_dictionary(
			session.screen_facade.current_campaign().to_dictionary()
		),
		null,
		session.content_catalogue
	)
	var service := CampaignResultCommitService.new()
	service.configure(store, session.content_catalogue)
	var authority := MissionAuthoritySnapshot.from_tactical_state(
		state,
		session.mission_setup
	)
	var committed: OperationResult = service.commit_envelope(
		MissionCommitEnvelope.new(session.mission_setup, result, authority)
	)
	_expect(committed.success, "The missing-character result failed to commit.", failures)
	if committed.success:
		var persisted: PersistentCharacterState = store.current_campaign().get_character(
			TacticalSandboxFactory.SCOUT_ID
		)
		_expect(
			persisted != null
			and persisted.is_missing_or_unrecovered()
			and not persisted.can_deploy_with_health(20),
			"A missing troop became deployable after the mission reservation ended.",
			failures
		)


static func _test_recovery_selection_rebuilds_captures_xp_and_history(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var grain: TacticalItemInstanceState = state.get_item(GRAIN_CRATE_ID)
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if grain == null or marauder == null:
		failures.append("The recovery-filter fixture is incomplete.")
		return
	grain.location = TacticalItemLocationState.unit_grid(
		marauder.unit_id,
		TacticalInventoryState.KIND_BACKPACK,
		Vector2i(3, 2)
	)
	state.rebuild_ground_item_index()
	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		EXTRACTION_ZONE_ID
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.stage_5_3g.selection",
		session.mission_setup,
		state,
		manifest
	)
	var captive := MissionCaptiveResult.new()
	captive.character_id = TacticalSandboxFactory.ENEMY_ID
	captive.source_definition_id = TacticalSandboxFactory.ENEMY_TEMPLATE_ID
	captive.display_name = "Captured Guard"
	captive.body_item_id = &"body.synthetic.captive"
	captive.restraint_item_id = &"instance.marauder.manacles"
	captive.condition_at_extraction = TacticalUnitState.LIFE_STATE_STABLE_UNCONSCIOUS
	captive.maximum_hp = 10
	captive.current_hp = 1
	captive.faction_id = &"faction.life"
	captive.captured_mission_id = result.mission_id
	captive.captor_character_id = TacticalSandboxFactory.MARAUDER_ID
	result.add_captive_result(captive)
	result.mission_statistics["captives_taken"] = 1
	MissionCharacterOutcomeService.populate(result, session.mission_setup, state, null)
	MissionExperienceAwardService.apply_awards(result, session.mission_setup)
	MissionCharacterOutcomeService.refresh_history(result, session.mission_setup)
	var initial_xp: int = result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	).xp_awarded
	var authority := MissionAuthoritySnapshot.from_tactical_state(
		state,
		session.mission_setup
	)
	var envelope := MissionCommitEnvelope.new(session.mission_setup, result, authority)
	var recovery_service := MissionRecoverySelectionService.new()
	recovery_service.configure(session.content_catalogue)
	var filtered: OperationResult = recovery_service.filter_envelope(
		envelope,
		[],
		[]
	)
	_expect(
		filtered.success,
		"Recovery selection failed to create a new immutable result: %s" % filtered.message,
		failures
	)
	if not filtered.success:
		return
	var filtered_envelope: MissionCommitEnvelope = filtered.value as MissionCommitEnvelope
	var filtered_result: MissionResult = filtered_envelope.result
	var filtered_marauder: MissionCharacterResult = filtered_result.get_character_result(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(
		filtered_result.get_captive_results().is_empty()
		and filtered_result.mission_statistics.get("captives_taken", -1) == 0,
		"An unselected captive remained in the mission cargo transaction.",
		failures
	)
	var grain_still_recovered: bool = false
	for entry: Dictionary in filtered_result.extracted_item_entries:
		if StringName(entry.get("item_id", "")) == GRAIN_CRATE_ID:
			grain_still_recovered = true
			break
	_expect(
		not grain_still_recovered
		and filtered_result.abandoned_item_ids.has(GRAIN_CRATE_ID),
		"Unselected optional loot was not moved from recovered cargo to abandoned items.",
		failures
	)
	_expect(
		filtered_marauder != null
		and filtered_marauder.statistic(&"captures") == 0
		and filtered_marauder.xp_awarded == initial_xp - 10
		and not filtered_marauder.history_entry.contains("Captures secured"),
		"Captive removal did not rebuild contribution, XP and permanent history together.",
		failures
	)


static func _test_pending_result_round_trip_migration(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var manifest: TacticalExtractionManifest = session.screen_facade.preview_extraction_manifest(
		EXTRACTION_ZONE_ID
	)
	var legacy_result: MissionResult = MissionResultBuilder.build_extraction_result(
		&"result.stage_5_3g.legacy_pending",
		session.mission_setup,
		state,
		manifest
	)
	for character_result: MissionCharacterResult in legacy_result.get_character_results():
		if character_result.was_deployed and character_result.survived and character_result.extracted:
			character_result.xp_awarded = 50
			character_result.xp_award_breakdown.clear()
		character_result.mission_statistics.clear()
		character_result.completed_objective_ids.clear()
		character_result.failed_objective_ids.clear()
	_expect(
		MissionCharacterOutcomeService.needs_lifecycle_migration(legacy_result),
		"A pre-Stage-5.3G pending result was not recognised for migration.",
		failures
	)
	MissionCharacterOutcomeService.reconcile_after_recovery_selection(
		legacy_result,
		session.mission_setup
	)
	MissionExperienceAwardService.apply_awards(legacy_result, session.mission_setup)
	MissionCharacterOutcomeService.refresh_history(legacy_result, session.mission_setup)
	_expect(
		not MissionCharacterOutcomeService.needs_lifecycle_migration(legacy_result)
		and MissionExperienceAwardService.validate_awards(
			legacy_result,
			session.mission_setup
		).is_empty(),
		"A pending result could not be normalised after loading the new lifecycle schema.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
