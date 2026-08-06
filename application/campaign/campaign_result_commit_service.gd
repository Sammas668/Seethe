class_name CampaignResultCommitService
extends RefCounted

const CAMPAIGN_CHANGE_SET_SCRIPT: Script = preload(
	"res://application/campaign/transactions/campaign_change_set.gd"
)

var _state_store: RefCounted
var _catalogue: ContentCatalogue
var _captive_policy_registry := CaptivePolicyRegistry.new()


func _init() -> void:
	pass


func configure(
		state_store: RefCounted,
		catalogue: ContentCatalogue = null
) -> void:
	_state_store = state_store
	_catalogue = catalogue


func commit_envelope(
		envelope: MissionCommitEnvelope,
		catalogue_override: ContentCatalogue = null
) -> OperationResult:
	if envelope == null:
		return OperationResult.fail(
			&"mission_commit_envelope_missing",
			"A mission commit envelope is required."
		)
	var envelope_errors: Array[String] = envelope.validate_envelope()
	if not envelope_errors.is_empty():
		return OperationResult.fail(
			&"mission_commit_envelope_invalid",
			envelope_errors[0]
		)
	return commit_result(
		envelope.result,
		envelope.setup,
		catalogue_override,
		envelope.authority_snapshot
	)


func commit_result(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		catalogue_override: ContentCatalogue = null,
		authority_snapshot: MissionAuthoritySnapshot = null
) -> OperationResult:
	if result == null or setup == null or _state_store == null:
		return OperationResult.fail(
			&"mission_result_missing",
			"A mission result, finalized mission setup and campaign store are required."
		)
	if not setup.verify_integrity():
		return OperationResult.fail(
			&"mission_setup_integrity_failed",
			"Mission results cannot commit against a mutable or altered setup."
		)
	if result.source_setup_hash != setup.finalized_setup_hash():
		return OperationResult.fail(
			&"mission_result_setup_hash_mismatch",
			"Mission result does not match its finalized mission setup."
		)
	if not _state_store.has_method("current_campaign"):
		return OperationResult.fail(
			&"campaign_store_invalid",
			"The configured campaign store has no current campaign."
		)

	var campaign_value: Variant = _state_store.call("current_campaign")
	var campaign: CampaignState = campaign_value as CampaignState
	if campaign == null:
		return OperationResult.fail(
			&"campaign_state_missing",
			"No active campaign state is available."
		)

	var basic_errors: Array[String] = result.validate_result()
	if not basic_errors.is_empty():
		return OperationResult.fail(&"mission_result_invalid", basic_errors[0])

	if campaign.has_applied_result(result.result_id):
		return OperationResult.new(
			true,
			&"already_applied",
			"Mission result %s was already applied." % result.result_id,
			campaign
		)
	if campaign.has_resolved_mission(result.mission_id):
		return OperationResult.new(
			true,
			&"mission_already_resolved",
			"Mission %s was already resolved." % result.mission_id,
			campaign
		)

	# Strategic time, travel and other unrelated campaign activity may legitimately
	# advance the campaign revision while the immutable tactical mission is active.
	# Reject only an impossible rollback; setup integrity, active-mission hashes,
	# reservations and result provenance provide the relevant conflict protection.
	if campaign.revision < result.source_campaign_revision:
		return OperationResult.fail(
			&"campaign_revision_rollback",
			"Campaign revision %d predates mission %s setup revision %d."
			% [campaign.revision, result.mission_id, result.source_campaign_revision]
		)
	for provenance_id: StringName in result.generated_item_provenance_ids:
		if campaign.has_applied_generated_item_provenance(provenance_id):
			return OperationResult.fail(
				&"generated_item_provenance_already_applied",
				"Generated-item provenance %s was already consumed." % provenance_id
			)

	var catalogue: ContentCatalogue = (
		catalogue_override if catalogue_override != null else _catalogue
	)
	var validation_errors: Array[String] = MissionResultValidator.validate(
		result,
		setup,
		campaign,
		catalogue,
		authority_snapshot
	)
	if not validation_errors.is_empty():
		return OperationResult.fail(
			&"mission_result_context_invalid",
			validation_errors[0]
		)

	var changes: RefCounted = CAMPAIGN_CHANGE_SET_SCRIPT.new() as RefCounted
	changes.set("reason", &"mission_result_committed")
	changes.set("expected_revision", campaign.revision)
	changes.call(
		"stage",
		Callable(self, "_apply_result_to_candidate").bind(result)
	)
	var committed_value: Variant = _state_store.call("commit", changes)
	var committed: OperationResult = committed_value as OperationResult
	if committed == null:
		return OperationResult.fail(
			&"campaign_commit_invalid",
			"CampaignStateStore returned no OperationResult."
		)
	if committed.success:
		committed.message = "Mission result %s committed once." % result.result_id
	return committed


func _apply_result_to_candidate(
		candidate: CampaignState,
		result: MissionResult
) -> OperationResult:
	for provenance_id: StringName in result.generated_item_provenance_ids:
		if not candidate.mark_generated_item_provenance_applied(provenance_id):
			return OperationResult.fail(
				&"generated_item_provenance_apply_failed",
				"Generated-item provenance %s could not be consumed exactly once."
				% provenance_id
			)

	for character_result: MissionCharacterResult in result.get_character_results():
		var character: PersistentCharacterState = candidate.get_character(
			character_result.character_id
		)
		if character == null:
			continue
		if character.persistence_scope == PersistentCharacterState.PERSISTENCE_MISSION:
			continue
		_apply_character_progression(candidate, character, character_result)
		_reconcile_character_item_ownership(candidate, character_result)
		_restore_recovered_character_armour(candidate, character_result)

	var return_operation_id: StringName = &""
	var resolved_mission: ActiveMissionState = candidate.get_active_mission(result.mission_id)
	if resolved_mission != null and not resolved_mission.travel_operation_id.is_empty():
		return_operation_id = resolved_mission.travel_operation_id
	for entry: Dictionary in result.extracted_item_entries:
		var item: CampaignItemState = CampaignItemState.from_dictionary(entry)
		if item.item_id.is_empty() or item.definition_id.is_empty():
			return OperationResult.fail(
				&"mission_result_item_invalid",
				"An extracted mission item could not be restored to the campaign."
			)
		_restore_armour_condition(item)
		item.persistent_modifiers.erase(
			TacticalCharacterDeploymentService.MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY
		)
		if (
			not return_operation_id.is_empty()
			and item.location != null
			and item.location.is_stronghold_storage()
		):
			item.location = CampaignItemLocationState.return_transit(return_operation_id)
		candidate.upsert_item(item)

	var reservation_reconciled: OperationResult = _reconcile_return_reservation(
		candidate,
		result,
		return_operation_id
	)
	if not reservation_reconciled.success:
		return reservation_reconciled

	for captive_result: MissionCaptiveResult in result.get_captive_results():
		var captive := CampaignCaptiveState.new()
		captive.captive_id = StringName(
			"captive.%s.%s" % [result.mission_id, captive_result.character_id]
		)
		captive.source_character_id = captive_result.character_id
		captive.source_definition_id = captive_result.source_definition_id
		captive.display_name = captive_result.display_name
		captive.current_hp = captive_result.current_hp
		captive.maximum_hp = maxi(captive.current_hp, captive_result.maximum_hp)
		captive.nonlethal_damage = captive_result.nonlethal_damage
		captive.condition_ids = [
			captive_result.condition_at_extraction,
			&"restrained",
		]
		captive.equipment_item_ids = captive_result.equipment_item_ids.duplicate()
		captive.restraint_item_id = captive_result.restraint_item_id
		captive.captured_mission_id = result.mission_id
		captive.captor_character_id = captive_result.captor_character_id
		captive.capture_location_label = String(
			resolved_mission.site_id if resolved_mission != null else result.mission_id
		).replace("site.", "").replace("_", " ").capitalize()
		captive.source_region_id = candidate.current_region_id
		captive.captured_at_tick = candidate.campaign_tick
		captive.status = &"incoming"
		captive.holding_location_id = (
			StringName("return_transit.%s" % return_operation_id)
			if not return_operation_id.is_empty()
			else &"stronghold.awaiting_admission"
		)
		captive.faction_id = captive_result.faction_id
		var captive_template: CharacterTemplateDefinition = (
			_catalogue.character_template(captive.source_definition_id)
			if _catalogue != null
			else null
		)
		if captive_template != null:
			captive.troop_type_id = StringName(captive_template.troop_type.to_snake_case())
			captive.level = captive_template.base_level
			captive.identity_known = (
				not captive.display_name.strip_edges().is_empty()
				and captive.display_name.strip_edges().to_lower() != captive_template.display_name.strip_edges().to_lower()
			)
		else:
			captive.identity_known = not captive.display_name.strip_edges().is_empty()
		_captive_policy_registry.apply_to_captive(captive)
		captive.history_entries.append(
			"Captured during %s." % captive.capture_location_label
		)
		if not candidate.upsert_captive(captive):
			return OperationResult.fail(
				&"mission_captive_apply_failed",
				"Captive %s could not enter campaign holding." % captive.display_name
			)

	if not candidate.record_mission_result(result):
		return OperationResult.fail(
			&"mission_history_apply_failed",
			"Mission %s could not be recorded exactly once." % result.mission_id
		)

	if not candidate.mark_result_applied(result.result_id):
		return OperationResult.fail(
			&"mission_result_apply_failed",
			"The mission result could not be marked as applied."
		)
	if candidate.get_active_mission(result.mission_id) != null:
		if not candidate.mark_active_mission_resolved(
			result.mission_id, result.result_id
		):
			return OperationResult.fail(
				&"active_mission_resolution_failed",
				"The active mission could not be marked resolved."
			)
	if result.mission_outcome == MissionOutcome.CAMPAIGN_DEFEAT:
		candidate.campaign_status = CampaignStatus.DEFEATED
	var audit: OperationResult = _audit_candidate_against_result(
		candidate,
		result,
		return_operation_id
	)
	if not audit.success:
		return audit
	return OperationResult.ok(candidate, "Mission result applied to candidate.")


func _reconcile_return_reservation(
		campaign: CampaignState,
		result: MissionResult,
		return_operation_id: StringName
) -> OperationResult:
	if campaign == null or return_operation_id.is_empty():
		return OperationResult.ok([], "No active return reservation requires reconciliation.")
	var operation: SquadTravelOperationState = campaign.get_squad_travel_operation(
		return_operation_id
	)
	if operation == null:
		return OperationResult.fail(
			&"return_operation_missing",
			"The mission result has no matching squad return operation."
		)
	var squad_members: Dictionary = {}
	for character_id: StringName in operation.character_ids:
		squad_members[character_id] = true
	var returning_item_ids: Array[StringName] = []
	for raw_item: Variant in campaign.get_items():
		var item: CampaignItemState = raw_item as CampaignItemState
		if (
			item == null
			or item.location == null
			or not squad_members.has(item.location.owner_id)
			or item.location.location_type not in [
				CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT,
				CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY,
			]
		):
			continue
		returning_item_ids.append(item.item_id)
	returning_item_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	operation.reserved_item_ids = returning_item_ids.duplicate()
	operation.revision += 1
	if not operation.reservation_id.is_empty():
		var reservation: StrategicReservationState = campaign.get_strategic_reservation(
			operation.reservation_id
		)
		if reservation == null or not reservation.is_active():
			return OperationResult.fail(
				&"return_reservation_missing",
				"The squad return operation has no active deployment reservation."
			)
		reservation.item_ids = returning_item_ids.duplicate()
		reservation.revision += 1
	campaign.revision += 1
	return OperationResult.ok(
		returning_item_ids,
		"Deployment reservation reconciled with the exact post-mission inventory."
	)


func _apply_character_progression(
		campaign: CampaignState,
		character: PersistentCharacterState,
		result: MissionCharacterResult
) -> void:
	if result.was_deployed:
		character.deployment_count += 1
		character.revision += 1
		var maximum_hp: int = _resolved_character_maximum_hp(campaign, character)
		character.set_persistent_health(
			result.current_hp,
			result.nonlethal_damage,
			maximum_hp
		)
	if result.xp_awarded > 0 and result.survived and result.extracted and not result.captured:
		character.award_xp(result.xp_awarded)
	for injury: String in result.injury_entries:
		if not character.injury_entries.has(injury):
			character.add_injury(injury)
	if not result.survived:
		character.is_dead = true
		character.revision += 1
	if not result.history_entry.strip_edges().is_empty():
		character.add_history(result.history_entry)


func _resolved_character_maximum_hp(
		campaign: CampaignState,
		character: PersistentCharacterState
) -> int:
	if character == null or _catalogue == null:
		return 1
	var service := CharacterResolutionService.new()
	service.configure(_catalogue)
	var items: Array = campaign.items_for_character(character.character_id) if campaign != null else []
	var snapshot: ResolvedCharacterSnapshot = service.resolve_character(character, [], items)
	return maxi(1, snapshot.stat_value(&"maximum_hp", 1))


func _reconcile_character_item_ownership(
		campaign: CampaignState,
		result: MissionCharacterResult
) -> void:
	if not result.was_deployed:
		return
	var retained_ids: Dictionary = {}
	if result.survived and result.extracted:
		for item_id: StringName in result.equipment_item_ids:
			retained_ids[item_id] = true
	for existing_item: CampaignItemState in campaign.items_for_character(
		result.character_id
	):
		if retained_ids.has(existing_item.item_id):
			continue
		campaign.remove_item(existing_item.item_id)

func _restore_recovered_character_armour(
		campaign: CampaignState,
		result: MissionCharacterResult
) -> void:
	if campaign == null or not result.survived or not result.extracted:
		return
	for item: CampaignItemState in campaign.items_for_character(result.character_id):
		if not result.equipment_item_ids.has(item.item_id):
			continue
		_restore_armour_condition(item)


func _restore_armour_condition(item: CampaignItemState) -> void:
	if item == null or _catalogue == null:
		return
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
	if (
		definition == null
		or (
			not definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
			and definition.defence_profile_id.is_empty()
		)
	):
		return
	if not is_equal_approx(item.condition, 1.0):
		item.condition = 1.0
		item.revision += 1


func _audit_candidate_against_result(
		candidate: CampaignState,
		result: MissionResult,
		return_operation_id: StringName
) -> OperationResult:
	if candidate == null or result == null:
		return OperationResult.fail(
			&"mission_commit_audit_missing",
			"The mission candidate audit has no campaign or result."
		)
	for character_result: MissionCharacterResult in result.get_character_results():
		var character: PersistentCharacterState = candidate.get_character(
			character_result.character_id
		)
		if character == null or character.persistence_scope == PersistentCharacterState.PERSISTENCE_MISSION:
			continue
		if character_result.is_dead_outcome() and not character.is_dead:
			return OperationResult.fail(
				&"mission_commit_death_audit_failed",
				"%s was not permanently marked dead." % character.display_name
			)
		if (
			character_result.outcome_state == MissionCharacterResult.OUTCOME_ALIVE_UNRECOVERED
			and not character.is_missing_or_unrecovered()
		):
			return OperationResult.fail(
				&"mission_commit_missing_audit_failed",
				"%s was not marked missing after being left behind."
				% character.display_name
			)
		if (
			not character_result.history_entry.strip_edges().is_empty()
			and not character.history_entries.has(character_result.history_entry)
		):
			return OperationResult.fail(
				&"mission_commit_history_audit_failed",
				"%s did not receive the immutable mission-history entry."
				% character.display_name
			)

	for entry: Dictionary in result.extracted_item_entries:
		var expected: CampaignItemState = CampaignItemState.from_dictionary(entry)
		if expected == null:
			return OperationResult.fail(
				&"mission_commit_item_audit_failed",
				"An extracted item could not be audited."
			)
		_restore_armour_condition(expected)
		expected.persistent_modifiers.erase(
			TacticalCharacterDeploymentService.MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY
		)
		if (
			not return_operation_id.is_empty()
			and expected.location != null
			and expected.location.is_stronghold_storage()
		):
			expected.location = CampaignItemLocationState.return_transit(
				return_operation_id
			)
		var actual: CampaignItemState = candidate.get_item(expected.item_id)
		if actual == null:
			return OperationResult.fail(
				&"mission_commit_item_audit_failed",
				"Extracted item %s is missing from the candidate campaign."
				% expected.item_id
			)
		if (
			actual.definition_id != expected.definition_id
			or actual.quantity != expected.quantity
			or not is_equal_approx(actual.condition, expected.condition)
			or actual.location == null
			or expected.location == null
			or actual.location.to_dictionary() != expected.location.to_dictionary()
		):
			return OperationResult.fail(
				&"mission_commit_item_audit_failed",
				"Extracted item %s does not match its committed identity, quantity or location."
				% expected.item_id
			)

	for raw_item_id: Variant in result.item_outcomes_by_id.keys():
		var item_id := StringName(raw_item_id)
		var outcome: Dictionary = result.item_outcome(item_id)
		if (
			StringName(outcome.get("outcome", "")) in [
				&"consumed",
				&"lost",
				&"consumed_or_lost",
			]
			and candidate.get_item(item_id) != null
		):
			return OperationResult.fail(
				&"mission_commit_lost_item_audit_failed",
				"Lost or consumed item %s still exists in the candidate campaign."
				% item_id
			)

	for captive_result: MissionCaptiveResult in result.get_captive_results():
		var captive_id := StringName(
			"captive.%s.%s" % [result.mission_id, captive_result.character_id]
		)
		if candidate.get_captive(captive_id) == null:
			return OperationResult.fail(
				&"mission_commit_captive_audit_failed",
				"Selected captive %s was not committed with the mission cargo."
				% captive_result.display_name
			)

	if not candidate.has_applied_result(result.result_id):
		return OperationResult.fail(
			&"mission_commit_result_audit_failed",
			"The result ID was not recorded on the candidate campaign."
		)
	if not candidate.has_resolved_mission(result.mission_id):
		return OperationResult.fail(
			&"mission_commit_resolution_audit_failed",
			"The mission was not marked resolved on the candidate campaign."
		)
	return OperationResult.ok(candidate, "Mission candidate passed lifecycle audit.")

