class_name ResolveTacticalMissionHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _setup: MissionSetupSnapshot
var _campaign_store: RefCounted
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _commit_service: CampaignResultCommitService


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		setup: MissionSetupSnapshot,
		campaign_store: RefCounted,
		catalogue: ContentCatalogue,
		event_journal: RefCounted
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_setup = setup
	_campaign_store = campaign_store
	_catalogue = catalogue
	_event_journal = event_journal
	_commit_service = CampaignResultCommitService.new()
	_commit_service.configure(_campaign_store, _catalogue)


func preview_manifest(zone_id: StringName) -> TacticalExtractionManifest:
	return TacticalExtractionManifestQuery.build_manifest(
		_state_store.state,
		_map_definition,
		_setup,
		zone_id
	)


func resolve(
		zone_id: StringName,
		expected_tactical_revision: int = -1
) -> OperationResult:
	if (
		_state_store == null
		or _map_definition == null
		or _setup == null
		or _campaign_store == null
	):
		return OperationResult.fail(
			&"mission_resolution_unconfigured",
			"Mission resolution is not configured."
		)
	if (
		expected_tactical_revision >= 0
		and _state_store.state.revision != expected_tactical_revision
	):
		return OperationResult.fail(
			&"extraction_preview_stale",
			(
				"The tactical state changed after the extraction preview. "
				+ "Review the refreshed manifest before confirming."
			)
		)
	var manifest: TacticalExtractionManifest = preview_manifest(zone_id)
	var manifest_errors: Array[String] = (
		TacticalExtractionManifestValidator.validate(
			manifest, _state_store.state
		)
	)
	if not manifest_errors.is_empty():
		return OperationResult.fail(
			&"extraction_manifest_integrity_failed",
			manifest_errors[0]
		)
	if manifest.mission_outcome == MissionOutcome.CAMPAIGN_DEFEAT:
		return _resolve_campaign_defeat(manifest)
	if manifest.mission_outcome == MissionOutcome.DEFEAT:
		return _resolve_tactical_defeat(manifest)
	if not manifest.extraction_is_legal:
		return OperationResult.fail(
			&"extraction_manifest_invalid",
			manifest.rejection_reasons[0]
			if not manifest.rejection_reasons.is_empty()
			else "Extraction is not legal."
		)

	var result_id := StringName(
		"result.%s.%d" % [_setup.mission_id, _setup.source_campaign_revision]
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		result_id,
		_setup,
		_state_store.state,
		manifest
	)
	_finalize_event_statistics(result)
	var basic_errors: Array[String] = result.validate_result()
	if not basic_errors.is_empty():
		return OperationResult.fail(&"mission_result_invalid", basic_errors[0])

	var lock_result: OperationResult = _commit_resolution_lock(result_id)
	if not lock_result.success:
		return lock_result
	var committed: OperationResult = _commit_service.commit_result(
		result, _setup, _catalogue
	)
	if not committed.success:
		_unlock_after_failed_commit()
		return committed

	_record_resolution_event(result, manifest)
	return OperationResult.ok(
		result,
		"%s committed exactly once."
		% MissionOutcome.display_name(result.mission_outcome)
	)


func current_campaign() -> CampaignState:
	if _campaign_store == null or not _campaign_store.has_method("current_campaign"):
		return null
	return _campaign_store.call("current_campaign") as CampaignState


func _resolve_tactical_defeat(
		manifest: TacticalExtractionManifest
) -> OperationResult:
	var result_id := StringName(
		"result.%s.%d.defeat"
		% [_setup.mission_id, _setup.source_campaign_revision]
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		result_id, _setup, _state_store.state, manifest
	)
	result.completed = true
	result.mission_outcome = MissionOutcome.DEFEAT
	result.successful = false
	_finalize_event_statistics(result)
	var basic_errors: Array[String] = result.validate_result()
	if not basic_errors.is_empty():
		return OperationResult.fail(&"mission_result_invalid", basic_errors[0])
	var lock_result: OperationResult = _commit_resolution_lock(result_id)
	if not lock_result.success:
		return lock_result
	var committed: OperationResult = _commit_service.commit_result(
		result, _setup, _catalogue
	)
	if not committed.success:
		_unlock_after_failed_commit()
		return committed
	_record_resolution_event(result, manifest)
	return OperationResult.ok(result, "Tactical defeat committed exactly once.")


func _resolve_campaign_defeat(
		manifest: TacticalExtractionManifest
) -> OperationResult:
	var result_id := StringName(
		"result.%s.%d.campaign_defeat"
		% [_setup.mission_id, _setup.source_campaign_revision]
	)
	var result: MissionResult = MissionResultBuilder.build_extraction_result(
		result_id, _setup, _state_store.state, manifest
	)
	result.completed = true
	result.mission_outcome = MissionOutcome.CAMPAIGN_DEFEAT
	result.successful = false
	_finalize_event_statistics(result)
	var basic_errors: Array[String] = result.validate_result()
	if not basic_errors.is_empty():
		return OperationResult.fail(&"mission_result_invalid", basic_errors[0])
	var lock_result: OperationResult = _commit_resolution_lock(result_id)
	if not lock_result.success:
		return lock_result
	# Campaign defeat intentionally does not overwrite the last safe campaign
	# save. The summary is returned from tactical state only.
	_record_resolution_event(result, manifest)
	return OperationResult.ok(result, "Campaign defeat resolved.")


func _finalize_event_statistics(result: MissionResult) -> void:
	if result == null:
		return
	var successful_first_aid: int = 0
	if _event_journal != null and _event_journal.has_method("events"):
		var raw_events: Variant = _event_journal.call("events", &"all", true)
		if raw_events is Array:
			for raw_event: Variant in raw_events as Array:
				if not raw_event is Dictionary:
					continue
				var event: Dictionary = raw_event as Dictionary
				if StringName(event.get("event_type", &"")) != &"first_aid":
					continue
				var raw_rolls: Variant = event.get("roll_records", [])
				if not raw_rolls is Array:
					continue
				for raw_roll: Variant in raw_rolls as Array:
					if (
						raw_roll is Dictionary
						and StringName((raw_roll as Dictionary).get("outcome", &""))
						== &"success"
					):
						successful_first_aid += 1
						break
	result.mission_statistics["allies_stabilised"] = successful_first_aid


func _commit_resolution_lock(result_id: StringName) -> OperationResult:
	var state: TacticalState = _state_store.state
	var changes := TacticalChangeSet.new(
		&"mission_resolution_locked", state.revision
	)
	changes.stage(
		func() -> bool:
			return state.lock_mission_resolution(result_id),
		func() -> void:
			state.unlock_mission_resolution_for_failed_commit(),
		"Mission resolution could not lock tactical commands.",
		&"mission_resolution_lock_failed"
	)
	return _state_store.commit(changes, _map_definition)


func _unlock_after_failed_commit() -> void:
	var state: TacticalState = _state_store.state
	var changes := TacticalChangeSet.new(
		&"mission_resolution_commit_failed", state.revision
	)
	changes.stage(
		func() -> bool:
			state.unlock_mission_resolution_for_failed_commit()
			return true,
		Callable(),
		"Mission resolution lock could not be released."
	)
	_state_store.commit(changes, _map_definition)


func _record_resolution_event(
		result: MissionResult,
		manifest: TacticalExtractionManifest
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	_event_journal.call(
		"record_event",
		&"mission_resolved",
		_state_store.state.phase_state.round_number,
		_state_store.state.phase_state.current_phase,
		"%s — %s."
		% [_setup.mission_display_name, MissionOutcome.display_name(result.mission_outcome)],
		{
			"category": &"events",
			"details": [
				"Extracted allies: %d" % (
					manifest.extracted_friendly_unit_ids.size()
					+ manifest.extracted_friendly_body_item_ids.size()
				),
				"Captives: %d" % manifest.captured_enemy_unit_ids.size(),
				"Recovered items: %d" % manifest.extracted_item_ids.size(),
			],
		}
	)
