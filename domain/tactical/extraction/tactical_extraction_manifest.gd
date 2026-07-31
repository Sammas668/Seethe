class_name TacticalExtractionManifest
extends RefCounted

var zone_id: StringName = &""
var mission_outcome: StringName = &"in_progress"
var source_tactical_revision: int = -1

var extracted_friendly_unit_ids: Array[StringName] = []
var extracted_friendly_body_item_ids: Array[StringName] = []
var captured_enemy_unit_ids: Array[StringName] = []
var recovered_enemy_body_item_ids: Array[StringName] = []
var extracted_item_ids: Array[StringName] = []
var abandoned_item_ids: Array[StringName] = []
var abandoned_friendly_unit_ids: Array[StringName] = []
var abandoned_friendly_body_item_ids: Array[StringName] = []
var unsecured_enemy_unit_ids: Array[StringName] = []

var protagonist_extracted: bool = false
var required_objectives_complete: bool = false
var extraction_is_legal: bool = false
var rejection_reasons: Array[String] = []
var warning_lines: Array[String] = []


func has_extracted_unit(unit_id: StringName) -> bool:
	return extracted_friendly_unit_ids.has(unit_id)


func has_extracted_body_item(body_item_id: StringName) -> bool:
	return (
		extracted_friendly_body_item_ids.has(body_item_id)
		or recovered_enemy_body_item_ids.has(body_item_id)
	)


func to_dictionary() -> Dictionary:
	return {
		"zone_id": String(zone_id),
		"mission_outcome": String(mission_outcome),
		"source_tactical_revision": source_tactical_revision,
		"extracted_friendly_unit_ids": _strings(extracted_friendly_unit_ids),
		"extracted_friendly_body_item_ids": _strings(extracted_friendly_body_item_ids),
		"captured_enemy_unit_ids": _strings(captured_enemy_unit_ids),
		"recovered_enemy_body_item_ids": _strings(recovered_enemy_body_item_ids),
		"extracted_item_ids": _strings(extracted_item_ids),
		"abandoned_item_ids": _strings(abandoned_item_ids),
		"abandoned_friendly_unit_ids": _strings(abandoned_friendly_unit_ids),
		"abandoned_friendly_body_item_ids": _strings(abandoned_friendly_body_item_ids),
		"unsecured_enemy_unit_ids": _strings(unsecured_enemy_unit_ids),
		"protagonist_extracted": protagonist_extracted,
		"required_objectives_complete": required_objectives_complete,
		"extraction_is_legal": extraction_is_legal,
		"rejection_reasons": rejection_reasons.duplicate(),
		"warning_lines": warning_lines.duplicate(),
	}


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
