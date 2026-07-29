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
	result.completed = true
	result.successful = successful
	var extracted_item_ids: Dictionary = {}

	for mission_character: PersistentCharacterState in setup.get_characters():
		var character_result: MissionCharacterResult = MissionCharacterResult.new()
		character_result.character_id = mission_character.character_id
		var unit: TacticalUnitState = state.get_unit(mission_character.character_id)
		character_result.was_deployed = setup.was_deployed(
			mission_character.character_id
		)
		character_result.current_hp = unit.current_hp if unit != null else 0
		character_result.survived = (
			character_result.was_deployed
			and unit != null
			and unit.current_hp > 0
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
		character_result.injury_entries = _string_array(
			injuries_by_character_id.get(mission_character.character_id, [])
		)

		if character_result.extracted and unit != null:
			for tactical_item: TacticalItemInstanceState in _unit_items(
				state,
				unit.unit_id
			):
				character_result.equipment_item_ids.append(tactical_item.item_id)
				var setup_item: CampaignItemState = setup.get_item(
					tactical_item.item_id
				)
				if (
					setup_item == null
					or setup_item.location == null
					or not setup_item.location.belongs_to_character(
						mission_character.character_id
					)
				):
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

	return result


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
