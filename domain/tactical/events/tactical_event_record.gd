extends RefCounted


static func create(
		event_type: StringName,
		round_number: int,
		phase_id: StringName,
		summary: String,
		options: Dictionary = {}
) -> Dictionary:
	return {
		"event_id": &"",
		"sequence_number": 0,
		"round_number": round_number,
		"phase_id": phase_id,
		"event_type": event_type,
		"category": StringName(options.get("category", &"events")),
		"summary": summary,
		"source_actor_id": StringName(
			options.get("source_actor_id", &"")
		),
		"target_actor_ids": _array_copy(
			options.get("target_actor_ids", [])
		),
		"action_id": StringName(options.get("action_id", &"")),
		"item_id": StringName(options.get("item_id", &"")),
		"details": _array_copy(options.get("details", [])),
		"roll_records": _array_copy(
			options.get("roll_records", [])
		),
		"modifier_records": _array_copy(
			options.get("modifier_records", [])
		),
		"effect_records": _array_copy(
			options.get("effect_records", [])
		),
		"resource_changes": _array_copy(
			options.get("resource_changes", [])
		),
		"visibility": StringName(
			options.get("visibility", &"player")
		),
		"parent_event_id": StringName(
			options.get("parent_event_id", &"")
		),
		"metadata": _dictionary_copy(
			options.get("metadata", {})
		),
	}


static func _array_copy(value: Variant) -> Array:
	if value is Array:
		var values: Array = value
		return values.duplicate(true)
	return []


static func _dictionary_copy(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}
