extends RefCounted


static func create(
		label: String,
		value: int,
		source_id: StringName = &"",
		source_type: StringName = &"rule"
) -> Dictionary:
	return {
		"label": label,
		"value": value,
		"source_id": source_id,
		"source_type": source_type,
	}
