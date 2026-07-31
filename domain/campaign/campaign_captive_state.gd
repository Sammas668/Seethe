class_name CampaignCaptiveState
extends RefCounted

var captive_id: StringName = &""
var source_character_id: StringName = &""
var source_definition_id: StringName = &""
var display_name: String = ""
var current_hp: int = 0
var condition_ids: Array[StringName] = []
var equipment_item_ids: Array[StringName] = []
var restraint_item_id: StringName = &""
var captured_mission_id: StringName = &""
var holding_location_id: StringName = &"stronghold.temporary_holding"
var faction_id: StringName = &""


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if captive_id.is_empty():
		errors.append("Campaign captive has no ID.")
	if source_character_id.is_empty():
		errors.append("Campaign captive %s has no source character." % captive_id)
	if source_definition_id.is_empty():
		errors.append("Campaign captive %s has no source definition." % captive_id)
	if display_name.strip_edges().is_empty():
		errors.append("Campaign captive %s has no display name." % captive_id)
	if captured_mission_id.is_empty():
		errors.append("Campaign captive %s has no capture mission." % captive_id)
	if holding_location_id.is_empty():
		errors.append("Campaign captive %s has no holding location." % captive_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"captive_id": String(captive_id),
		"source_character_id": String(source_character_id),
		"source_definition_id": String(source_definition_id),
		"display_name": display_name,
		"current_hp": current_hp,
		"condition_ids": _strings(condition_ids),
		"equipment_item_ids": _strings(equipment_item_ids),
		"restraint_item_id": String(restraint_item_id),
		"captured_mission_id": String(captured_mission_id),
		"holding_location_id": String(holding_location_id),
		"faction_id": String(faction_id),
	}


static func from_dictionary(data: Dictionary) -> CampaignCaptiveState:
	var result := CampaignCaptiveState.new()
	result.captive_id = StringName(data.get("captive_id", ""))
	result.source_character_id = StringName(data.get("source_character_id", ""))
	result.source_definition_id = StringName(data.get("source_definition_id", ""))
	result.display_name = String(data.get("display_name", ""))
	result.current_hp = int(data.get("current_hp", 0))
	result.restraint_item_id = StringName(data.get("restraint_item_id", ""))
	result.captured_mission_id = StringName(data.get("captured_mission_id", ""))
	result.holding_location_id = StringName(data.get("holding_location_id", "stronghold.temporary_holding"))
	result.faction_id = StringName(data.get("faction_id", ""))
	result.condition_ids = _names(data.get("condition_ids", []))
	result.equipment_item_ids = _names(data.get("equipment_item_ids", []))
	return result


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for raw_value: Variant in value as Array:
			result.append(StringName(raw_value))
	return result
