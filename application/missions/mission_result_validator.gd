class_name MissionResultValidator
extends RefCounted


static func validate(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		campaign: CampaignState,
		catalogue: ContentCatalogue,
		authority_snapshot: MissionAuthoritySnapshot = null
) -> Array[String]:
	var errors: Array[String] = []
	if result == null:
		errors.append("Mission result is missing.")
		return errors
	errors.append_array(result.validate_result())
	if setup == null:
		errors.append("Mission result validation requires its MissionSetupSnapshot.")
		return errors
	if not setup.is_finalized():
		errors.append("Mission result validation requires a finalized setup snapshot.")
		return errors
	if campaign == null:
		errors.append("Mission result validation requires the current CampaignState.")
		return errors
	if catalogue == null:
		errors.append("Mission result validation requires the ContentCatalogue.")
		return errors

	_validate_identity_and_revision(result, setup, authority_snapshot, errors)
	var extracted_items: Dictionary = _validate_extracted_items(
		result,
		setup,
		campaign,
		catalogue,
		authority_snapshot,
		errors
	)
	_validate_outbound_lineage_conservation(setup, extracted_items, errors)
	_validate_item_outcomes(result, setup, extracted_items, errors)
	_validate_character_outcomes(result, setup, extracted_items, errors)
	if not result.extracted_zone_id.is_empty():
		errors.append_array(
			MissionExperienceAwardService.validate_awards(result, setup)
		)
	_validate_extracted_destinations(result, extracted_items, errors)
	_validate_generated_item_sources(result, setup, authority_snapshot, extracted_items, errors)
	_validate_extraction_semantics(result, setup, extracted_items, errors)
	return errors


static func _validate_identity_and_revision(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		authority_snapshot: MissionAuthoritySnapshot,
		errors: Array[String]
) -> void:
	if not setup.verify_integrity():
		errors.append("Mission setup integrity verification failed.")
	if result.mission_id != setup.mission_id:
		errors.append(
			"Mission result %s belongs to %s, not setup %s."
			% [result.result_id, result.mission_id, setup.mission_id]
		)
	if result.source_campaign_revision != setup.source_campaign_revision:
		errors.append(
			"Mission result source revision %d does not match setup revision %d."
			% [result.source_campaign_revision, setup.source_campaign_revision]
		)
	if result.source_setup_hash.is_empty():
		errors.append("Mission result source setup hash is missing.")
	elif result.source_setup_hash != setup.finalized_setup_hash():
		errors.append("Mission result source setup hash does not match its setup.")
	if authority_snapshot != null:
		if not authority_snapshot.verify_integrity():
			errors.append("Mission authority snapshot failed integrity verification.")
		elif authority_snapshot.mission_id != setup.mission_id:
			errors.append("Mission authority snapshot belongs to another mission.")
		elif authority_snapshot.source_setup_hash != setup.finalized_setup_hash():
			errors.append("Mission authority snapshot uses another setup hash.")


static func _validate_extracted_items(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		campaign: CampaignState,
		catalogue: ContentCatalogue,
		authority_snapshot: MissionAuthoritySnapshot,
		errors: Array[String]
) -> Dictionary:
	var extracted_items: Dictionary = {}
	for entry: Dictionary in result.extracted_item_entries:
		var item: CampaignItemState = CampaignItemState.from_dictionary(entry)
		if item.item_id.is_empty():
			continue
		extracted_items[item.item_id] = item

		var setup_item: CampaignItemState = setup.get_item(item.item_id)
		if setup_item == null:
			var lineage_origin: CampaignItemState = _outbound_lineage_origin(setup, item)
			if lineage_origin != null:
				_validate_split_outbound_item(item, lineage_origin, errors)
			else:
				if authority_snapshot == null:
					errors.append(
						"Extracted item %s was not part of setup %s and has no trusted mission authority snapshot."
						% [item.item_id, setup.mission_id]
					)
					continue
				var provenance: TacticalGeneratedItemProvenance = (
					authority_snapshot.provenance_for_item(item.item_id)
				)
				if provenance == null:
					errors.append(
						"Extracted generated item %s has no trusted provenance record."
						% item.item_id
					)
					continue
				if not result.generated_item_provenance_ids.has(provenance.provenance_id):
					errors.append(
						"Extracted generated item %s does not reference provenance %s."
						% [item.item_id, provenance.provenance_id]
					)
				if not provenance.validate_record().is_empty():
					errors.append("Generated item %s has invalid trusted provenance." % item.item_id)
				elif provenance.mission_id != setup.mission_id:
					errors.append("Generated item %s provenance belongs to another mission." % item.item_id)
				elif provenance.source_setup_hash != setup.finalized_setup_hash():
					errors.append("Generated item %s provenance uses another setup hash." % item.item_id)
				elif not provenance.matches_campaign_item(item):
					errors.append("Generated item %s does not match its trusted provenance values." % item.item_id)
		else:
			_validate_existing_item_conservation(item, setup_item, errors)

		if catalogue.item_definition(item.definition_id) == null:
			errors.append(
				"Extracted item %s references unknown definition %s."
				% [item.item_id, item.definition_id]
			)
		errors.append_array(
			CampaignItemValidator.validate_item(item, campaign, catalogue, false)
		)

		var existing: CampaignItemState = campaign.get_item(item.item_id)
		if existing == null:
			continue
		if setup.get_item(existing.item_id) == null:
			errors.append(
				"Mission result would overwrite unrelated campaign item %s."
				% item.item_id
			)
		elif existing.definition_id != item.definition_id:
			errors.append(
				"Mission result item %s conflicts with campaign definition %s."
				% [item.item_id, existing.definition_id]
			)
	return extracted_items


static func _validate_existing_item_conservation(
		item: CampaignItemState,
		setup_item: CampaignItemState,
		errors: Array[String]
) -> void:
	if setup_item.definition_id != item.definition_id:
		errors.append(
			"Extracted item %s changed definition from %s to %s."
			% [item.item_id, setup_item.definition_id, item.definition_id]
		)
	if item.quantity > setup_item.quantity:
		errors.append(
			(
				"Extracted item %s increased quantity from %d to %d "
				+ "without an authorised source."
			) % [item.item_id, setup_item.quantity, item.quantity]
		)
	if item.condition > setup_item.condition + 0.0001:
		errors.append(
			"Extracted item %s improved condition without an authorised effect."
			% item.item_id
		)
	if (
		_modifiers_without_mission_lineage(item.persistent_modifiers)
		!= _modifiers_without_mission_lineage(setup_item.persistent_modifiers)
	):
		errors.append(
			"Extracted item %s changed persistent modifiers without authorisation."
			% item.item_id
		)


static func _modifiers_without_mission_lineage(values: Dictionary) -> Dictionary:
	var result: Dictionary = values.duplicate(true)
	result.erase(TacticalCharacterDeploymentService.MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY)
	return result


static func _outbound_lineage_origin(
		setup: MissionSetupSnapshot,
		item: CampaignItemState
) -> CampaignItemState:
	if setup == null or item == null:
		return null
	var origin_id := StringName(item.persistent_modifiers.get(
		TacticalCharacterDeploymentService.MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY,
		""
	))
	if not origin_id.is_empty():
		var marked_origin: CampaignItemState = setup.get_item(origin_id)
		if marked_origin != null and _setup_item_belongs_to_deployed_player(setup, marked_origin):
			return marked_origin
	# Compatibility for results already saved before the marker existed. The
	# restraint splitter names its child from the original exact item ID.
	var item_id_text: String = String(item.item_id)
	for setup_item: CampaignItemState in setup.get_items():
		if not _setup_item_belongs_to_deployed_player(setup, setup_item):
			continue
		var origin_text: String = String(setup_item.item_id)
		if (
			item_id_text.begins_with("%s.attached." % origin_text)
			or item_id_text.begins_with("%s.split." % origin_text)
		):
			return setup_item
	return null


static func _setup_item_belongs_to_deployed_player(
		setup: MissionSetupSnapshot,
		item: CampaignItemState
) -> bool:
	if setup == null or item == null or item.location == null:
		return false
	var owner_id: StringName = item.location.owner_id
	return setup.player_unit_order().has(owner_id) and setup.was_deployed(owner_id)


static func _validate_split_outbound_item(
		item: CampaignItemState,
		origin: CampaignItemState,
		errors: Array[String]
) -> void:
	if item.definition_id != origin.definition_id:
		errors.append(
			"Split outbound item %s changed definition from its origin %s."
			% [item.item_id, origin.item_id]
		)
	if item.quantity < 1 or item.quantity > origin.quantity:
		errors.append(
			"Split outbound item %s has an impossible quantity for origin %s."
			% [item.item_id, origin.item_id]
		)
	if item.condition > origin.condition + 0.0001:
		errors.append(
			"Split outbound item %s improved condition without authorisation."
			% item.item_id
		)
	if (
		_modifiers_without_mission_lineage(item.persistent_modifiers)
		!= _modifiers_without_mission_lineage(origin.persistent_modifiers)
	):
		errors.append(
			"Split outbound item %s changed persistent modifiers without authorisation."
			% item.item_id
		)


static func _validate_outbound_lineage_conservation(
		setup: MissionSetupSnapshot,
		extracted_items: Dictionary,
		errors: Array[String]
) -> void:
	for setup_item: CampaignItemState in setup.get_items():
		if not _setup_item_belongs_to_deployed_player(setup, setup_item):
			continue
		var surviving_quantity: int = 0
		for raw_item: Variant in extracted_items.values():
			var extracted: CampaignItemState = raw_item as CampaignItemState
			if extracted == null:
				continue
			if extracted.item_id == setup_item.item_id:
				surviving_quantity += extracted.quantity
				continue
			var origin: CampaignItemState = _outbound_lineage_origin(setup, extracted)
			if origin != null and origin.item_id == setup_item.item_id:
				surviving_quantity += extracted.quantity
		if surviving_quantity > setup_item.quantity:
			errors.append(
				"Outbound item %s returned quantity %d from an original quantity of %d."
				% [setup_item.item_id, surviving_quantity, setup_item.quantity]
			)


static func _validate_item_outcomes(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		extracted_items: Dictionary,
		errors: Array[String]
) -> void:
	var deployed_ids: Dictionary = {}
	for character_id: StringName in setup.get_deployed_character_ids():
		deployed_ids[character_id] = true
	var expected_item_ids: Dictionary = {}
	for setup_item: CampaignItemState in setup.get_items():
		if (
			setup_item == null
			or setup_item.location == null
			or not deployed_ids.has(setup_item.location.owner_id)
		):
			continue
		expected_item_ids[setup_item.item_id] = true
		var outcome: Dictionary = result.item_outcome(setup_item.item_id)
		if outcome.is_empty():
			errors.append(
				"Mission result omits the post-mission outcome for deployment item %s."
				% setup_item.item_id
			)
			continue
		if StringName(outcome.get("definition_id", "")) != setup_item.definition_id:
			errors.append("Deployment item %s changed definition in its outcome record." % setup_item.item_id)
		if int(outcome.get("original_quantity", 0)) != setup_item.quantity:
			errors.append("Deployment item %s outcome changed its original quantity." % setup_item.item_id)
		var outcome_id := StringName(outcome.get("outcome", ""))
		var extracted: CampaignItemState = extracted_items.get(setup_item.item_id) as CampaignItemState
		if outcome_id in [&"consumed", &"lost", &"consumed_or_lost"]:
			if extracted != null:
				errors.append("Consumed or lost item %s was also extracted." % setup_item.item_id)
			continue
		if extracted == null:
			errors.append("Surviving deployment item %s was not extracted." % setup_item.item_id)
			continue
		if int(outcome.get("final_quantity", 0)) != extracted.quantity:
			errors.append("Deployment item %s outcome disagrees with its extracted quantity." % setup_item.item_id)
		if StringName(outcome.get("final_owner_id", "")) != extracted.location.owner_id:
			errors.append("Deployment item %s outcome disagrees with its final owner." % setup_item.item_id)
	for raw_item_id: Variant in result.item_outcomes_by_id.keys():
		var item_id := StringName(raw_item_id)
		if not expected_item_ids.has(item_id):
			errors.append("Mission result invents an outcome for non-deployment item %s." % item_id)


static func _validate_character_outcomes(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		extracted_items: Dictionary,
		errors: Array[String]
) -> void:
	var seen_character_results: Dictionary = {}
	for character_result: MissionCharacterResult in result.get_character_results():
		seen_character_results[character_result.character_id] = true
		var mission_character: PersistentCharacterState = setup.get_character(
			character_result.character_id
		)
		if mission_character == null:
			errors.append(
				"Mission result references character %s outside the setup."
				% character_result.character_id
			)
			continue

		var expected_deployed: bool = setup.was_deployed(
			character_result.character_id
		)
		if character_result.was_deployed != expected_deployed:
			errors.append(
				"Character %s deployment outcome disagrees with the participant manifest."
				% character_result.character_id
			)
		if not character_result.was_deployed:
			if character_result.xp_awarded != 0:
				errors.append(
					"Character %s received XP despite not being deployed."
					% character_result.character_id
				)
			if not character_result.injury_entries.is_empty():
				errors.append(
					"Character %s received injuries despite not being deployed."
					% character_result.character_id
				)
			if character_result.extracted:
				errors.append(
					"Character %s extracted despite not being deployed."
					% character_result.character_id
				)
			if not character_result.equipment_item_ids.is_empty():
				errors.append(
					"Character %s returned equipment despite not being deployed."
					% character_result.character_id
				)

		_validate_character_item_lists(
			character_result,
			extracted_items,
			errors
		)
		if character_result.was_deployed and not result.extracted_zone_id.is_empty():
			if character_result.completed_objective_ids != result.completed_objective_ids:
				errors.append(
					"Character %s completed-objective history disagrees with the mission result."
					% character_result.character_id
				)
			if character_result.failed_objective_ids != result.failed_objective_ids:
				errors.append(
					"Character %s failed-objective history disagrees with the mission result."
					% character_result.character_id
				)
			if character_result.history_entry.strip_edges().is_empty():
				errors.append(
					"Character %s has no persistent mission-history entry."
					% character_result.character_id
				)

	for character_id: StringName in setup.get_deployed_character_ids():
		if not seen_character_results.has(character_id):
			errors.append(
				"Mission result omits deployed participant %s." % character_id
			)


static func _validate_character_item_lists(
		character_result: MissionCharacterResult,
		extracted_items: Dictionary,
		errors: Array[String]
) -> void:
	var equipment_seen: Dictionary = {}
	for item_id: StringName in character_result.equipment_item_ids:
		if equipment_seen.has(item_id):
			errors.append(
				"Character %s duplicates equipment item %s."
				% [character_result.character_id, item_id]
			)
			continue
		equipment_seen[item_id] = true
		var extracted_item: CampaignItemState = (
			extracted_items.get(item_id) as CampaignItemState
		)
		if extracted_item == null:
			errors.append(
				"Character %s claims equipment %s that was not extracted."
				% [character_result.character_id, item_id]
			)
			continue
		if (
			extracted_item.location == null
			or not extracted_item.location.belongs_to_character(
				character_result.character_id
			)
		):
			errors.append(
				"Extracted item %s is not assigned to character %s."
				% [item_id, character_result.character_id]
			)

	for item_id: StringName in character_result.loot_item_ids:
		if not equipment_seen.has(item_id):
			errors.append(
				"Character %s lists loot %s outside their extracted equipment."
				% [character_result.character_id, item_id]
			)


static func _validate_extracted_destinations(
		result: MissionResult,
		extracted_items: Dictionary,
		errors: Array[String]
) -> void:
	for raw_item: Variant in extracted_items.values():
		var item: CampaignItemState = raw_item as CampaignItemState
		if item == null or item.location == null:
			continue
		if item.location.location_type in [
			CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT,
			CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY,
		]:
			var owner_result: MissionCharacterResult = result.get_character_result(
				item.location.owner_id
			)
			if owner_result == null or not owner_result.extracted:
				errors.append(
					"Item %s is assigned to a character who did not extract."
					% item.item_id
				)
		elif (
			item.location.location_type
			!= CampaignItemLocationState.LOCATION_STRONGHOLD_STORAGE
		):
			errors.append(
				"Extracted item %s has illegal campaign destination %s."
				% [item.item_id, item.location.location_type]
			)


static func _validate_generated_item_sources(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		authority_snapshot: MissionAuthoritySnapshot,
		extracted_items: Dictionary,
		errors: Array[String]
) -> void:
	if result.generated_item_provenance_ids.is_empty():
		return
	if authority_snapshot == null:
		errors.append("Mission result references generated items without a trusted authority snapshot.")
		return
	for provenance_id: StringName in result.generated_item_provenance_ids:
		var provenance: TacticalGeneratedItemProvenance = authority_snapshot.provenance(
			provenance_id
		)
		if provenance == null:
			errors.append("Mission result references unknown provenance %s." % provenance_id)
			continue
		if not extracted_items.has(provenance.generated_item_id):
			errors.append(
				"Provenance %s does not authorise an extracted generated item."
				% provenance_id
			)
		for source_id: StringName in provenance.source_item_ids:
			if setup.get_item(source_id) == null:
				errors.append(
					"Generated item %s cites unknown source item %s."
					% [provenance.generated_item_id, source_id]
				)


static func _validate_extraction_semantics(
		result: MissionResult,
		setup: MissionSetupSnapshot,
		extracted_items: Dictionary,
		errors: Array[String]
) -> void:
	if result.successful != (result.mission_outcome == MissionOutcome.VICTORY):
		errors.append("Mission successful flag disagrees with the mission outcome.")
	var uses_extraction_contract: bool = (
		not result.extracted_zone_id.is_empty()
		or not result.completed_objective_ids.is_empty()
		or not result.failed_objective_ids.is_empty()
		or not result.get_captive_results().is_empty()
	)
	if not uses_extraction_contract:
		return
	if setup.extraction_zone(result.extracted_zone_id) == null:
		errors.append(
			"Mission result references unknown extraction zone %s."
			% result.extracted_zone_id
		)
	if (
		result.mission_outcome in [MissionOutcome.VICTORY, MissionOutcome.WITHDRAWAL]
		and setup.requires_protagonist_extraction
		and not result.protagonist_extracted
	):
		errors.append("Mission result did not extract the required protagonist.")
	if result.mission_outcome == MissionOutcome.VICTORY:
		if not result.completed_objective_ids.has(setup.primary_objective_id):
			errors.append("Victory result did not complete the primary objective.")
	if result.mission_outcome == MissionOutcome.WITHDRAWAL:
		if not setup.allows_withdrawal:
			errors.append("Mission result withdraws from a mission that forbids it.")
		if not result.failed_objective_ids.has(setup.primary_objective_id):
			errors.append("Withdrawal result does not record the failed primary objective.")

	var seen_captive_ids: Dictionary = {}
	for captive: MissionCaptiveResult in result.get_captive_results():
		if seen_captive_ids.has(captive.character_id):
			errors.append("Mission result duplicates captive %s." % captive.character_id)
		seen_captive_ids[captive.character_id] = true
		var source: PersistentCharacterState = setup.get_character(captive.character_id)
		if source == null:
			errors.append("Captive %s was not part of the mission setup." % captive.character_id)
		elif source.template_id != captive.source_definition_id:
			errors.append("Captive %s changed source definition." % captive.character_id)
		var character_result: MissionCharacterResult = result.get_character_result(
			captive.character_id
		)
		if (
			character_result == null
			or not character_result.captured
			or character_result.outcome_state
			!= MissionCharacterResult.OUTCOME_CAPTURED_ENEMY
		):
			errors.append("Captive %s has no matching captured character result." % captive.character_id)
		if not extracted_items.has(captive.restraint_item_id):
			errors.append("Captive %s restraint was not extracted." % captive.character_id)
		for item_id: StringName in captive.equipment_item_ids:
			if not extracted_items.has(item_id):
				errors.append(
					"Captive %s references unextracted item %s."
					% [captive.character_id, item_id]
				)

