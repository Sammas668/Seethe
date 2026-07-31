class_name CampaignState
extends CharacterRosterState

const CAMPAIGN_ITEM_STATE_SCRIPT = preload(
	"res://domain/campaign/campaign_item_state.gd"
)
const CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT = preload(
	"res://domain/campaign/campaign_item_location_state.gd"
)

const CURRENT_SAVE_VERSION: int = 4

var items_by_id: Dictionary = {}
var captives_by_id: Dictionary = {}
var mission_history_by_id: Dictionary = {}


func _init() -> void:
	save_version = CURRENT_SAVE_VERSION


func upsert_captive(captive: CampaignCaptiveState) -> bool:
	if captive == null or captive.captive_id.is_empty():
		return false
	captives_by_id[captive.captive_id] = captive
	revision += 1
	return true


func get_captive(captive_id: StringName) -> CampaignCaptiveState:
	return captives_by_id.get(captive_id) as CampaignCaptiveState


func get_captives() -> Array[CampaignCaptiveState]:
	var result: Array[CampaignCaptiveState] = []
	for raw_value: Variant in captives_by_id.values():
		var captive: CampaignCaptiveState = raw_value as CampaignCaptiveState
		if captive != null:
			result.append(captive)
	result.sort_custom(
		func(a: CampaignCaptiveState, b: CampaignCaptiveState) -> bool:
			return String(a.captive_id) < String(b.captive_id)
	)
	return result


func has_resolved_mission(mission_id: StringName) -> bool:
	return not mission_id.is_empty() and mission_history_by_id.has(mission_id)


func record_mission_result(result: MissionResult) -> bool:
	if (
		result == null
		or result.mission_id.is_empty()
		or has_resolved_mission(result.mission_id)
	):
		return false
	mission_history_by_id[result.mission_id] = result.to_dictionary()
	revision += 1
	return true


func mission_history(mission_id: StringName) -> Dictionary:
	var raw: Variant = mission_history_by_id.get(mission_id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func add_item(item) -> bool:
	if item == null or item.item_id.is_empty():
		return false
	if items_by_id.has(item.item_id):
		return false
	items_by_id[item.item_id] = item
	revision += 1
	return true


func upsert_item(item) -> bool:
	if item == null or item.item_id.is_empty():
		return false
	items_by_id[item.item_id] = item
	revision += 1
	return true


func remove_item(item_id: StringName) -> bool:
	if item_id.is_empty() or not items_by_id.has(item_id):
		return false
	items_by_id.erase(item_id)
	revision += 1
	return true


func get_item(item_id: StringName):
	return items_by_id.get(item_id)


func get_items() -> Array:
	var result: Array = []
	for value: Variant in items_by_id.values():
		var item = value
		if item != null:
			result.append(item)
	result.sort_custom(
		func(a, b) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


func items_for_character(
		character_id: StringName
) -> Array:
	var result: Array = []
	for item in get_items():
		if item.location != null and item.location.belongs_to_character(character_id):
			result.append(item)
	return result


func item_ids_for_character(character_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for item in items_for_character(character_id):
		result.append(item.item_id)
	return result


func stronghold_storage_items(
		storage_id: StringName = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID
) -> Array:
	var result: Array = []
	for item in get_items():
		if (
			item.location != null
			and item.location.location_type
			== CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.LOCATION_STRONGHOLD_STORAGE
			and item.location.owner_id == storage_id
		):
			result.append(item)
	return result


func items_in_stronghold(
		storage_id: StringName = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID
) -> Array:
	# Compatibility alias for earlier Stage 3.14 callers.
	return stronghold_storage_items(storage_id)


func assign_item_to_character(
		item_id: StringName,
		character_id: StringName,
		container_id: StringName,
		grid_position: Vector2i = Vector2i.ZERO
) -> bool:
	var item = get_item(item_id)
	if item == null or get_character(character_id) == null:
		return false
	item.set_location(
		CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.character_slot(
			character_id,
			container_id,
			grid_position
		)
	)
	revision += 1
	return true


func move_item_to_stronghold(
		item_id: StringName,
		storage_id: StringName = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID,
		grid_position: Vector2i = Vector2i.ZERO
) -> bool:
	var item = get_item(item_id)
	if item == null:
		return false
	item.set_location(
		CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.stronghold_storage(storage_id, grid_position)
	)
	revision += 1
	return true


func unique_item_id(preferred_id: StringName) -> StringName:
	var base_text: String = String(preferred_id)
	if base_text.is_empty():
		base_text = "campaign.item"
	var candidate: StringName = StringName(base_text)
	if not items_by_id.has(candidate):
		return candidate
	var suffix: int = 1
	candidate = StringName("%s.%03d" % [base_text, suffix])
	while items_by_id.has(candidate):
		suffix += 1
		candidate = StringName("%s.%03d" % [base_text, suffix])
	return candidate


func validate_campaign() -> Array[String]:
	var errors: Array[String] = []
	var known_characters: Dictionary = characters_by_id
	for item in get_items():
		errors.append_array(item.validate_state())
		if item.location == null:
			continue
		if (
			item.location.location_type in [
				CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.LOCATION_CHARACTER_EQUIPMENT,
				CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.LOCATION_CHARACTER_INVENTORY,
			]
			and not known_characters.has(item.location.owner_id)
		):
			errors.append(
				"Campaign item %s references missing character %s."
				% [item.item_id, item.location.owner_id]
			)
	for captive: CampaignCaptiveState in get_captives():
		errors.append_array(captive.validate_state())
		if (
			not captive.restraint_item_id.is_empty()
			and get_item(captive.restraint_item_id) == null
		):
			errors.append(
				"Campaign captive %s references missing restraint %s."
				% [captive.captive_id, captive.restraint_item_id]
			)
		for item_id: StringName in captive.equipment_item_ids:
			if get_item(item_id) == null:
				errors.append(
					"Campaign captive %s references missing item %s."
					% [captive.captive_id, item_id]
				)
	return errors



func restore_from_dictionary(data: Dictionary) -> void:
	var restored: CampaignState = CampaignState.from_dictionary(data)
	characters_by_id = restored.characters_by_id
	items_by_id = restored.items_by_id
	captives_by_id = restored.captives_by_id
	mission_history_by_id = restored.mission_history_by_id
	save_version = restored.save_version
	revision = restored.revision
	applied_result_ids = restored.applied_result_ids


func to_dictionary() -> Dictionary:
	var base: Dictionary = super.to_dictionary()
	var serialized_items: Array[Dictionary] = []
	for item in get_items():
		if item.location != null and item.location.belongs_to_character(item.location.owner_id):
			var owner: PersistentCharacterState = get_character(item.location.owner_id)
			if (
				owner != null
				and owner.persistence_scope
				== PersistentCharacterState.PERSISTENCE_MISSION
			):
				continue
		serialized_items.append(item.to_dictionary())
	var serialized_captives: Array[Dictionary] = []
	for captive: CampaignCaptiveState in get_captives():
		serialized_captives.append(captive.to_dictionary())
	base["save_version"] = CURRENT_SAVE_VERSION
	base["items"] = serialized_items
	base["captives"] = serialized_captives
	base["mission_history"] = mission_history_by_id.duplicate(true)
	return base


static func from_dictionary(data: Dictionary) -> CampaignState:
	var campaign: CampaignState = CampaignState.new()
	campaign.revision = maxi(0, int(data.get("revision", 0)))

	var raw_result_ids: Array = data.get("applied_result_ids", [])
	for raw_result_id: Variant in raw_result_ids:
		var result_id: StringName = StringName(raw_result_id)
		if not result_id.is_empty():
			campaign.applied_result_ids[result_id] = true

	var raw_characters: Array = data.get("characters", [])
	for raw_character: Variant in raw_characters:
		if not raw_character is Dictionary:
			continue
		var character_data: Dictionary = raw_character as Dictionary
		var character: PersistentCharacterState = (
			PersistentCharacterState.from_dictionary(character_data)
		)
		if character.character_id.is_empty():
			continue
		campaign.characters_by_id[character.character_id] = character
		_migrate_legacy_loadouts(campaign, character_data, character.character_id)

	var raw_items: Array = data.get("items", [])
	for raw_item: Variant in raw_items:
		if not raw_item is Dictionary:
			continue
		var item = CAMPAIGN_ITEM_STATE_SCRIPT.from_dictionary(
			raw_item as Dictionary
		)
		if item.item_id.is_empty():
			continue
		item.item_id = campaign.unique_item_id(item.item_id)
		campaign.items_by_id[item.item_id] = item

	_migrate_legacy_campaign_loot(
		campaign,
		data.get("campaign_loot_entries", [])
	)
	var raw_captives: Variant = data.get("captives", [])
	if raw_captives is Array:
		for raw_captive: Variant in raw_captives as Array:
			if not raw_captive is Dictionary:
				continue
			var captive: CampaignCaptiveState = CampaignCaptiveState.from_dictionary(
				raw_captive as Dictionary
			)
			if not captive.captive_id.is_empty():
				campaign.captives_by_id[captive.captive_id] = captive
	var raw_history: Variant = data.get("mission_history", {})
	if raw_history is Dictionary:
		for raw_mission_id: Variant in (raw_history as Dictionary).keys():
			var mission_id: StringName = StringName(raw_mission_id)
			var raw_entry: Variant = (raw_history as Dictionary).get(
				raw_mission_id, {}
			)
			if not mission_id.is_empty() and raw_entry is Dictionary:
				campaign.mission_history_by_id[mission_id] = (
					(raw_entry as Dictionary).duplicate(true)
				)
	campaign.save_version = CURRENT_SAVE_VERSION
	return campaign


static func _migrate_legacy_loadouts(
		campaign: CampaignState,
		character_data: Dictionary,
		character_id: StringName
) -> void:
	var raw_loadout: Variant = character_data.get("loadout_entries", [])
	if not raw_loadout is Array:
		return
	var legacy_entries: Array = raw_loadout as Array
	for raw_entry: Variant in legacy_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var preferred_id: StringName = StringName(entry.get("instance_id", ""))
		var item_id: StringName = campaign.unique_item_id(preferred_id)
		var container_id: StringName = StringName(
			entry.get("container_kind", CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.CONTAINER_BACKPACK)
		)
		var position: Vector2i = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT._vector_from_value(
			entry.get("grid_position", [0, 0])
		)
		var item = CAMPAIGN_ITEM_STATE_SCRIPT.new(
			item_id,
			StringName(entry.get("definition_id", "")),
			maxi(1, int(entry.get("quantity", 1))),
			clampf(float(entry.get("condition", 1.0)), 0.0, 1.0),
			CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.character_slot(
				character_id,
				container_id,
				position
			)
		)
		campaign.items_by_id[item.item_id] = item


static func _migrate_legacy_campaign_loot(
		campaign: CampaignState,
		raw_entries: Variant
) -> void:
	if not raw_entries is Array:
		return
	var legacy_entries: Array = raw_entries as Array
	for raw_entry: Variant in legacy_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var preferred_id: StringName = StringName(entry.get("instance_id", ""))
		var item_id: StringName = campaign.unique_item_id(preferred_id)
		var position: Vector2i = CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT._vector_from_value(
			entry.get("grid_position", [0, 0])
		)
		var item = CAMPAIGN_ITEM_STATE_SCRIPT.new(
			item_id,
			StringName(entry.get("definition_id", "")),
			maxi(1, int(entry.get("quantity", 1))),
			clampf(float(entry.get("condition", 1.0)), 0.0, 1.0),
			CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.stronghold_storage(
				CAMPAIGN_ITEM_LOCATION_STATE_SCRIPT.DEFAULT_STRONGHOLD_STORAGE_ID,
				position
			)
		)
		campaign.items_by_id[item.item_id] = item
