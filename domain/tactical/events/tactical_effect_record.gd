extends RefCounted


static func create(
		label: String,
		effect_type: StringName,
		before_value: Variant = null,
		after_value: Variant = null,
		source_id: StringName = &""
) -> Dictionary:
	return {
		"label": label,
		"effect_type": effect_type,
		"before_value": before_value,
		"after_value": after_value,
		"source_id": source_id,
	}
