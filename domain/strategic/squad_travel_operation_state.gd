class_name SquadTravelOperationState
extends RefCounted

const STATUS_TRAVELLING: StringName = &"travelling"
const STATUS_ARRIVED: StringName = &"arrived"
const STATUS_IN_TACTICAL: StringName = &"in_tactical"
const STATUS_RETURNING: StringName = &"returning"
const STATUS_RESOLVED: StringName = &"resolved"
const STATUS_CANCELLED: StringName = &"cancelled"

var operation_id: StringName = &""
var mission_instance_id: StringName = &""
var route_plan: SquadRoutePlan
var visibility_snapshot: SquadVisibilitySnapshot
var exposure_entries: Array[TravelExposureEntry] = []
var character_ids: Array[StringName] = []
var reserved_item_ids: Array[StringName] = []
# Departure-time desired equipment plan for each deployed character. This is
# separate from exact item reservations so consumed or lost instances can be
# replaced with equivalent Storage items after the squad returns.
var desired_loadout_entries_by_character_id: Dictionary = {}
var campaign_squad_id: StringName = &""
var stable_bay_id: StringName = &""
var formation_character_ids_by_slot: Dictionary = {}
var transport_asset_id: StringName = &""
var transport_id: StringName = &"" # Transport definition ID; walking is transport.walking.
var transport_instance_ids: Array[StringName] = []
var transport_display_name: String = ""
var transport_assigned_count: int = 0
var transport_passenger_capacity: int = 0
var transport_strategic_speed_multiplier: float = 1.0
var transport_terrain_multiplier: float = 1.0
var transport_cargo_capacity_lb: float = 0.0
var transport_notoriety_modifier_percent: int = 0
var transport_stable_space: int = 0
var transport_is_walking: bool = false
# Legacy fields are retained only for save compatibility. No route-viability rule remains.
var transport_viability_label: String = ""
var transport_viability_explanation: String = ""
var origin_site_id: StringName = &""
var destination_site_id: StringName = &""
var started_tick: int = 0
var arrival_tick: int = 0
var return_started_tick: int = 0
var return_arrival_tick: int = 0
var status: StringName = STATUS_TRAVELLING
var arrival_event_id: StringName = &""
var last_resolved_arrival_event_id: StringName = &""
var tactical_setup_registration_id: StringName = &""
var reservation_id: StringName = &""
var revision: int = 0


func is_active() -> bool:
	return status in [STATUS_TRAVELLING, STATUS_ARRIVED, STATUS_IN_TACTICAL, STATUS_RETURNING]


func map_position_at_time(campaign_time: float) -> Vector2:
	return route_plan.map_position_at_time(campaign_time) if route_plan != null else Vector2.ZERO


func desired_loadout_entries(character_id: StringName) -> Array:
	var raw: Variant = desired_loadout_entries_by_character_id.get(
		character_id,
		desired_loadout_entries_by_character_id.get(String(character_id), [])
	)
	return (raw as Array).duplicate(true) if raw is Array else []


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if operation_id.is_empty():
		errors.append("Squad travel operation has no ID.")
	if mission_instance_id.is_empty():
		errors.append("Squad travel operation %s has no mission." % operation_id)
	if route_plan == null:
		errors.append("Squad travel operation %s has no route." % operation_id)
	else:
		errors.append_array(route_plan.validate_state())
	if visibility_snapshot == null:
		errors.append("Squad travel operation %s has no visibility snapshot." % operation_id)
	else:
		errors.append_array(visibility_snapshot.validate_state())
	if character_ids.is_empty():
		errors.append("Squad travel operation %s has no characters." % operation_id)
	if transport_id.is_empty():
		errors.append("Squad travel operation %s has no transport." % operation_id)
	if transport_strategic_speed_multiplier <= 0.0 or transport_terrain_multiplier <= 0.0:
		errors.append("Squad travel operation %s has an invalid transport speed." % operation_id)
	if not transport_is_walking and transport_instance_ids.size() != transport_assigned_count:
		errors.append("Squad travel operation %s does not retain its exact assigned transports." % operation_id)
	if transport_cargo_capacity_lb < 0.0:
		errors.append("Squad travel operation %s has negative cargo capacity." % operation_id)
	if status not in [STATUS_TRAVELLING, STATUS_ARRIVED, STATUS_IN_TACTICAL, STATUS_RETURNING, STATUS_RESOLVED, STATUS_CANCELLED]:
		errors.append("Squad travel operation %s has invalid status %s." % [operation_id, status])
	if is_active() and reservation_id.is_empty():
		errors.append(
			"Active squad travel operation %s has no deployment reservation."
			% operation_id
		)
	for entry: TravelExposureEntry in exposure_entries:
		if entry != null:
			errors.append_array(entry.validate_state())
	return errors


func to_dictionary() -> Dictionary:
	var serialized_entries: Array[Dictionary] = []
	for entry: TravelExposureEntry in exposure_entries:
		if entry != null:
			serialized_entries.append(entry.to_dictionary())
	return {
		"operation_id": String(operation_id),
		"mission_instance_id": String(mission_instance_id),
		"route_plan": route_plan.to_dictionary() if route_plan != null else {},
		"visibility_snapshot": visibility_snapshot.to_dictionary() if visibility_snapshot != null else {},
		"exposure_entries": serialized_entries,
		"character_ids": _name_array(character_ids),
		"reserved_item_ids": _name_array(reserved_item_ids),
		"desired_loadout_entries_by_character_id": desired_loadout_entries_by_character_id.duplicate(true),
		"campaign_squad_id": String(campaign_squad_id),
		"stable_bay_id": String(stable_bay_id),
		"formation_character_ids_by_slot": _string_dictionary(formation_character_ids_by_slot),
		"transport_asset_id": String(transport_asset_id),
		"transport_id": String(transport_id),
		"transport_instance_ids": _name_array(transport_instance_ids),
		"transport_display_name": transport_display_name,
		"transport_assigned_count": transport_assigned_count,
		"transport_passenger_capacity": transport_passenger_capacity,
		"transport_strategic_speed_multiplier": transport_strategic_speed_multiplier,
		"transport_terrain_multiplier": transport_terrain_multiplier,
		"transport_travel_time_multiplier": transport_terrain_multiplier / maxf(0.01, transport_strategic_speed_multiplier),
		"transport_cargo_capacity_lb": transport_cargo_capacity_lb,
		"transport_notoriety_modifier_percent": transport_notoriety_modifier_percent,
		"transport_stable_space": transport_stable_space,
		"transport_is_walking": transport_is_walking,
		"transport_viability_label": transport_viability_label,
		"transport_viability_explanation": transport_viability_explanation,
		"origin_site_id": String(origin_site_id),
		"destination_site_id": String(destination_site_id),
		"started_tick": started_tick,
		"arrival_tick": arrival_tick,
		"return_started_tick": return_started_tick,
		"return_arrival_tick": return_arrival_tick,
		"status": String(status),
		"arrival_event_id": String(arrival_event_id),
		"last_resolved_arrival_event_id": String(last_resolved_arrival_event_id),
		"tactical_setup_registration_id": String(tactical_setup_registration_id),
		"reservation_id": String(reservation_id),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> SquadTravelOperationState:
	var result := SquadTravelOperationState.new()
	result.operation_id = StringName(data.get("operation_id", ""))
	result.mission_instance_id = StringName(data.get("mission_instance_id", ""))
	var raw_route: Variant = data.get("route_plan", {})
	if raw_route is Dictionary and not (raw_route as Dictionary).is_empty():
		result.route_plan = SquadRoutePlan.from_dictionary(raw_route as Dictionary)
	var raw_visibility: Variant = data.get("visibility_snapshot", {})
	if raw_visibility is Dictionary and not (raw_visibility as Dictionary).is_empty():
		result.visibility_snapshot = SquadVisibilitySnapshot.from_dictionary(raw_visibility as Dictionary)
	var raw_entries: Variant = data.get("exposure_entries", [])
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries as Array:
			if raw_entry is Dictionary:
				result.exposure_entries.append(TravelExposureEntry.from_dictionary(raw_entry as Dictionary))
	result.character_ids = _name_array_from(data.get("character_ids", []))
	result.reserved_item_ids = _name_array_from(data.get("reserved_item_ids", []))
	var raw_desired_loadouts: Variant = data.get("desired_loadout_entries_by_character_id", {})
	if raw_desired_loadouts is Dictionary:
		result.desired_loadout_entries_by_character_id = (
			(raw_desired_loadouts as Dictionary).duplicate(true)
		)
	result.campaign_squad_id = StringName(data.get("campaign_squad_id", ""))
	result.stable_bay_id = StringName(data.get("stable_bay_id", ""))
	var raw_formation: Variant = data.get("formation_character_ids_by_slot", {})
	if raw_formation is Dictionary:
		for raw_slot_id: Variant in (raw_formation as Dictionary).keys():
			result.formation_character_ids_by_slot[StringName(raw_slot_id)] = StringName((raw_formation as Dictionary).get(raw_slot_id, ""))
	result.transport_asset_id = StringName(data.get("transport_asset_id", ""))
	result.transport_id = StringName(data.get("transport_id", "transport.walking"))
	result.transport_instance_ids = _name_array_from(data.get("transport_instance_ids", []))
	result.transport_display_name = String(data.get("transport_display_name", "Walking"))
	result.transport_assigned_count = maxi(0, int(data.get("transport_assigned_count", result.transport_instance_ids.size())))
	result.transport_passenger_capacity = maxi(0, int(data.get("transport_passenger_capacity", 0)))
	var legacy_time_multiplier: float = maxf(0.01, float(data.get("transport_travel_time_multiplier", 1.0)))
	result.transport_strategic_speed_multiplier = maxf(0.01, float(data.get("transport_strategic_speed_multiplier", 1.0 / legacy_time_multiplier)))
	result.transport_terrain_multiplier = maxf(0.01, float(data.get("transport_terrain_multiplier", 1.0)))
	result.transport_cargo_capacity_lb = maxf(0.0, float(data.get("transport_cargo_capacity_lb", 0.0)))
	result.transport_notoriety_modifier_percent = int(data.get("transport_notoriety_modifier_percent", 0))
	result.transport_stable_space = maxi(0, int(data.get("transport_stable_space", 0)))
	result.transport_is_walking = bool(data.get("transport_is_walking", result.transport_id == &"transport.walking"))
	result.transport_viability_label = String(data.get("transport_viability_label", "GOOD"))
	result.transport_viability_explanation = String(data.get("transport_viability_explanation", "Compatible with the route."))
	result.origin_site_id = StringName(data.get("origin_site_id", ""))
	result.destination_site_id = StringName(data.get("destination_site_id", ""))
	result.started_tick = maxi(0, int(data.get("started_tick", 0)))
	result.arrival_tick = maxi(result.started_tick, int(data.get("arrival_tick", result.started_tick)))
	result.return_started_tick = maxi(0, int(data.get("return_started_tick", 0)))
	result.return_arrival_tick = maxi(result.return_started_tick, int(data.get("return_arrival_tick", result.return_started_tick)))
	result.status = StringName(data.get("status", STATUS_TRAVELLING))
	result.arrival_event_id = StringName(data.get("arrival_event_id", ""))
	result.last_resolved_arrival_event_id = StringName(data.get("last_resolved_arrival_event_id", ""))
	result.tactical_setup_registration_id = StringName(data.get("tactical_setup_registration_id", ""))
	result.reservation_id = StringName(data.get("reservation_id", ""))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result


static func _string_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key: Variant in values.keys():
		result[String(raw_key)] = String(values.get(raw_key, ""))
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
