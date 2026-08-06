class_name MissionResultBuilder
extends RefCounted


static func build_result(
		result_id: StringName,
		setup: MissionSetupSnapshot,
		state: TacticalState,
		extracted_character_ids: Array[StringName],
		xp_by_character_id: Dictionary = {},
		injuries_by_character_id: Dictionary = {},
		extracted_ground_item_ids: Array[StringName] = [],
		successful: bool = true
) -> MissionResult:
	var result: MissionResult = MissionResult.new()
	result.result_id = result_id
	if setup == null or state == null or not setup.is_finalized():
		return result

	result.mission_id = setup.mission_id
	result.source_campaign_revision = setup.source_campaign_revision
	result.source_setup_hash = setup.finalized_setup_hash()
	result.completed = true
	result.successful = successful
	result.mission_outcome = (
		MissionOutcome.VICTORY if successful else MissionOutcome.DEFEAT
	)
	var extracted_item_ids: Dictionary = {}

	for mission_character: PersistentCharacterState in setup.get_characters():
		var character_result: MissionCharacterResult = MissionCharacterResult.new()
		character_result.character_id = mission_character.character_id
		var unit: TacticalUnitState = state.get_unit(mission_character.character_id)
		character_result.was_deployed = setup.was_deployed(
			mission_character.character_id
		)
		character_result.current_hp = unit.current_hp if unit != null else 0
		character_result.nonlethal_damage = unit.nonlethal_damage if unit != null else 0
		character_result.survived = (
			character_result.was_deployed
			and unit != null
			and not unit.is_dead()
		)
		if not character_result.was_deployed:
			character_result.outcome_state = MissionCharacterResult.OUTCOME_NOT_DEPLOYED
		elif character_result.survived:
			character_result.outcome_state = MissionCharacterResult.OUTCOME_ACTIVE
		else:
			character_result.outcome_state = MissionCharacterResult.OUTCOME_DEAD
		character_result.extracted = (
			character_result.survived
			and extracted_character_ids.has(mission_character.character_id)
		)
		character_result.xp_awarded = maxi(
			0,
			int(xp_by_character_id.get(mission_character.character_id, 0))
		)
		if character_result.xp_awarded > 0:
			character_result.xp_award_breakdown = [
				"Legacy mission award: %d XP" % character_result.xp_awarded,
			]
		character_result.injury_entries = _string_array(
			injuries_by_character_id.get(mission_character.character_id, [])
		)

		if character_result.extracted and unit != null:
			for tactical_item: TacticalItemInstanceState in _unit_items(
				state,
				unit.unit_id
			):
				character_result.equipment_item_ids.append(tactical_item.item_id)
				if not _is_outbound_tactical_item(setup, tactical_item):
					character_result.loot_item_ids.append(tactical_item.item_id)
				_append_extracted_item(
					result,
					extracted_item_ids,
					_campaign_item_from_tactical(
						tactical_item,
						CampaignItemLocationState.character_slot(
							mission_character.character_id,
							tactical_item.location.container_kind,
							tactical_item.location.grid_position
						)
					)
				)

		character_result.history_entry = _history_entry(
			setup.mission_id,
			character_result
		)
		result.add_character_result(character_result)

	for item_id: StringName in extracted_ground_item_ids:
		var item: TacticalItemInstanceState = state.get_item(item_id)
		if (
			item == null
			or item.location == null
			or item.location.location_type
			!= TacticalItemLocationState.LOCATION_TACTICAL_GROUND
		):
			continue
		_append_extracted_item(
			result,
			extracted_item_ids,
			_campaign_item_from_tactical(
				item,
				CampaignItemLocationState.stronghold_storage()
			)
		)

	_record_deployment_item_outcomes(result, setup, state)
	_bind_generated_item_authority(result, setup, state)
	return result


static func build_extraction_result(
		result_id: StringName,
		setup: MissionSetupSnapshot,
		state: TacticalState,
		manifest: TacticalExtractionManifest
) -> MissionResult:
	var result := MissionResult.new()
	result.result_id = result_id
	if (
		setup == null
		or state == null
		or manifest == null
		or not setup.is_finalized()
	):
		return result

	result.mission_id = setup.mission_id
	result.source_campaign_revision = setup.source_campaign_revision
	result.source_setup_hash = setup.finalized_setup_hash()
	result.completed = true
	result.mission_outcome = manifest.mission_outcome
	result.successful = manifest.mission_outcome == MissionOutcome.VICTORY
	result.extracted_zone_id = manifest.zone_id
	result.protagonist_extracted = manifest.protagonist_extracted
	result.abandoned_item_ids = manifest.abandoned_item_ids.duplicate()
	if manifest.required_objectives_complete:
		result.completed_objective_ids.append(setup.primary_objective_id)
	else:
		result.failed_objective_ids.append(setup.primary_objective_id)
	if (
		not setup.optional_captive_objective_id.is_empty()
		and not manifest.captured_enemy_unit_ids.is_empty()
	):
		result.optional_objective_ids.append(setup.optional_captive_objective_id)
	_apply_authored_objective_results(result, state, setup, manifest)
	result.summary_event_ids = [
		&"mission.extraction.confirmed",
		&"mission.result.committed",
	]
	result.mission_statistics = _mission_statistics(state, manifest)

	var extracted_item_ids: Dictionary = {}
	var campaign_destination_by_item_id: Dictionary = {}
	for item_id: StringName in manifest.extracted_item_ids:
		var tactical_item: TacticalItemInstanceState = state.get_item(item_id)
		if tactical_item == null or tactical_item.is_body():
			continue
		var destination: CampaignItemLocationState = _extraction_destination_for_item(
			tactical_item, state, manifest
		)
		var campaign_item: CampaignItemState = _campaign_item_from_tactical(
			tactical_item, destination
		)
		_append_extracted_item(result, extracted_item_ids, campaign_item)
		campaign_destination_by_item_id[item_id] = destination

	for mission_character: PersistentCharacterState in setup.get_characters():
		var character_result := MissionCharacterResult.new()
		character_result.character_id = mission_character.character_id
		character_result.was_deployed = setup.was_deployed(
			mission_character.character_id
		)
		var unit: TacticalUnitState = state.get_unit(mission_character.character_id)
		character_result.current_hp = unit.current_hp if unit != null else 0
		character_result.nonlethal_damage = unit.nonlethal_damage if unit != null else 0
		if not character_result.was_deployed:
			character_result.outcome_state = MissionCharacterResult.OUTCOME_NOT_DEPLOYED
			character_result.survived = true
			result.add_character_result(character_result)
			continue

		var body: TacticalItemInstanceState = (
			state.body_item_for_unit(mission_character.character_id)
		)
		var body_extracted: bool = (
			body != null and manifest.has_extracted_body_item(body.item_id)
		)
		var standing_extracted: bool = manifest.has_extracted_unit(
			mission_character.character_id
		)
		var captured: bool = manifest.captured_enemy_unit_ids.has(
			mission_character.character_id
		)
		character_result.extracted = standing_extracted or body_extracted or captured
		character_result.body_recovered = body_extracted or captured
		character_result.captured = captured

		if unit == null:
			character_result.survived = false
			character_result.outcome_state = MissionCharacterResult.OUTCOME_TEMPORARY_UNIT_REMOVED
		elif captured:
			character_result.survived = true
			character_result.outcome_state = MissionCharacterResult.OUTCOME_CAPTURED_ENEMY
		elif unit.is_dead():
			character_result.survived = false
			character_result.outcome_state = (
				MissionCharacterResult.OUTCOME_EXTRACTED_DEAD
				if body_extracted
				else MissionCharacterResult.OUTCOME_DEAD_UNRECOVERED
			)
		elif character_result.extracted:
			character_result.survived = true
			if unit.requires_body_item():
				character_result.outcome_state = MissionCharacterResult.OUTCOME_EXTRACTED_CRITICAL
			elif unit.current_hp < unit.maximum_hp or unit.nonlethal_damage > 0:
				character_result.outcome_state = MissionCharacterResult.OUTCOME_EXTRACTED_WOUNDED
			else:
				character_result.outcome_state = MissionCharacterResult.OUTCOME_EXTRACTED_READY
		else:
			character_result.survived = true
			character_result.outcome_state = (
				MissionCharacterResult.OUTCOME_TEMPORARY_UNIT_REMOVED
				if mission_character.persistence_scope == PersistentCharacterState.PERSISTENCE_MISSION
				else MissionCharacterResult.OUTCOME_ALIVE_UNRECOVERED
			)
			if (
				character_result.outcome_state
				== MissionCharacterResult.OUTCOME_ALIVE_UNRECOVERED
			):
				character_result.injury_entries.append("Missing / Unrecovered")

		if (
			character_result.extracted
			and character_result.survived
			and not character_result.captured
		):
			for item_id: StringName in manifest.extracted_item_ids:
				var destination: CampaignItemLocationState = (
					campaign_destination_by_item_id.get(item_id)
					as CampaignItemLocationState
				)
				if (
					destination == null
					or not destination.belongs_to_character(
						mission_character.character_id
					)
				):
					continue
				character_result.equipment_item_ids.append(item_id)
				var extracted_tactical_item: TacticalItemInstanceState = state.get_item(item_id)
				if not _is_outbound_tactical_item(setup, extracted_tactical_item):
					character_result.loot_item_ids.append(item_id)

		character_result.history_entry = _extraction_history_entry(
			setup.mission_id, character_result
		)
		result.add_character_result(character_result)

	for captive_unit_id: StringName in manifest.captured_enemy_unit_ids:
		var captive_unit: TacticalUnitState = state.get_unit(captive_unit_id)
		var source_character: PersistentCharacterState = setup.get_character(
			captive_unit_id
		)
		var captive_body: TacticalItemInstanceState = state.body_item_for_unit(
			captive_unit_id
		)
		if captive_unit == null or source_character == null or captive_body == null:
			continue
		var captive_result := MissionCaptiveResult.new()
		captive_result.character_id = captive_unit_id
		captive_result.source_definition_id = source_character.template_id
		captive_result.display_name = captive_unit.display_name
		captive_result.body_item_id = captive_body.item_id
		captive_result.restraint_item_id = captive_unit.restraint_item_id
		captive_result.condition_at_extraction = captive_unit.life_state_id()
		captive_result.current_hp = captive_unit.current_hp
		captive_result.maximum_hp = captive_unit.maximum_hp
		captive_result.nonlethal_damage = captive_unit.nonlethal_damage
		captive_result.faction_id = captive_unit.faction_id
		captive_result.captured_mission_id = setup.mission_id
		captive_result.captor_character_id = StringName(captive_unit.get("restraint_applied_by_unit_id"))
		for item_id: StringName in manifest.extracted_item_ids:
			var item: TacticalItemInstanceState = state.get_item(item_id)
			if item == null or item.location == null:
				continue
			if (
				item.location.owner_id == captive_unit_id
				and item_id != captive_result.restraint_item_id
			):
				captive_result.equipment_item_ids.append(item_id)
		result.add_captive_result(captive_result)

	_record_deployment_item_outcomes(result, setup, state)
	_bind_generated_item_authority(result, setup, state)
	return result


static func _is_outbound_tactical_item(
		setup: MissionSetupSnapshot,
		item: TacticalItemInstanceState
) -> bool:
	if setup == null or item == null:
		return false

	# MissionSetupSnapshot contains both the squad's immutable outbound loadout
	# and authored mission-ground items. Presence in the setup alone therefore
	# does not mean an item left the stronghold with the squad. Only items owned
	# by a deployed player character are outbound equipment. Authored grain,
	# furniture and other objective props remain newly acquired loot after they
	# are moved into a survivor's Backpack.
	if _setup_item_is_player_outbound(setup, setup.get_item(item.item_id)):
		return true
	var origin_item_id := StringName(item.tactical_modifiers.get(
		TacticalCharacterDeploymentService.MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY,
		""
	))
	if (
		not origin_item_id.is_empty()
		and _setup_item_is_player_outbound(setup, setup.get_item(origin_item_id))
	):
		return true
	var item_id_text: String = String(item.item_id)
	for setup_item: CampaignItemState in setup.get_items():
		if not _setup_item_is_player_outbound(setup, setup_item):
			continue
		var origin_text: String = String(setup_item.item_id)
		if (
			item_id_text.begins_with("%s.attached." % origin_text)
			or item_id_text.begins_with("%s.split." % origin_text)
		):
			return true
	return false


static func _setup_item_is_player_outbound(
		setup: MissionSetupSnapshot,
		item: CampaignItemState
) -> bool:
	if setup == null or item == null or item.location == null:
		return false
	if item.location.location_type not in [
		CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT,
		CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY,
	]:
		return false
	return setup.was_deployed(item.location.owner_id)


static func _record_deployment_item_outcomes(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		state: TacticalState
) -> void:
	if result == null or setup == null or state == null:
		return
	var extracted_by_id: Dictionary = {}
	for entry: Dictionary in result.extracted_item_entries:
		var item := CampaignItemState.from_dictionary(entry)
		if item != null and not item.item_id.is_empty():
			extracted_by_id[item.item_id] = item
	var deployed_ids: Dictionary = {}
	for character_id: StringName in setup.get_deployed_character_ids():
		deployed_ids[character_id] = true
	for setup_item: CampaignItemState in setup.get_items():
		if (
			setup_item == null
			or setup_item.location == null
			or not deployed_ids.has(setup_item.location.owner_id)
		):
			continue
		var final_item: CampaignItemState = extracted_by_id.get(setup_item.item_id) as CampaignItemState
		var tactical_item: TacticalItemInstanceState = state.get_item(setup_item.item_id)
		var outcome_id: StringName = &"consumed" if tactical_item == null else &"lost"
		var final_owner_id: StringName = &""
		var final_container_id: StringName = &""
		var final_quantity: int = 0
		if final_item != null and final_item.location != null:
			final_owner_id = final_item.location.owner_id
			final_container_id = final_item.location.container_id
			final_quantity = final_item.quantity
			if (
				final_item.location.belongs_to_character(setup_item.location.owner_id)
				and final_item.quantity == setup_item.quantity
			):
				outcome_id = &"returned"
			elif (
				final_item.location.belongs_to_character(setup_item.location.owner_id)
				and final_item.quantity < setup_item.quantity
			):
				outcome_id = &"partially_consumed"
			else:
				outcome_id = &"transferred"
		result.item_outcomes_by_id[setup_item.item_id] = {
			"item_id": String(setup_item.item_id),
			"definition_id": String(setup_item.definition_id),
			"original_owner_id": String(setup_item.location.owner_id),
			"original_container_id": String(setup_item.location.container_id),
			"original_grid_position": [
				setup_item.location.grid_position.x,
				setup_item.location.grid_position.y,
			],
			"original_is_rotated": setup_item.location.is_rotated,
			"original_quantity": setup_item.quantity,
			"outcome": String(outcome_id),
			"final_owner_id": String(final_owner_id),
			"final_container_id": String(final_container_id),
			"final_quantity": final_quantity,
		}


static func _bind_generated_item_authority(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		state: TacticalState
) -> void:
	if result == null or setup == null or state == null:
		return
	for entry: Dictionary in result.extracted_item_entries:
		var item_id := StringName(entry.get("item_id", ""))
		if item_id.is_empty() or setup.get_item(item_id) != null:
			continue
		var provenance := state.generated_item_provenance_for_item(item_id)
		if (
			provenance != null
			and not result.generated_item_provenance_ids.has(provenance.provenance_id)
		):
			result.generated_item_provenance_ids.append(provenance.provenance_id)


static func _apply_authored_objective_results(
		result: MissionResult,
		state: TacticalState,
		setup: MissionSetupSnapshot,
		manifest: TacticalExtractionManifest
) -> void:
	if result == null or state == null or setup == null or manifest == null:
		return
	var runtime: MissionRuntimeState = state.mission_runtime_state
	if runtime != null:
		result.completed_objective_ids.clear()
		result.failed_objective_ids.clear()
		result.optional_objective_ids.clear()
		for objective_state: MissionObjectiveState in runtime.objectives():
			result.objective_outcomes_by_id[objective_state.objective_id] = objective_state.to_dictionary()
			if objective_state.is_complete():
				result.completed_objective_ids.append(objective_state.objective_id)
				if objective_state.optional:
					result.optional_objective_ids.append(objective_state.objective_id)
			elif objective_state.is_failed():
				result.failed_objective_ids.append(objective_state.objective_id)
		result.notoriety_preview_lines = runtime.notoriety_preview_lines.duplicate()
		result.important_event_ids = runtime.important_event_ids.duplicate()
	_apply_terminal_primary_objective_outcome(result, setup, manifest, state.revision)


static func _apply_terminal_primary_objective_outcome(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		manifest: TacticalExtractionManifest,
		tactical_revision: int
) -> void:
	var primary_id: StringName = setup.primary_objective_id
	if primary_id.is_empty():
		return
	var outcome_data: Dictionary = {}
	var raw_outcome: Variant = result.objective_outcomes_by_id.get(primary_id, {})
	if raw_outcome is Dictionary:
		outcome_data = (raw_outcome as Dictionary).duplicate(true)
	outcome_data["objective_id"] = String(primary_id)
	outcome_data["optional"] = false

	if manifest.required_objectives_complete or result.mission_outcome == MissionOutcome.VICTORY:
		result.failed_objective_ids.erase(primary_id)
		if not result.completed_objective_ids.has(primary_id):
			result.completed_objective_ids.append(primary_id)
		outcome_data["status"] = String(MissionObjectiveState.STATUS_COMPLETED)
		outcome_data["failure_reason"] = ""
		if int(outcome_data.get("completion_revision", -1)) < 0:
			outcome_data["completion_revision"] = tactical_revision
	else:
		result.completed_objective_ids.erase(primary_id)
		if not result.failed_objective_ids.has(primary_id):
			result.failed_objective_ids.append(primary_id)
		outcome_data["status"] = String(MissionObjectiveState.STATUS_FAILED)
		outcome_data["failure_reason"] = (
			"The squad withdrew before completing the primary objective."
			if result.mission_outcome == MissionOutcome.WITHDRAWAL
			else "The mission ended before the primary objective was completed."
		)
		if int(outcome_data.get("failure_revision", -1)) < 0:
			outcome_data["failure_revision"] = tactical_revision
	result.objective_outcomes_by_id[primary_id] = outcome_data


static func _mission_statistics(
		state: TacticalState,
		manifest: TacticalExtractionManifest
) -> Dictionary:
	var enemies_killed: int = 0
	var enemies_incapacitated: int = 0
	for enemy: TacticalUnitState in state.get_enemy_units():
		if enemy == null or not enemy.counts_for_victory:
			continue
		if enemy.is_dead():
			enemies_killed += 1
		elif enemy.requires_body_item():
			enemies_incapacitated += 1
	return {
		"enemies_killed": enemies_killed,
		"enemies_incapacitated": enemies_incapacitated,
		"captives_taken": manifest.captured_enemy_unit_ids.size(),
		"allies_stabilised": 0,
		"allies_extracted": (
			manifest.extracted_friendly_unit_ids.size()
			+ manifest.extracted_friendly_body_item_ids.size()
		),
		"allies_abandoned": (
			manifest.abandoned_friendly_unit_ids.size()
			+ manifest.abandoned_friendly_body_item_ids.size()
		),
		"items_extracted": manifest.extracted_item_ids.size(),
		"items_abandoned": manifest.abandoned_item_ids.size(),
	}


static func _extraction_destination_for_item(
		item: TacticalItemInstanceState,
		state: TacticalState,
		manifest: TacticalExtractionManifest
) -> CampaignItemLocationState:
	if item == null or item.location == null:
		return CampaignItemLocationState.stronghold_storage()
	if item.location.location_type in [
		TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
		TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
	]:
		var owner: TacticalUnitState = state.get_unit(item.location.owner_id)
		if (
			owner != null
			and owner.team_id == &"player"
			and not owner.is_dead()
			and (
				manifest.has_extracted_unit(owner.unit_id)
				or _manifest_contains_linked_body(state, manifest, owner.unit_id)
			)
		):
			return CampaignItemLocationState.character_slot(
				owner.persistent_character_id,
				item.location.container_kind,
				item.location.grid_position
			)
	return CampaignItemLocationState.stronghold_storage()


static func _manifest_contains_linked_body(
		state: TacticalState,
		manifest: TacticalExtractionManifest,
		unit_id: StringName
) -> bool:
	var body: TacticalItemInstanceState = state.body_item_for_unit(unit_id)
	return body != null and manifest.has_extracted_body_item(body.item_id)


static func _extraction_history_entry(
		mission_id: StringName,
		character_result: MissionCharacterResult
) -> String:
	match character_result.outcome_state:
		MissionCharacterResult.OUTCOME_EXTRACTED_READY:
			return "Returned safely from mission %s." % mission_id
		MissionCharacterResult.OUTCOME_EXTRACTED_WOUNDED:
			return "Returned wounded from mission %s." % mission_id
		MissionCharacterResult.OUTCOME_EXTRACTED_CRITICAL:
			return "Was recovered in critical condition from mission %s." % mission_id
		MissionCharacterResult.OUTCOME_EXTRACTED_DEAD:
			return "Died during mission %s; body recovered." % mission_id
		MissionCharacterResult.OUTCOME_DEAD_UNRECOVERED:
			return "Died during mission %s; body unrecovered." % mission_id
		MissionCharacterResult.OUTCOME_ALIVE_UNRECOVERED:
			return "Was left behind during mission %s." % mission_id
		MissionCharacterResult.OUTCOME_CAPTURED_ENEMY:
			return "Was captured during mission %s." % mission_id
		_:
			return "Participated in mission %s." % mission_id


static func _unit_items(
		state: TacticalState,
		unit_id: StringName
) -> Array[TacticalItemInstanceState]:
	var result: Array[TacticalItemInstanceState] = []
	for item: TacticalItemInstanceState in state.get_items():
		if item.location == null or item.location.owner_id != unit_id:
			continue
		if item.location.location_type not in [
			TacticalItemLocationState.LOCATION_UNIT_EQUIPMENT,
			TacticalItemLocationState.LOCATION_UNIT_INVENTORY,
		]:
			continue
		result.append(item)
	result.sort_custom(
		func(a: TacticalItemInstanceState, b: TacticalItemInstanceState) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


static func _campaign_item_from_tactical(
		item: TacticalItemInstanceState,
		location: CampaignItemLocationState
) -> CampaignItemState:
	return CampaignItemState.new(
		item.item_id,
		item.definition_id,
		item.quantity,
		item.condition,
		location,
		item.tactical_modifiers
	)


static func _append_extracted_item(
		result: MissionResult,
		extracted_item_ids: Dictionary,
		item: CampaignItemState
) -> void:
	if item == null or item.item_id.is_empty() or extracted_item_ids.has(item.item_id):
		return
	result.extracted_item_entries.append(item.to_dictionary())
	extracted_item_ids[item.item_id] = true


static func _history_entry(
		mission_id: StringName,
		result: MissionCharacterResult
) -> String:
	if not result.was_deployed:
		return "Was not deployed to mission %s." % mission_id
	if not result.survived:
		return "Died during mission %s." % mission_id
	if result.extracted:
		return "Returned from mission %s." % mission_id
	return "Survived mission %s but did not extract." % mission_id


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value as Array
	for entry: Variant in values:
		result.append(String(entry))
	return result
