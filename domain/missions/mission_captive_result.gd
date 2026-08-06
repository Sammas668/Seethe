class_name MissionCaptiveResult
extends RefCounted

var character_id: StringName = &""
var source_definition_id: StringName = &""
var display_name: String = ""
var body_item_id: StringName = &""
var restraint_item_id: StringName = &""
var condition_at_extraction: StringName = &""
var current_hp: int = 0
var maximum_hp: int = 1
var nonlethal_damage: int = 0
var equipment_item_ids: Array[StringName] = []
var faction_id: StringName = &""
var captured_mission_id: StringName = &""
var captor_character_id: StringName = &""


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if character_id.is_empty():
		errors.append("Mission captive result has no character ID.")
	if source_definition_id.is_empty():
		errors.append("Mission captive %s has no source definition." % character_id)
	if display_name.strip_edges().is_empty():
		errors.append("Mission captive %s has no display name." % character_id)
	if body_item_id.is_empty():
		errors.append("Mission captive %s has no body item." % character_id)
	if restraint_item_id.is_empty():
		errors.append("Mission captive %s has no restraint item." % character_id)
	if condition_at_extraction == TacticalUnitState.LIFE_STATE_DEAD:
		errors.append("Dead character %s cannot be a living captive." % character_id)
	return errors


func to_dictionary() -> Dictionary:
	var equipment: Array[String] = []
	for item_id: StringName in equipment_item_ids:
		equipment.append(String(item_id))
	return {
		"character_id": String(character_id),
		"source_definition_id": String(source_definition_id),
		"display_name": display_name,
		"body_item_id": String(body_item_id),
		"restraint_item_id": String(restraint_item_id),
		"condition_at_extraction": String(condition_at_extraction),
		"current_hp": current_hp,
		"maximum_hp": maximum_hp,
		"nonlethal_damage": nonlethal_damage,
		"equipment_item_ids": equipment,
		"faction_id": String(faction_id),
		"captured_mission_id": String(captured_mission_id),
		"captor_character_id": String(captor_character_id),
	}


static func from_dictionary(data: Dictionary) -> MissionCaptiveResult:
	var result := MissionCaptiveResult.new()
	result.character_id = StringName(data.get("character_id", ""))
	result.source_definition_id = StringName(data.get("source_definition_id", ""))
	result.display_name = String(data.get("display_name", ""))
	result.body_item_id = StringName(data.get("body_item_id", ""))
	result.restraint_item_id = StringName(data.get("restraint_item_id", ""))
	result.condition_at_extraction = StringName(data.get("condition_at_extraction", ""))
	result.current_hp = maxi(0, int(data.get("current_hp", 0)))
	result.maximum_hp = maxi(result.current_hp, int(data.get("maximum_hp", maxi(1, result.current_hp))))
	result.nonlethal_damage = maxi(0, int(data.get("nonlethal_damage", 0)))
	result.faction_id = StringName(data.get("faction_id", ""))
	result.captured_mission_id = StringName(data.get("captured_mission_id", ""))
	result.captor_character_id = StringName(data.get("captor_character_id", ""))
	var raw_items: Variant = data.get("equipment_item_ids", [])
	if raw_items is Array:
		for raw_item_id: Variant in raw_items as Array:
			result.equipment_item_ids.append(StringName(raw_item_id))
	return result
