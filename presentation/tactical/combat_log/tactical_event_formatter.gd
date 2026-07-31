extends RefCounted


static func summary_text(event: Dictionary) -> String:
	return str(event.get("summary", "Unknown tactical event."))


static func details_text(event: Dictionary) -> String:
	var lines: Array[String] = []
	var round_number: int = int(event.get("round_number", 0))
	var phase_id: StringName = StringName(str(event.get("phase_id", &"")))
	lines.append(
		"ROUND %d · %s"
		% [round_number, _phase_label(phase_id)]
	)

	var details: Array = event.get("details", [])
	for detail: Variant in details:
		lines.append(str(detail))

	var rolls: Array = event.get("roll_records", [])
	for roll_value: Variant in rolls:
		if not roll_value is Dictionary:
			continue
		var roll: Dictionary = roll_value
		lines.append("")
		lines.append(_roll_heading(roll))
		lines.append(
			"%s: %s"
			% [
				str(roll.get("dice_expression", "Roll")),
				_results_text(roll.get("die_results", [])),
			]
		)

		var modifiers: Array = roll.get("modifiers", [])
		for modifier_value: Variant in modifiers:
			if not modifier_value is Dictionary:
				continue
			var modifier: Dictionary = modifier_value
			lines.append(
				"%s: %+d"
				% [
					str(modifier.get("label", "Modifier")),
					int(modifier.get("value", 0)),
				]
			)

		lines.append(
			"Final total: %d" % int(roll.get("final_total", 0))
		)

		var opposing_value: int = int(roll.get("opposing_value", -1))
		if opposing_value >= 0:
			lines.append(
				"Opposing value: %d" % opposing_value
			)

		var outcome: StringName = StringName(str(roll.get("outcome", &"")))
		if not outcome.is_empty():
			lines.append(
				"Outcome: %s"
				% str(outcome).replace("_", " ").capitalize()
			)

	var effects: Array = event.get("effect_records", [])
	for effect_value: Variant in effects:
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		lines.append(
			"%s: %s → %s"
			% [
				str(effect.get("label", "Effect")),
				str(effect.get("before_value", "-")),
				str(effect.get("after_value", "-")),
			]
		)

	return "\n".join(PackedStringArray(lines))


static func _phase_label(phase_id: StringName) -> String:
	match phase_id:
		&"player":
			return "PLAYER PHASE"
		&"enemy":
			return "ENEMY TURN"
		&"world":
			return "WORLD PHASE"
		_:
			return str(phase_id).replace("_", " ").capitalize()


static func _roll_heading(roll: Dictionary) -> String:
	var roll_type: StringName = StringName(str(roll.get("roll_type", &"roll")))
	return str(roll_type).replace("_", " ").capitalize()


static func _results_text(results_value: Variant) -> String:
	if not results_value is Array:
		return "—"
	var results: Array = results_value
	if results.is_empty():
		return "—"

	var result_strings: Array[String] = []
	for result: Variant in results:
		result_strings.append(str(result))
	return "[" + ", ".join(PackedStringArray(result_strings)) + "]"
