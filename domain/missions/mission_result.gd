class_name MissionResult
extends RefCounted

var result_id: StringName = &""
var mission_id: StringName = &""
var source_campaign_revision: int = 0
var source_roster_revision: int:
	get:
		return source_campaign_revision
	set(value):
		source_campaign_revision = value
var completed: bool = false
var successful: bool = false
var character_results_by_id: Dictionary = {}
var extracted_item_entries: Array[Dictionary] = []
var generated_item_provenance_by_id: Dictionary = {}


func authorize_generated_item(
		item_id: StringName,
		source_event_id: StringName,
		reason: String,
		definition_id: StringName,
		quantity: int = 1,
		condition: float = 1.0,
		persistent_modifiers: Dictionary = {},
		source_item_ids: Array[StringName] = []
) -> void:
	var clean_reason: String = reason.strip_edges()
	if (
		item_id.is_empty()
		or source_event_id.is_empty()
		or clean_reason.is_empty()
		or definition_id.is_empty()
		or quantity < 1
		or condition < 0.0
		or condition > 1.0
	):
		return
	var sources: Array[String] = []
	for source_item_id: StringName in source_item_ids:
		if not source_item_id.is_empty():
			sources.append(String(source_item_id))
	generated_item_provenance_by_id[item_id] = {
		"source_event_id": String(source_event_id),
		"reason": clean_reason,
		"definition_id": String(definition_id),
		"quantity": quantity,
		"condition": condition,
		"persistent_modifiers": persistent_modifiers.duplicate(true),
		"source_item_ids": sources,
	}


func add_character_result(result: MissionCharacterResult) -> bool:
	if result == null or result.character_id.is_empty():
		return false
	if character_results_by_id.has(result.character_id):
		return false
	character_results_by_id[result.character_id] = result
	return true


func get_character_result(character_id: StringName) -> MissionCharacterResult:
	return character_results_by_id.get(character_id) as MissionCharacterResult


func get_character_results() -> Array[MissionCharacterResult]:
	var result: Array[MissionCharacterResult] = []
	for value: Variant in character_results_by_id.values():
		var character_result: MissionCharacterResult = value as MissionCharacterResult
		if character_result != null:
			result.append(character_result)
	result.sort_custom(
		func(a: MissionCharacterResult, b: MissionCharacterResult) -> bool:
			return String(a.character_id) < String(b.character_id)
	)
	return result


func validate_result() -> Array[String]:
	var errors: Array[String] = []
	if result_id.is_empty():
		errors.append("MissionResult has no result ID.")
	if mission_id.is_empty():
		errors.append("MissionResult has no mission ID.")
	if not completed:
		errors.append("MissionResult is not marked complete.")

	for character_result: MissionCharacterResult in get_character_results():
		errors.append_array(character_result.validate_state())

	var seen_item_ids: Dictionary = {}
	for entry: Dictionary in extracted_item_entries:
		var item_id: StringName = StringName(entry.get("item_id", &""))
		if item_id.is_empty():
			errors.append("MissionResult contains an extracted item with no ID.")
		elif seen_item_ids.has(item_id):
			errors.append("MissionResult duplicates extracted item %s." % item_id)
		else:
			seen_item_ids[item_id] = true

	for raw_id: Variant in generated_item_provenance_by_id.keys():
		var item_id: StringName = StringName(raw_id)
		var entry: Variant = generated_item_provenance_by_id.get(raw_id, {})
		if item_id.is_empty() or not entry is Dictionary:
			errors.append("MissionResult contains invalid generated-item provenance.")
			continue
		var provenance: Dictionary = entry as Dictionary
		if String(provenance.get("source_event_id", "")).is_empty():
			errors.append("Generated item %s has no source event." % item_id)
		if String(provenance.get("reason", "")).strip_edges().is_empty():
			errors.append("Generated item %s has no provenance reason." % item_id)
		if String(provenance.get("definition_id", "")).is_empty():
			errors.append("Generated item %s has no authorised definition." % item_id)
		if int(provenance.get("quantity", 0)) < 1:
			errors.append("Generated item %s has no authorised quantity." % item_id)
		var authorised_condition: float = float(
			provenance.get("condition", -1.0)
		)
		if authorised_condition < 0.0 or authorised_condition > 1.0:
			errors.append("Generated item %s has invalid authorised condition." % item_id)
		if not provenance.get("persistent_modifiers", {}) is Dictionary:
			errors.append("Generated item %s has invalid authorised modifiers." % item_id)
	return errors


func to_dictionary() -> Dictionary:
	var character_results: Array[Dictionary] = []
	for character_result: MissionCharacterResult in get_character_results():
		character_results.append(character_result.to_dictionary())
	return {
		"result_id": String(result_id),
		"mission_id": String(mission_id),
		"source_campaign_revision": source_campaign_revision,
		"completed": completed,
		"successful": successful,
		"character_results": character_results,
		"extracted_item_entries": _serialize_item_entries(extracted_item_entries),
		"generated_item_provenance": _serialize_provenance(
			generated_item_provenance_by_id
		),
	}


static func from_dictionary(data: Dictionary) -> MissionResult:
	var result: MissionResult = MissionResult.new()
	result.result_id = StringName(data.get("result_id", ""))
	result.mission_id = StringName(data.get("mission_id", ""))
	result.source_campaign_revision = maxi(
		0,
		int(
			data.get(
				"source_campaign_revision",
				data.get("source_roster_revision", 0)
			)
		)
	)
	result.completed = bool(data.get("completed", false))
	result.successful = bool(data.get("successful", false))
	var raw_results: Array = data.get("character_results", [])
	for raw_result: Variant in raw_results:
		if raw_result is Dictionary:
			result.add_character_result(
				MissionCharacterResult.from_dictionary(raw_result as Dictionary)
			)
	result.extracted_item_entries = _deserialize_item_entries(
		data.get("extracted_item_entries", data.get("extracted_loot_entries", []))
	)
	result.generated_item_provenance_by_id = _deserialize_provenance(
		data.get("generated_item_provenance", {})
	)
	return result


static func _serialize_item_entries(
		entries: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var item: CampaignItemState = CampaignItemState.from_dictionary(entry)
		result.append(item.to_dictionary())
	return result


static func _deserialize_item_entries(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var values: Array = value as Array
	for raw_entry: Variant in values:
		if not raw_entry is Dictionary:
			continue
		var raw_data: Dictionary = raw_entry as Dictionary
		if raw_data.has("item_id"):
			result.append(
				CampaignItemState.from_dictionary(raw_data).to_dictionary()
			)
			continue

		# Stage 3.13 result compatibility.
		var legacy_item: CampaignItemState = CampaignItemState.new(
			StringName(raw_data.get("instance_id", "")),
			StringName(raw_data.get("definition_id", "")),
			maxi(1, int(raw_data.get("quantity", 1))),
			clampf(float(raw_data.get("condition", 1.0)), 0.0, 1.0),
			CampaignItemLocationState.stronghold_storage()
		)
		result.append(legacy_item.to_dictionary())
	return result


static func _serialize_provenance(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_id: Variant in value.keys():
		var item_id: StringName = StringName(raw_id)
		var raw_entry: Variant = value.get(raw_id, {})
		if item_id.is_empty() or not raw_entry is Dictionary:
			continue
		result[String(item_id)] = (raw_entry as Dictionary).duplicate(true)
	return result


static func _deserialize_provenance(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	var source: Dictionary = value as Dictionary
	for raw_id: Variant in source.keys():
		var item_id: StringName = StringName(raw_id)
		var raw_entry: Variant = source.get(raw_id, {})
		if item_id.is_empty() or not raw_entry is Dictionary:
			continue
		result[item_id] = (raw_entry as Dictionary).duplicate(true)
	return result
