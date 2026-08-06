class_name MissionResult
extends RefCounted

var result_id: StringName = &""
var mission_id: StringName = &""
var source_campaign_revision: int = 0
var source_setup_hash: String = ""
var source_roster_revision: int:
	get:
		return source_campaign_revision
	set(value):
		source_campaign_revision = value
var completed: bool = false
var successful: bool = false
var mission_outcome: StringName = MissionOutcome.IN_PROGRESS
var completed_objective_ids: Array[StringName] = []
var failed_objective_ids: Array[StringName] = []
var optional_objective_ids: Array[StringName] = []
var extracted_zone_id: StringName = &""
var protagonist_extracted: bool = false
var captive_results_by_character_id: Dictionary = {}
var abandoned_item_ids: Array[StringName] = []
var summary_event_ids: Array[StringName] = []
var mission_statistics: Dictionary = {}
var character_results_by_id: Dictionary = {}
var extracted_item_entries: Array[Dictionary] = []
var generated_item_provenance_ids: Array[StringName] = []
var objective_outcomes_by_id: Dictionary = {}
var notoriety_preview_lines: Array[String] = []
var important_event_ids: Array[StringName] = []
# Exact post-mission disposition for every outbound player item. Values are
# plain Dictionaries so the immutable result remains JSON-stable.
var item_outcomes_by_id: Dictionary = {}


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


func add_captive_result(result: MissionCaptiveResult) -> bool:
	if result == null or result.character_id.is_empty():
		return false
	if captive_results_by_character_id.has(result.character_id):
		return false
	captive_results_by_character_id[result.character_id] = result
	return true


func get_captive_results() -> Array[MissionCaptiveResult]:
	var result: Array[MissionCaptiveResult] = []
	for raw_value: Variant in captive_results_by_character_id.values():
		var captive: MissionCaptiveResult = raw_value as MissionCaptiveResult
		if captive != null:
			result.append(captive)
	result.sort_custom(
		func(a: MissionCaptiveResult, b: MissionCaptiveResult) -> bool:
			return String(a.character_id) < String(b.character_id)
	)
	return result


func item_outcome(item_id: StringName) -> Dictionary:
	var raw: Variant = item_outcomes_by_id.get(
		item_id,
		item_outcomes_by_id.get(String(item_id), {})
	)
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func validate_result() -> Array[String]:
	var errors: Array[String] = []
	if result_id.is_empty():
		errors.append("MissionResult has no result ID.")
	if mission_id.is_empty():
		errors.append("MissionResult has no mission ID.")
	if source_setup_hash.length() != 64:
		errors.append("MissionResult has no valid source setup hash.")
	if not completed:
		errors.append("MissionResult is not marked complete.")
	if completed and not MissionOutcome.is_final(mission_outcome):
		errors.append("MissionResult has no final mission outcome.")
	if (
		mission_outcome in [MissionOutcome.VICTORY, MissionOutcome.WITHDRAWAL]
		and not completed_objective_ids.is_empty()
		and extracted_zone_id.is_empty()
	):
		errors.append("Extracted MissionResult has no extraction zone.")

	for character_result: MissionCharacterResult in get_character_results():
		errors.append_array(character_result.validate_state())

	for captive_result: MissionCaptiveResult in get_captive_results():
		errors.append_array(captive_result.validate_state())

	for raw_stat_name: Variant in mission_statistics.keys():
		var stat_value: Variant = mission_statistics.get(raw_stat_name)
		if not stat_value is int or int(stat_value) < 0:
			errors.append(
				"Mission statistic %s must be a non-negative integer."
				% String(raw_stat_name)
			)

	var seen_item_ids: Dictionary = {}
	for entry: Dictionary in extracted_item_entries:
		var item_id: StringName = StringName(entry.get("item_id", &""))
		if item_id.is_empty():
			errors.append("MissionResult contains an extracted item with no ID.")
		elif seen_item_ids.has(item_id):
			errors.append("MissionResult duplicates extracted item %s." % item_id)
		else:
			seen_item_ids[item_id] = true

	var known_item_outcomes: Array[StringName] = [
		&"returned",
		&"partially_consumed",
		&"consumed",
		&"lost",
		&"consumed_or_lost",
		&"transferred",
	]
	for raw_item_id: Variant in item_outcomes_by_id.keys():
		var item_id := StringName(raw_item_id)
		var raw_outcome: Variant = item_outcomes_by_id.get(raw_item_id, {})
		if item_id.is_empty() or not raw_outcome is Dictionary:
			errors.append("MissionResult contains an invalid deployment-item outcome.")
			continue
		var outcome: Dictionary = raw_outcome as Dictionary
		var outcome_id := StringName(outcome.get("outcome", ""))
		if outcome_id not in known_item_outcomes:
			errors.append("MissionResult item %s has unknown outcome %s." % [item_id, outcome_id])
		if int(outcome.get("original_quantity", 0)) < 1:
			errors.append("MissionResult item %s has no valid original quantity." % item_id)
		if int(outcome.get("final_quantity", 0)) < 0:
			errors.append("MissionResult item %s has a negative final quantity." % item_id)
		var no_longer_owned: bool = outcome_id in [
			&"consumed",
			&"lost",
			&"consumed_or_lost",
		]
		if no_longer_owned and int(outcome.get("final_quantity", 0)) != 0:
			errors.append("Consumed or lost item %s still has a final quantity." % item_id)
		if not no_longer_owned and not seen_item_ids.has(item_id):
			errors.append("Surviving deployment item %s is missing from extracted items." % item_id)

	for raw_objective_id: Variant in objective_outcomes_by_id.keys():
		var objective_id := StringName(raw_objective_id)
		if objective_id.is_empty() or not objective_outcomes_by_id.get(raw_objective_id) is Dictionary:
			errors.append("MissionResult contains an invalid objective outcome entry.")

	var provenance_seen: Dictionary = {}
	for provenance_id: StringName in generated_item_provenance_ids:
		if provenance_id.is_empty():
			errors.append("MissionResult contains an empty generated-item provenance ID.")
		elif provenance_seen.has(provenance_id):
			errors.append("MissionResult duplicates generated-item provenance %s." % provenance_id)
		else:
			provenance_seen[provenance_id] = true

	return errors


func to_dictionary() -> Dictionary:
	var character_results: Array[Dictionary] = []
	for character_result: MissionCharacterResult in get_character_results():
		character_results.append(character_result.to_dictionary())
	var captive_results: Array[Dictionary] = []
	for captive_result: MissionCaptiveResult in get_captive_results():
		captive_results.append(captive_result.to_dictionary())
	return {
		"result_id": String(result_id),
		"mission_id": String(mission_id),
		"source_campaign_revision": source_campaign_revision,
		"source_setup_hash": source_setup_hash,
		"completed": completed,
		"successful": successful,
		"mission_outcome": String(mission_outcome),
		"completed_objective_ids": _serialize_string_names(completed_objective_ids),
		"failed_objective_ids": _serialize_string_names(failed_objective_ids),
		"optional_objective_ids": _serialize_string_names(optional_objective_ids),
		"extracted_zone_id": String(extracted_zone_id),
		"protagonist_extracted": protagonist_extracted,
		"character_results": character_results,
		"captive_results": captive_results,
		"abandoned_item_ids": _serialize_string_names(abandoned_item_ids),
		"summary_event_ids": _serialize_string_names(summary_event_ids),
		"mission_statistics": mission_statistics.duplicate(true),
		"extracted_item_entries": _serialize_item_entries(extracted_item_entries),
		"generated_item_provenance_ids": _serialize_string_names(
			generated_item_provenance_ids
		),
		"objective_outcomes_by_id": objective_outcomes_by_id.duplicate(true),
		"notoriety_preview_lines": notoriety_preview_lines.duplicate(),
		"important_event_ids": _serialize_string_names(important_event_ids),
		"item_outcomes_by_id": item_outcomes_by_id.duplicate(true),
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
	result.source_setup_hash = String(data.get("source_setup_hash", ""))
	result.completed = bool(data.get("completed", false))
	result.successful = bool(data.get("successful", false))
	result.mission_outcome = StringName(data.get(
		"mission_outcome",
		MissionOutcome.VICTORY if result.successful else MissionOutcome.DEFEAT
	))
	result.completed_objective_ids = _deserialize_string_names(data.get("completed_objective_ids", []))
	result.failed_objective_ids = _deserialize_string_names(data.get("failed_objective_ids", []))
	result.optional_objective_ids = _deserialize_string_names(data.get("optional_objective_ids", []))
	result.extracted_zone_id = StringName(data.get("extracted_zone_id", ""))
	result.protagonist_extracted = bool(data.get("protagonist_extracted", false))
	result.abandoned_item_ids = _deserialize_string_names(data.get("abandoned_item_ids", []))
	result.summary_event_ids = _deserialize_string_names(data.get("summary_event_ids", []))
	var raw_statistics: Variant = data.get("mission_statistics", {})
	if raw_statistics is Dictionary:
		result.mission_statistics = (raw_statistics as Dictionary).duplicate(true)
	var raw_results: Array = data.get("character_results", [])
	for raw_result: Variant in raw_results:
		if raw_result is Dictionary:
			result.add_character_result(
				MissionCharacterResult.from_dictionary(raw_result as Dictionary)
			)
	var raw_captives: Variant = data.get("captive_results", [])
	if raw_captives is Array:
		for raw_captive: Variant in raw_captives as Array:
			if raw_captive is Dictionary:
				result.add_captive_result(
					MissionCaptiveResult.from_dictionary(raw_captive as Dictionary)
				)
	result.extracted_item_entries = _deserialize_item_entries(
		data.get("extracted_item_entries", data.get("extracted_loot_entries", []))
	)
	result.generated_item_provenance_ids = _deserialize_string_names(
		data.get("generated_item_provenance_ids", [])
	)
	var raw_objectives: Variant = data.get("objective_outcomes_by_id", {})
	if raw_objectives is Dictionary:
		result.objective_outcomes_by_id = (raw_objectives as Dictionary).duplicate(true)
	for raw_line: Variant in data.get("notoriety_preview_lines", []):
		result.notoriety_preview_lines.append(String(raw_line))
	result.important_event_ids = _deserialize_string_names(
		data.get("important_event_ids", [])
	)
	var raw_item_outcomes: Variant = data.get("item_outcomes_by_id", {})
	if raw_item_outcomes is Dictionary:
		result.item_outcomes_by_id = (raw_item_outcomes as Dictionary).duplicate(true)
	return result


static func _serialize_string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _deserialize_string_names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for raw_value: Variant in value as Array:
			result.append(StringName(raw_value))
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

