class_name TravelNotorietyReport
extends RefCounted

var report_id: StringName = &""
var source_travel_operation_id: StringName = &""
var subregion_id: StringName = &""
var exposure_entry_ids: Array[StringName] = []
var line_items: Array[Dictionary] = []
var base_subtotal: int = 0
var visibility_adjustment: int = 0
var transport_modifier_percent: int = 0
var transport_adjustment: int = 0
var applied_delta: int = 0
var old_local_value: int = 0
var new_local_value: int = 0
var old_regional_total: int = 0
var new_regional_total: int = 0
var created_raid_operation_id: StringName = &""
var created_tick: int = 0


func to_dictionary() -> Dictionary:
	return {
		"report_id": String(report_id),
		"source_travel_operation_id": String(source_travel_operation_id),
		"subregion_id": String(subregion_id),
		"exposure_entry_ids": _name_array(exposure_entry_ids),
		"line_items": line_items.duplicate(true),
		"base_subtotal": base_subtotal,
		"visibility_adjustment": visibility_adjustment,
		"transport_modifier_percent": transport_modifier_percent,
		"transport_adjustment": transport_adjustment,
		"applied_delta": applied_delta,
		"old_local_value": old_local_value,
		"new_local_value": new_local_value,
		"old_regional_total": old_regional_total,
		"new_regional_total": new_regional_total,
		"created_raid_operation_id": String(created_raid_operation_id),
		"created_tick": created_tick,
	}


static func from_dictionary(data: Dictionary) -> TravelNotorietyReport:
	var result := TravelNotorietyReport.new()
	result.report_id = StringName(data.get("report_id", ""))
	result.source_travel_operation_id = StringName(data.get("source_travel_operation_id", ""))
	result.subregion_id = StringName(data.get("subregion_id", ""))
	result.exposure_entry_ids = _name_array_from(data.get("exposure_entry_ids", []))
	var raw_lines: Variant = data.get("line_items", [])
	if raw_lines is Array:
		for raw_line: Variant in raw_lines as Array:
			if raw_line is Dictionary:
				result.line_items.append((raw_line as Dictionary).duplicate(true))
	result.base_subtotal = maxi(0, int(data.get("base_subtotal", 0)))
	result.visibility_adjustment = maxi(0, int(data.get("visibility_adjustment", 0)))
	result.transport_modifier_percent = int(data.get("transport_modifier_percent", 0))
	result.transport_adjustment = int(data.get("transport_adjustment", 0))
	result.applied_delta = maxi(0, int(data.get("applied_delta", 0)))
	result.old_local_value = clampi(int(data.get("old_local_value", 0)), 0, 100)
	result.new_local_value = clampi(int(data.get("new_local_value", 0)), 0, 100)
	result.old_regional_total = maxi(0, int(data.get("old_regional_total", 0)))
	result.new_regional_total = maxi(0, int(data.get("new_regional_total", 0)))
	result.created_raid_operation_id = StringName(data.get("created_raid_operation_id", ""))
	result.created_tick = maxi(0, int(data.get("created_tick", 0)))
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
