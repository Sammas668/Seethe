class_name SubregionNotorietyState
extends RefCounted

var region_id: StringName = &""
var subregion_id: StringName = &""
var value: int = 0
var last_report_id: StringName = &""
var total_positive_change: int = 0
var total_negative_change: int = 0
var revision: int = 0


func apply_delta(delta: int, report_id: StringName) -> int:
	var old_value: int = value
	value = clampi(value + delta, 0, 100)
	var applied: int = value - old_value
	if applied > 0:
		total_positive_change += applied
	elif applied < 0:
		total_negative_change += -applied
	last_report_id = report_id
	revision += 1
	return applied


func stage_label() -> String:
	if value >= 100:
		return "Fully mobilised"
	if value >= 75:
		return "Preparing retaliation"
	if value >= 50:
		return "Alarmed"
	if value >= 25:
		return "Rumours spreading"
	return "Unaware"


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if region_id.is_empty() or subregion_id.is_empty():
		errors.append("Subregion Notoriety state has incomplete identity.")
	if value < 0 or value > 100:
		errors.append("Subregion Notoriety %s is outside 0-100." % subregion_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"region_id": String(region_id),
		"subregion_id": String(subregion_id),
		"value": value,
		"last_report_id": String(last_report_id),
		"total_positive_change": total_positive_change,
		"total_negative_change": total_negative_change,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> SubregionNotorietyState:
	var result := SubregionNotorietyState.new()
	result.region_id = StringName(data.get("region_id", ""))
	result.subregion_id = StringName(data.get("subregion_id", ""))
	result.value = clampi(int(data.get("value", 0)), 0, 100)
	result.last_report_id = StringName(data.get("last_report_id", ""))
	result.total_positive_change = maxi(0, int(data.get("total_positive_change", 0)))
	result.total_negative_change = maxi(0, int(data.get("total_negative_change", 0)))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
