class_name TravelExposureEntry
extends RefCounted

var entry_id: StringName = &""
var subregion_id: StringName = &""
var start_route_minutes: float = 0.0
var end_route_minutes: float = 0.0
var completion_tick: int = 0
var geographic_category: StringName = &""
var quantity: int = 0
var value_per_unit: int = 0
var base_subtotal: int = 0
var visibility_category: StringName = &""
var visibility_multiplier: float = 1.0
var applied_subtotal: int = 0
# Transport modifies the complete journey after route and squad exposure are calculated.
# These fields preserve the explainable pre-transport amount and the distributed adjustment.
var pre_transport_subtotal: int = 0
var transport_modifier_percent: int = 0
var transport_adjustment: int = 0
var report_text: String = ""
var applied: bool = false


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if entry_id.is_empty():
		errors.append("Travel exposure entry has no ID.")
	if subregion_id.is_empty():
		errors.append("Travel exposure entry %s has no subregion." % entry_id)
	if end_route_minutes < start_route_minutes:
		errors.append("Travel exposure entry %s has reversed route timing." % entry_id)
	if quantity < 0 or value_per_unit < 0 or base_subtotal < 0 or applied_subtotal < 0:
		errors.append("Travel exposure entry %s has negative exposure." % entry_id)
	if quantity * value_per_unit != base_subtotal:
		errors.append("Travel exposure entry %s base subtotal is not explainable." % entry_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"entry_id": String(entry_id),
		"subregion_id": String(subregion_id),
		"start_route_minutes": start_route_minutes,
		"end_route_minutes": end_route_minutes,
		"completion_tick": completion_tick,
		"geographic_category": String(geographic_category),
		"quantity": quantity,
		"value_per_unit": value_per_unit,
		"base_subtotal": base_subtotal,
		"visibility_category": String(visibility_category),
		"visibility_multiplier": visibility_multiplier,
		"applied_subtotal": applied_subtotal,
		"pre_transport_subtotal": pre_transport_subtotal,
		"transport_modifier_percent": transport_modifier_percent,
		"transport_adjustment": transport_adjustment,
		"report_text": report_text,
		"applied": applied,
	}


static func from_dictionary(data: Dictionary) -> TravelExposureEntry:
	var result := TravelExposureEntry.new()
	result.entry_id = StringName(data.get("entry_id", ""))
	result.subregion_id = StringName(data.get("subregion_id", ""))
	result.start_route_minutes = maxf(0.0, float(data.get("start_route_minutes", 0.0)))
	result.end_route_minutes = maxf(result.start_route_minutes, float(data.get("end_route_minutes", result.start_route_minutes)))
	result.completion_tick = maxi(0, int(data.get("completion_tick", 0)))
	result.geographic_category = StringName(data.get("geographic_category", ""))
	result.quantity = maxi(0, int(data.get("quantity", 0)))
	result.value_per_unit = maxi(0, int(data.get("value_per_unit", 0)))
	result.base_subtotal = maxi(0, int(data.get("base_subtotal", result.quantity * result.value_per_unit)))
	result.visibility_category = StringName(data.get("visibility_category", ""))
	result.visibility_multiplier = maxf(0.01, float(data.get("visibility_multiplier", 1.0)))
	result.applied_subtotal = maxi(0, int(data.get("applied_subtotal", 0)))
	result.pre_transport_subtotal = maxi(0, int(data.get("pre_transport_subtotal", result.applied_subtotal)))
	result.transport_modifier_percent = int(data.get("transport_modifier_percent", 0))
	result.transport_adjustment = int(data.get("transport_adjustment", result.applied_subtotal - result.pre_transport_subtotal))
	result.report_text = String(data.get("report_text", ""))
	result.applied = bool(data.get("applied", false))
	return result
