class_name MissionSetupSnapshot
extends RefCounted

var _mission_id: StringName = &""
var mission_id: StringName:
	get:
		return _mission_id

var _mission_definition_id: StringName = &""
var mission_definition_id: StringName:
	get:
		return _mission_definition_id

var _tactical_map_definition_id: StringName = &""
var tactical_map_definition_id: StringName:
	get:
		return _tactical_map_definition_id

var _mission_display_name: String = "Tactical Mission"
var mission_display_name: String:
	get:
		return _mission_display_name

var _protagonist_character_id: StringName = &""
var protagonist_character_id: StringName:
	get:
		return _protagonist_character_id

var _primary_objective_id: StringName = &"objective.primary"
var primary_objective_id: StringName:
	get:
		return _primary_objective_id

var _primary_objective_text: String = "Complete the mission objective."
var primary_objective_text: String:
	get:
		return _primary_objective_text

var _optional_captive_objective_id: StringName = &""
var optional_captive_objective_id: StringName:
	get:
		return _optional_captive_objective_id

var _optional_captive_objective_text: String = ""
var optional_captive_objective_text: String:
	get:
		return _optional_captive_objective_text

var _allows_withdrawal: bool = true
var allows_withdrawal: bool:
	get:
		return _allows_withdrawal

var _requires_protagonist_extraction: bool = true
var requires_protagonist_extraction: bool:
	get:
		return _requires_protagonist_extraction

var _source_campaign_revision: int = 0
var source_campaign_revision: int:
	get:
		return _source_campaign_revision
var source_roster_revision: int:
	get:
		return _source_campaign_revision

var _characters_by_id: Dictionary = {}
var _items_by_id: Dictionary = {}
var _player_unit_order: Array[StringName] = []
var _deployed_character_ids: Array[StringName] = []
var _extraction_zone_definitions_by_id: Dictionary = {}
var _objective_definitions_by_id: Dictionary = {}
var _primary_objective_ids: Array[StringName] = []
var _optional_objective_ids: Array[StringName] = []
var _finalized: bool = false
var _finalized_setup_hash: String = ""


func configure_identity(
		mission_id_value: StringName,
		source_campaign_revision_value: int
) -> bool:
	if _finalized or mission_id_value.is_empty() or source_campaign_revision_value < 0:
		return false
	_mission_id = mission_id_value
	_source_campaign_revision = source_campaign_revision_value
	return true


func configure_authored_mission(
		definition: MissionDefinition,
		protagonist_id: StringName
) -> bool:
	if _finalized or definition == null or definition.map_definition == null:
		return false
	var definition_errors: Array[String] = definition.validate_definition()
	if not definition_errors.is_empty():
		return false
	_mission_definition_id = definition.mission_definition_id
	_tactical_map_definition_id = definition.map_definition.definition_id
	_mission_display_name = definition.display_name
	_protagonist_character_id = protagonist_id
	_objective_definitions_by_id.clear()
	_primary_objective_ids.clear()
	_optional_objective_ids.clear()
	for objective: MissionObjectiveDefinition in definition.primary_objectives:
		if objective == null:
			continue
		var isolated := MissionObjectiveDefinition.from_dictionary(objective.to_dictionary())
		_objective_definitions_by_id[isolated.objective_id] = isolated
		_primary_objective_ids.append(isolated.objective_id)
	for objective: MissionObjectiveDefinition in definition.optional_objectives:
		if objective == null:
			continue
		var isolated := MissionObjectiveDefinition.from_dictionary(objective.to_dictionary())
		_objective_definitions_by_id[isolated.objective_id] = isolated
		_optional_objective_ids.append(isolated.objective_id)
	if not _primary_objective_ids.is_empty():
		var primary := objective_definition(_primary_objective_ids[0])
		_primary_objective_id = primary.objective_id
		_primary_objective_text = primary.display_name
	_optional_captive_objective_id = &""
	_optional_captive_objective_text = ""
	for objective_id: StringName in _optional_objective_ids:
		var optional_objective := objective_definition(objective_id)
		if optional_objective != null and optional_objective.objective_kind == MissionObjectiveDefinition.KIND_EXTRACT_CAPTIVE:
			_optional_captive_objective_id = optional_objective.objective_id
			_optional_captive_objective_text = optional_objective.display_name
			break
	_allows_withdrawal = true
	_requires_protagonist_extraction = true
	_extraction_zone_definitions_by_id.clear()
	for zone: TacticalExtractionZoneDefinition in definition.map_definition.extraction_zones:
		if zone == null or zone.zone_id.is_empty():
			continue
		_extraction_zone_definitions_by_id[zone.zone_id] = TacticalExtractionZoneDefinition.from_dictionary(zone.to_dictionary())
	return true


func objective_definition(objective_id: StringName) -> MissionObjectiveDefinition:
	var definition := _objective_definitions_by_id.get(objective_id) as MissionObjectiveDefinition
	return MissionObjectiveDefinition.from_dictionary(definition.to_dictionary()) if definition != null else null


func objective_definitions() -> Array[MissionObjectiveDefinition]:
	var result: Array[MissionObjectiveDefinition] = []
	for raw_definition: Variant in _objective_definitions_by_id.values():
		var definition := raw_definition as MissionObjectiveDefinition
		if definition != null:
			result.append(MissionObjectiveDefinition.from_dictionary(definition.to_dictionary()))
	result.sort_custom(func(a: MissionObjectiveDefinition, b: MissionObjectiveDefinition) -> bool: return String(a.objective_id) < String(b.objective_id))
	return result


func primary_objective_ids() -> Array[StringName]:
	return _primary_objective_ids.duplicate()


func optional_objective_ids() -> Array[StringName]:
	return _optional_objective_ids.duplicate()


func configure_mission_definition(
		map_definition: TacticalMapDefinition,
		protagonist_id: StringName
) -> bool:
	if _finalized or map_definition == null:
		return false
	_mission_display_name = map_definition.mission_display_name
	_protagonist_character_id = protagonist_id
	_primary_objective_id = map_definition.primary_objective_id
	_primary_objective_text = map_definition.primary_objective_text
	_optional_captive_objective_id = map_definition.optional_captive_objective_id
	_optional_captive_objective_text = map_definition.optional_captive_objective_text
	_allows_withdrawal = map_definition.allows_withdrawal
	_requires_protagonist_extraction = map_definition.requires_protagonist_extraction
	_extraction_zone_definitions_by_id.clear()
	for zone: TacticalExtractionZoneDefinition in map_definition.extraction_zones:
		if zone == null or zone.zone_id.is_empty():
			continue
		_extraction_zone_definitions_by_id[zone.zone_id] = (
			TacticalExtractionZoneDefinition.from_dictionary(zone.to_dictionary())
		)
	return true


func extraction_zone(zone_id: StringName) -> TacticalExtractionZoneDefinition:
	var zone: TacticalExtractionZoneDefinition = (
		_extraction_zone_definitions_by_id.get(zone_id)
		as TacticalExtractionZoneDefinition
	)
	if zone == null:
		return null
	return TacticalExtractionZoneDefinition.from_dictionary(zone.to_dictionary())


func extraction_zones() -> Array[TacticalExtractionZoneDefinition]:
	var result: Array[TacticalExtractionZoneDefinition] = []
	for raw_zone: Variant in _extraction_zone_definitions_by_id.values():
		var zone: TacticalExtractionZoneDefinition = raw_zone as TacticalExtractionZoneDefinition
		if zone != null:
			result.append(TacticalExtractionZoneDefinition.from_dictionary(zone.to_dictionary()))
	result.sort_custom(
		func(a: TacticalExtractionZoneDefinition, b: TacticalExtractionZoneDefinition) -> bool:
			return String(a.zone_id) < String(b.zone_id)
	)
	return result


func is_finalized() -> bool:
	return _finalized


func finalized_setup_hash() -> String:
	return _finalized_setup_hash


func verify_integrity() -> bool:
	return (
		_finalized
		and _finalized_setup_hash.length() == 64
		and CanonicalDataHasher.sha256_hex(_canonical_dictionary())
		== _finalized_setup_hash
	)


func add_character_copy(character: PersistentCharacterState) -> bool:
	if _finalized:
		return false
	if character == null or character.character_id.is_empty():
		return false
	if _characters_by_id.has(character.character_id):
		return false
	var isolated: PersistentCharacterState = PersistentCharacterState.from_dictionary(
		character.to_dictionary()
	)
	_characters_by_id[isolated.character_id] = isolated
	return true


func add_isolated_character(
		character: PersistentCharacterState,
		item_states: Array = []
) -> bool:
	if _finalized or not add_character_copy(character):
		return false
	for value: Variant in item_states:
		var item: CampaignItemState = value as CampaignItemState
		if item == null:
			continue
		var isolated_item: CampaignItemState = item.clone()
		isolated_item.item_id = unique_item_id(isolated_item.item_id)
		_items_by_id[isolated_item.item_id] = isolated_item
	return true


func add_item_copy(item: CampaignItemState) -> bool:
	if _finalized:
		return false
	if item == null or item.item_id.is_empty():
		return false
	if _items_by_id.has(item.item_id):
		return false
	_items_by_id[item.item_id] = item.clone()
	return true


func append_player_unit(character_id: StringName) -> bool:
	if _finalized or character_id.is_empty():
		return false
	if get_character(character_id) == null:
		return false
	if not _player_unit_order.has(character_id):
		_player_unit_order.append(character_id)
	return true


func player_unit_order() -> Array[StringName]:
	return _player_unit_order.duplicate()


func mark_deployed(character_id: StringName) -> bool:
	if _finalized:
		return false
	if character_id.is_empty() or _character_reference(character_id) == null:
		return false
	if not _deployed_character_ids.has(character_id):
		_deployed_character_ids.append(character_id)
	return true


func was_deployed(character_id: StringName) -> bool:
	return _deployed_character_ids.has(character_id)


func get_deployed_character_ids() -> Array[StringName]:
	var result: Array[StringName] = _deployed_character_ids.duplicate()
	result.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	return result


func finalize() -> Array[String]:
	if _finalized:
		return []
	var errors: Array[String] = validate_snapshot(false)
	if not errors.is_empty():
		return errors
	var computed_hash: String = CanonicalDataHasher.sha256_hex(_canonical_dictionary())
	if computed_hash.length() != 64:
		return ["MissionSetupSnapshot could not generate a canonical SHA-256 hash."]
	_finalized_setup_hash = computed_hash
	_finalized = true
	return []


func get_character(character_id: StringName) -> PersistentCharacterState:
	var character: PersistentCharacterState = _character_reference(character_id)
	if character == null:
		return null
	return (
		PersistentCharacterState.from_dictionary(character.to_dictionary())
		if _finalized
		else character
	)


func get_characters() -> Array[PersistentCharacterState]:
	var result: Array[PersistentCharacterState] = []
	for value: Variant in _characters_by_id.values():
		var character: PersistentCharacterState = value as PersistentCharacterState
		if character == null:
			continue
		result.append(
			PersistentCharacterState.from_dictionary(character.to_dictionary())
			if _finalized
			else character
		)
	result.sort_custom(
		func(a: PersistentCharacterState, b: PersistentCharacterState) -> bool:
			return String(a.character_id) < String(b.character_id)
	)
	return result


func get_item(item_id: StringName) -> CampaignItemState:
	var item: CampaignItemState = _item_reference(item_id)
	if item == null:
		return null
	return item.clone() if _finalized else item


func get_items() -> Array[CampaignItemState]:
	var result: Array[CampaignItemState] = []
	for value: Variant in _items_by_id.values():
		var item: CampaignItemState = value as CampaignItemState
		if item != null:
			result.append(item.clone() if _finalized else item)
	result.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


func items_for_character(character_id: StringName) -> Array[CampaignItemState]:
	var result: Array[CampaignItemState] = []
	for value: Variant in _items_by_id.values():
		var item: CampaignItemState = value as CampaignItemState
		if (
			item != null
			and item.location != null
			and item.location.belongs_to_character(character_id)
		):
			result.append(item.clone() if _finalized else item)
	result.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


func mission_ground_items() -> Array[CampaignItemState]:
	var result: Array[CampaignItemState] = []
	for value: Variant in _items_by_id.values():
		var item: CampaignItemState = value as CampaignItemState
		if (
			item != null
			and item.location != null
			and item.location.location_type
			== CampaignItemLocationState.LOCATION_MISSION_GROUND
		):
			result.append(item.clone() if _finalized else item)
	result.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


func add_ground_item(
		preferred_instance_id: StringName,
		definition_id: StringName,
		map_position: Vector2i,
		quantity: int = 1,
		condition: float = 1.0,
		source_label: String = "Ground"
) -> StringName:
	if _finalized or definition_id.is_empty():
		return &""
	var instance_id: StringName = unique_item_id(preferred_instance_id)
	var item: CampaignItemState = CampaignItemState.new(
		instance_id,
		definition_id,
		quantity,
		condition,
		CampaignItemLocationState.mission_ground(map_position, source_label)
	)
	_items_by_id[instance_id] = item
	return instance_id


func unique_item_id(preferred_instance_id: StringName) -> StringName:
	var base_text: String = String(preferred_instance_id)
	if base_text.is_empty():
		base_text = "%s.item" % String(mission_id)
	var candidate: StringName = StringName(base_text)
	if not _items_by_id.has(candidate):
		return candidate
	var suffix: int = 1
	candidate = StringName("%s.mission.%03d" % [base_text, suffix])
	while _items_by_id.has(candidate):
		suffix += 1
		candidate = StringName("%s.mission.%03d" % [base_text, suffix])
	return candidate


func all_item_ids() -> Dictionary:
	var result: Dictionary = {}
	for item_id: Variant in _items_by_id.keys():
		result[StringName(item_id)] = true
	return result


func validate_snapshot(require_finalized: bool = true) -> Array[String]:
	var errors: Array[String] = []
	if require_finalized and not _finalized:
		errors.append("MissionSetupSnapshot has not been finalized.")
	if _finalized and not verify_integrity():
		errors.append("MissionSetupSnapshot integrity hash does not match its canonical content.")
	if mission_id.is_empty():
		errors.append("MissionSetupSnapshot has no mission ID.")
	if not _mission_definition_id.is_empty() and _tactical_map_definition_id.is_empty():
		errors.append("Authored MissionSetupSnapshot has no tactical map definition ID.")
	for objective: MissionObjectiveDefinition in objective_definitions():
		errors.append_array(objective.validate_definition())
	if mission_display_name.strip_edges().is_empty():
		errors.append("MissionSetupSnapshot has no mission display name.")
	if primary_objective_id.is_empty():
		errors.append("MissionSetupSnapshot has no primary objective ID.")
	if requires_protagonist_extraction and protagonist_character_id.is_empty():
		errors.append("MissionSetupSnapshot requires a protagonist but has no protagonist ID.")
	if not protagonist_character_id.is_empty() and _character_reference(protagonist_character_id) == null:
		errors.append("MissionSetupSnapshot protagonist %s is missing." % protagonist_character_id)
	if _extraction_zone_definitions_by_id.is_empty():
		errors.append("MissionSetupSnapshot has no extraction zones.")
	for zone: TacticalExtractionZoneDefinition in extraction_zones():
		errors.append_array(zone.validate_definition())

	for value: Variant in _characters_by_id.values():
		var character: PersistentCharacterState = value as PersistentCharacterState
		if character == null or character.character_id.is_empty():
			errors.append("Mission setup contains a character with no ID.")

	for value: Variant in _items_by_id.values():
		var item: CampaignItemState = value as CampaignItemState
		if item == null:
			errors.append("Mission setup contains a missing item.")
			continue
		errors.append_array(item.validate_state())
		if (
			item.location != null
			and item.location.location_type in [
				CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT,
				CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY,
			]
			and _character_reference(item.location.owner_id) == null
		):
			errors.append(
				"Mission item %s references missing character %s."
				% [item.item_id, item.location.owner_id]
			)

	for character_id: StringName in _player_unit_order:
		var character: PersistentCharacterState = _character_reference(character_id)
		if character == null:
			errors.append(
				"Player unit order references missing mission character %s."
				% character_id
			)
		elif character.team_id != &"player":
			errors.append(
				"Player unit order contains non-player character %s."
				% character_id
			)

	var seen_deployed: Dictionary = {}
	for character_id: StringName in _deployed_character_ids:
		if seen_deployed.has(character_id):
			errors.append("Mission setup duplicates deployed character %s." % character_id)
			continue
		seen_deployed[character_id] = true
		if _character_reference(character_id) == null:
			errors.append(
				"Deployed participant manifest references missing character %s."
				% character_id
			)
	return errors


func _character_reference(character_id: StringName) -> PersistentCharacterState:
	return _characters_by_id.get(character_id) as PersistentCharacterState


func _item_reference(item_id: StringName) -> CampaignItemState:
	return _items_by_id.get(item_id) as CampaignItemState


func _canonical_dictionary() -> Dictionary:
	var characters: Array[Dictionary] = []
	for value: Variant in _characters_by_id.values():
		var character: PersistentCharacterState = value as PersistentCharacterState
		if character != null:
			characters.append(character.to_dictionary())
	characters.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("character_id", "")) < String(b.get("character_id", ""))
	)
	var items: Array[Dictionary] = []
	for value: Variant in _items_by_id.values():
		var item: CampaignItemState = value as CampaignItemState
		if item != null:
			items.append(item.to_dictionary())
	items.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("item_id", "")) < String(b.get("item_id", ""))
	)
	var zones: Array[Dictionary] = []
	for zone: TacticalExtractionZoneDefinition in extraction_zones():
		zones.append(zone.to_dictionary())
	var canonical_player_order: Array[String] = []
	for character_id: StringName in _player_unit_order:
		canonical_player_order.append(String(character_id))
	var canonical_deployed: Array[String] = []
	for character_id: StringName in _deployed_character_ids:
		canonical_deployed.append(String(character_id))
	canonical_deployed.sort()
	var canonical_objectives: Array[Dictionary] = []
	for objective: MissionObjectiveDefinition in objective_definitions():
		canonical_objectives.append(objective.to_dictionary())
	return {
		"mission_id": String(mission_id),
		"mission_definition_id": String(_mission_definition_id),
		"tactical_map_definition_id": String(_tactical_map_definition_id),
		"objective_definitions": canonical_objectives,
		"primary_objective_ids": _string_names(_primary_objective_ids),
		"optional_objective_ids": _string_names(_optional_objective_ids),
		"mission_display_name": mission_display_name,
		"protagonist_character_id": String(protagonist_character_id),
		"primary_objective_id": String(primary_objective_id),
		"primary_objective_text": primary_objective_text,
		"optional_captive_objective_id": String(optional_captive_objective_id),
		"optional_captive_objective_text": optional_captive_objective_text,
		"allows_withdrawal": allows_withdrawal,
		"requires_protagonist_extraction": requires_protagonist_extraction,
		"extraction_zones": zones,
		"source_campaign_revision": source_campaign_revision,
		"characters": characters,
		"items": items,
		"player_unit_order": canonical_player_order,
		"deployed_character_ids": canonical_deployed,
	}


static func _string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


func to_dictionary() -> Dictionary:
	var data: Dictionary = _canonical_dictionary()
	data["finalized"] = _finalized
	data["finalized_setup_hash"] = _finalized_setup_hash
	return data


static func from_dictionary(data: Dictionary) -> MissionSetupSnapshot:
	var result := MissionSetupSnapshot.new()
	if not result.configure_identity(
		StringName(data.get("mission_id", "")),
		maxi(0, int(data.get("source_campaign_revision", 0)))
	):
		return result
	result._mission_definition_id = StringName(data.get("mission_definition_id", ""))
	result._tactical_map_definition_id = StringName(data.get("tactical_map_definition_id", ""))
	result._mission_display_name = String(data.get("mission_display_name", "Tactical Mission"))
	for raw_objective: Variant in data.get("objective_definitions", []):
		if raw_objective is Dictionary:
			var objective := MissionObjectiveDefinition.from_dictionary(raw_objective as Dictionary)
			result._objective_definitions_by_id[objective.objective_id] = objective
	for raw_id: Variant in data.get("primary_objective_ids", []):
		result._primary_objective_ids.append(StringName(raw_id))
	for raw_id: Variant in data.get("optional_objective_ids", []):
		result._optional_objective_ids.append(StringName(raw_id))
	result._protagonist_character_id = StringName(data.get("protagonist_character_id", ""))
	result._primary_objective_id = StringName(data.get("primary_objective_id", "objective.primary"))
	result._primary_objective_text = String(data.get("primary_objective_text", "Complete the mission objective."))
	result._optional_captive_objective_id = StringName(data.get("optional_captive_objective_id", ""))
	result._optional_captive_objective_text = String(data.get("optional_captive_objective_text", ""))
	result._allows_withdrawal = bool(data.get("allows_withdrawal", true))
	result._requires_protagonist_extraction = bool(data.get("requires_protagonist_extraction", true))
	for raw_character: Variant in data.get("characters", []):
		if raw_character is Dictionary:
			result.add_character_copy(PersistentCharacterState.from_dictionary(raw_character as Dictionary))
	for raw_item: Variant in data.get("items", []):
		if raw_item is Dictionary:
			result.add_item_copy(CampaignItemState.from_dictionary(raw_item as Dictionary))
	for raw_id: Variant in data.get("player_unit_order", []):
		result.append_player_unit(StringName(raw_id))
	for raw_id: Variant in data.get("deployed_character_ids", []):
		result.mark_deployed(StringName(raw_id))
	for raw_zone: Variant in data.get("extraction_zones", []):
		if raw_zone is Dictionary:
			var zone := TacticalExtractionZoneDefinition.from_dictionary(raw_zone as Dictionary)
			if zone != null and not zone.zone_id.is_empty():
				result._extraction_zone_definitions_by_id[zone.zone_id] = zone
	if bool(data.get("finalized", false)):
		result._finalized_setup_hash = String(data.get("finalized_setup_hash", ""))
		result._finalized = true
	return result
