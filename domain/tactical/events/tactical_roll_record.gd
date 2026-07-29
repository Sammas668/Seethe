extends RefCounted


static func create(
		roll_type: StringName,
		dice_expression: String,
		die_results: Array,
		final_total: int,
		opposing_value: int = -1,
		outcome: StringName = &"",
		modifiers: Array = []
) -> Dictionary:
	return {
		"roll_type": roll_type,
		"dice_expression": dice_expression,
		"die_results": die_results.duplicate(true),
		"modifiers": modifiers.duplicate(true),
		"final_total": final_total,
		"opposing_value": opposing_value,
		"outcome": outcome,
	}
