class_name StableBayState
extends RefCounted

const STATUS_EMPTY: StringName = &"empty"
const STATUS_READY: StringName = &"ready"
const STATUS_TRAVELLING_OUT: StringName = &"travelling_out"
const STATUS_AT_MISSION: StringName = &"at_mission"
const STATUS_RETURNING: StringName = &"returning"

# A StableBayState now represents one exact constructed Stable facility rather
# than an abstract capacity point produced by facility level.
var bay_id: StringName = &""
var bay_index: int = 0
var stable_facility_id: StringName = &""
var assigned_squad_id: StringName = &""
var transport_method_id: StringName = &"transport.walking"
var transport_asset_id: StringName = &""
var is_walking: bool = true
var formation_character_ids_by_slot: Dictionary = {}
var installed_fitting_ids: Array[StringName] = []
var active_operation_id: StringName = &""
var status: StringName = STATUS_EMPTY
var revision: int = 0


func is_active() -> bool:
	return status in [STATUS_TRAVELLING_OUT, STATUS_AT_MISSION, STATUS_RETURNING]


func is_assignable() -> bool:
	return not is_active()


func has_transport() -> bool:
	return not transport_asset_id.is_empty()


func has_squad() -> bool:
	return not assigned_squad_id.is_empty()


func is_vacant_for_transport() -> bool:
	# A squad may remain assigned while the Stable changes from Walking to a
	# housed vehicle. Only an active expedition or an existing vehicle blocks
	# transport acquisition.
	return not is_active() and not has_transport()


func occupied_character_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var slot_keys: Array = formation_character_ids_by_slot.keys()
	slot_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	for raw_slot_id: Variant in slot_keys:
		var character_id := StringName(formation_character_ids_by_slot.get(raw_slot_id, ""))
		if not character_id.is_empty():
			result.append(character_id)
	return result


func clear_squad_assignment() -> void:
	assigned_squad_id = &""
	formation_character_ids_by_slot.clear()
	active_operation_id = &""
	status = STATUS_EMPTY
	is_walking = transport_asset_id.is_empty()
	if is_walking:
		transport_method_id = &"transport.walking"
	revision += 1


func clear_transport_assignment() -> void:
	transport_method_id = &"transport.walking"
	transport_asset_id = &""
	is_walking = true
	installed_fitting_ids.clear()
	formation_character_ids_by_slot.clear()
	status = STATUS_READY if has_squad() else STATUS_EMPTY
	revision += 1


# Compatibility helper for old callers that intended to clear the complete
# abstract bay. New gameplay normally clears only the squad or the transport.
func clear_assignment() -> void:
	assigned_squad_id = &""
	transport_method_id = &"transport.walking"
	transport_asset_id = &""
	is_walking = true
	formation_character_ids_by_slot.clear()
	installed_fitting_ids.clear()
	active_operation_id = &""
	status = STATUS_EMPTY
	revision += 1


func validate_state(campaign: CampaignState = null) -> Array[String]:
	var errors: Array[String] = []
	if bay_id.is_empty():
		errors.append("Stable housing record has no ID.")
	if bay_index < 0:
		errors.append("Stable housing record %s has a negative index." % bay_id)
	if stable_facility_id.is_empty():
		errors.append("Stable housing record %s is not linked to a constructed Stable." % bay_id)
	if status not in [STATUS_EMPTY, STATUS_READY, STATUS_TRAVELLING_OUT, STATUS_AT_MISSION, STATUS_RETURNING]:
		errors.append("Stable housing record %s has invalid status %s." % [bay_id, status])
	if status == STATUS_EMPTY and not assigned_squad_id.is_empty():
		errors.append("Empty Stable %s retains a squad." % bay_id)
	if status != STATUS_EMPTY and assigned_squad_id.is_empty():
		errors.append("Occupied Stable %s has no squad." % bay_id)
	if is_walking and not transport_asset_id.is_empty():
		errors.append("Walking Stable %s retains a transport asset." % bay_id)
	if not is_walking and transport_asset_id.is_empty():
		errors.append("Vehicle Stable %s has no exact transport asset." % bay_id)
	if campaign != null and campaign.stronghold != null and campaign.stronghold.get_facility(stable_facility_id) == null:
		errors.append("Stable housing record %s references missing facility %s." % [bay_id, stable_facility_id])
	var seen: Dictionary = {}
	for raw_character_id: Variant in formation_character_ids_by_slot.values():
		var character_id := StringName(raw_character_id)
		if character_id.is_empty():
			continue
		if seen.has(character_id):
			errors.append("Stable %s places character %s more than once." % [bay_id, character_id])
		seen[character_id] = true
		if campaign != null and campaign.get_character(character_id) == null:
			errors.append("Stable %s references missing character %s." % [bay_id, character_id])
		elif campaign != null and not assigned_squad_id.is_empty():
			var squad: CampaignSquadState = campaign.get_squad(assigned_squad_id)
			if squad != null and not squad.member_character_ids.has(character_id):
				errors.append("Stable %s places character %s outside its assigned squad." % [bay_id, character_id])
	return errors


func to_dictionary() -> Dictionary:
	var formation: Dictionary = {}
	for raw_slot_id: Variant in formation_character_ids_by_slot.keys():
		formation[String(raw_slot_id)] = String(formation_character_ids_by_slot.get(raw_slot_id, ""))
	return {
		"bay_id": String(bay_id),
		"bay_index": bay_index,
		"stable_facility_id": String(stable_facility_id),
		"assigned_squad_id": String(assigned_squad_id),
		"transport_method_id": String(transport_method_id),
		"transport_asset_id": String(transport_asset_id),
		"is_walking": is_walking,
		"formation_character_ids_by_slot": formation,
		"installed_fitting_ids": _name_array(installed_fitting_ids),
		"active_operation_id": String(active_operation_id),
		"status": String(status),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> StableBayState:
	var result := StableBayState.new()
	result.bay_id = StringName(data.get("bay_id", ""))
	result.bay_index = maxi(0, int(data.get("bay_index", 0)))
	result.stable_facility_id = StringName(data.get("stable_facility_id", ""))
	result.assigned_squad_id = StringName(data.get("assigned_squad_id", ""))
	result.transport_method_id = StringName(data.get("transport_method_id", "transport.walking"))
	result.transport_asset_id = StringName(data.get("transport_asset_id", ""))
	result.is_walking = bool(data.get("is_walking", result.transport_asset_id.is_empty()))
	var raw_formation: Variant = data.get("formation_character_ids_by_slot", {})
	if raw_formation is Dictionary:
		for raw_slot_id: Variant in (raw_formation as Dictionary).keys():
			var slot_id := StringName(raw_slot_id)
			var character_id := StringName((raw_formation as Dictionary).get(raw_slot_id, ""))
			if not slot_id.is_empty() and not character_id.is_empty():
				result.formation_character_ids_by_slot[slot_id] = character_id
	result.installed_fitting_ids = _name_array_from(data.get("installed_fitting_ids", []))
	result.active_operation_id = StringName(data.get("active_operation_id", ""))
	result.status = StringName(data.get("status", STATUS_EMPTY))
	result.revision = maxi(0, int(data.get("revision", 0)))
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
