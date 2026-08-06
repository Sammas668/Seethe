class_name CampaignSquadState
extends RefCounted

var squad_id: StringName = &""
var display_name: String = "Squad"
var member_character_ids: Array[StringName] = []
var leader_character_id: StringName = &""
var assigned_stable_bay_id: StringName = &""
var current_operation_id: StringName = &""
var history_entries: Array[String] = []
var revision: int = 0


func is_active() -> bool:
	return not current_operation_id.is_empty()


func contains_character(character_id: StringName) -> bool:
	return member_character_ids.has(character_id)


func validate_state(campaign: CampaignState = null) -> Array[String]:
	var errors: Array[String] = []
	if squad_id.is_empty():
		errors.append("Campaign squad has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Campaign squad %s has no display name." % squad_id)
	var seen: Dictionary = {}
	for character_id: StringName in member_character_ids:
		if character_id.is_empty():
			errors.append("Campaign squad %s contains an empty character ID." % squad_id)
			continue
		if seen.has(character_id):
			errors.append("Campaign squad %s contains character %s twice." % [squad_id, character_id])
			continue
		seen[character_id] = true
		if campaign != null and campaign.get_character(character_id) == null:
			errors.append("Campaign squad %s references missing character %s." % [squad_id, character_id])
	if not leader_character_id.is_empty() and not member_character_ids.has(leader_character_id):
		errors.append("Campaign squad %s leader is not a member." % squad_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"squad_id": String(squad_id),
		"display_name": display_name,
		"member_character_ids": _name_array(member_character_ids),
		"leader_character_id": String(leader_character_id),
		"assigned_stable_bay_id": String(assigned_stable_bay_id),
		"current_operation_id": String(current_operation_id),
		"history_entries": history_entries.duplicate(),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> CampaignSquadState:
	var result := CampaignSquadState.new()
	result.squad_id = StringName(data.get("squad_id", ""))
	result.display_name = String(data.get("display_name", "Squad"))
	result.member_character_ids = _name_array_from(data.get("member_character_ids", []))
	result.leader_character_id = StringName(data.get("leader_character_id", ""))
	result.assigned_stable_bay_id = StringName(data.get("assigned_stable_bay_id", ""))
	result.current_operation_id = StringName(data.get("current_operation_id", ""))
	var raw_history: Variant = data.get("history_entries", [])
	if raw_history is Array:
		for raw_entry: Variant in raw_history as Array:
			var entry := String(raw_entry).strip_edges()
			if not entry.is_empty():
				result.history_entries.append(entry)
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result


static func _name_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _name_array_from(raw_value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if raw_value is Array:
		for raw_entry: Variant in raw_value as Array:
			var value := StringName(raw_entry)
			if not value.is_empty():
				result.append(value)
	return result
