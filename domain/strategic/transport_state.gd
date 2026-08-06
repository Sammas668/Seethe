class_name TransportState
extends RefCounted

const STATUS_AVAILABLE: StringName = &"available"
const STATUS_ASSIGNED: StringName = &"assigned"
const STATUS_RESERVED: StringName = &"reserved"
const STATUS_TRAVELLING_OUT: StringName = &"travelling_out"
const STATUS_DEPLOYED: StringName = &"deployed"
const STATUS_RETURNING: StringName = &"returning"

# Legacy values are accepted only while loading older saves. They are migrated
# to AVAILABLE and are never produced by current gameplay.
const STATUS_DAMAGED: StringName = &"damaged"
const STATUS_UNDER_REPAIR: StringName = &"under_repair"
const STATUS_UNSUPPORTED: StringName = &"unsupported"
const STATUS_LOST: StringName = &"lost"
const STATUS_DESTROYED: StringName = &"destroyed"

var transport_id: StringName = &""
var definition_id: StringName = &""
var housed_stable_id: StringName = &""
var assigned_bay_id: StringName = &""
var status: StringName = STATUS_AVAILABLE
var reserved_mission_id: StringName = &""
var current_journey_id: StringName = &""
var custom_name: String = ""
var installed_fitting_ids: Array[StringName] = []
var history_entries: Array[String] = []
var revision: int = 0

# Legacy save fields retained so old dictionaries can be read without losing
# data. They have no authority and are never displayed or modified by missions.
var condition: int = 100
var support_enabled: bool = true


func is_destroyed_or_lost() -> bool:
	return false


func is_reserved() -> bool:
	return status in [STATUS_RESERVED, STATUS_TRAVELLING_OUT, STATUS_DEPLOYED, STATUS_RETURNING]


func is_available_for_bay() -> bool:
	return status == STATUS_AVAILABLE and assigned_bay_id.is_empty()


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if transport_id.is_empty():
		errors.append("Transport asset has no ID.")
	if definition_id.is_empty():
		errors.append("Transport asset %s has no definition." % transport_id)
	if status not in [STATUS_AVAILABLE, STATUS_ASSIGNED, STATUS_RESERVED, STATUS_TRAVELLING_OUT, STATUS_DEPLOYED, STATUS_RETURNING]:
		errors.append("Transport asset %s has invalid status %s." % [transport_id, status])
	if is_reserved() and reserved_mission_id.is_empty():
		errors.append("Reserved transport asset %s has no mission." % transport_id)
	if status == STATUS_ASSIGNED and assigned_bay_id.is_empty():
		errors.append("Assigned transport asset %s has no Stable housing record." % transport_id)
	if not assigned_bay_id.is_empty() and housed_stable_id.is_empty():
		errors.append("Transport asset %s is assigned without an exact constructed Stable." % transport_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"transport_id": String(transport_id),
		"definition_id": String(definition_id),
		"housed_stable_id": String(housed_stable_id),
		"assigned_bay_id": String(assigned_bay_id),
		"status": String(status),
		"reserved_mission_id": String(reserved_mission_id),
		"current_journey_id": String(current_journey_id),
		"custom_name": custom_name,
		"installed_fitting_ids": _name_array(installed_fitting_ids),
		"history_entries": history_entries.duplicate(),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> TransportState:
	var result := TransportState.new()
	result.transport_id = StringName(data.get("transport_id", ""))
	result.definition_id = StringName(data.get("definition_id", ""))
	result.housed_stable_id = StringName(data.get("housed_stable_id", ""))
	result.assigned_bay_id = StringName(data.get("assigned_bay_id", ""))
	var loaded_status := StringName(data.get("status", STATUS_AVAILABLE))
	if loaded_status in [STATUS_DAMAGED, STATUS_UNDER_REPAIR, STATUS_UNSUPPORTED, STATUS_LOST, STATUS_DESTROYED]:
		loaded_status = STATUS_AVAILABLE
	result.status = loaded_status
	result.reserved_mission_id = StringName(data.get("reserved_mission_id", ""))
	result.current_journey_id = StringName(data.get("current_journey_id", ""))
	result.custom_name = String(data.get("custom_name", ""))
	result.installed_fitting_ids = _name_array_from(data.get("installed_fitting_ids", []))
	var raw_history: Variant = data.get("history_entries", [])
	if raw_history is Array:
		for raw_entry: Variant in raw_history as Array:
			var entry := String(raw_entry).strip_edges()
			if not entry.is_empty():
				result.history_entries.append(entry)
	result.revision = maxi(0, int(data.get("revision", 0)))
	result.condition = 100
	result.support_enabled = true
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

