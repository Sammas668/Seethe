class_name SquadTransportDefinition
extends RefCounted

var id: StringName = &""
var display_name: String = "Transport"
var description: String = "Mission transport."
var research_unlock_id: StringName = &""
var acquisition_costs: Dictionary = {}
var passenger_capacity: int = 0
var strategic_speed_multiplier: float = 1.0
var cargo_capacity_lb: float = 0.0
var journey_notoriety_modifier_percent: int = 0
var captive_capacity: int = 0
var cage_anchor_capacity: int = 0
var monster_capacity: int = 0
var siege_anchor_capacity: int = 0
var oversized_cargo_capacity: int = 0
var stable_bays_required: int = 1
# Legacy alias retained for old content and callers.
var stable_space_required: int = 1
var terrain_speed_modifiers: Dictionary = {}
var impassable_terrain_tags: Array[StringName] = []
var deployment_layout_id: StringName = &"layout.walking"
var fitting_slot_types: Array[StringName] = []
var icon_path: String = ""
var artwork_path: String = ""
var is_walking: bool = false

# Legacy definition fields no longer used.
var maximum_condition: int = 100
var repair_profile_id: StringName = &""


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Transport definition has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Transport %s has no display name." % id)
	if passenger_capacity < 0:
		errors.append("Transport %s has negative passenger capacity." % id)
	if strategic_speed_multiplier <= 0.0:
		errors.append("Transport %s has an invalid speed multiplier." % id)
	if cargo_capacity_lb < 0.0:
		errors.append("Transport %s has negative cargo capacity." % id)
	if stable_bays_required < 0:
		errors.append("Transport %s has negative Stable bay use." % id)
	if not is_walking and stable_bays_required <= 0:
		errors.append("Persistent transport %s requires no Stable bay." % id)
	for capacity: int in [captive_capacity, cage_anchor_capacity, monster_capacity, siege_anchor_capacity, oversized_cargo_capacity]:
		if capacity < 0:
			errors.append("Transport %s has negative specialist capacity." % id)
	return errors


func terrain_multiplier(terrain_tag: StringName) -> float:
	return maxf(0.05, float(terrain_speed_modifiers.get(terrain_tag, 1.0)))


func to_dictionary() -> Dictionary:
	var impassable: Array[String] = []
	for terrain_tag: StringName in impassable_terrain_tags:
		impassable.append(String(terrain_tag))
	var slots: Array[String] = []
	for slot_type: StringName in fitting_slot_types:
		slots.append(String(slot_type))
	return {
		"id": String(id),
		"display_name": display_name,
		"description": description,
		"research_unlock_id": String(research_unlock_id),
		"acquisition_costs": acquisition_costs.duplicate(true),
		"passenger_capacity": passenger_capacity,
		"strategic_speed_multiplier": strategic_speed_multiplier,
		"cargo_capacity_lb": cargo_capacity_lb,
		"journey_notoriety_modifier_percent": journey_notoriety_modifier_percent,
		"captive_capacity": captive_capacity,
		"cage_anchor_capacity": cage_anchor_capacity,
		"monster_capacity": monster_capacity,
		"siege_anchor_capacity": siege_anchor_capacity,
		"oversized_cargo_capacity": oversized_cargo_capacity,
		"stable_bays_required": stable_bays_required,
		"stable_space_required": stable_bays_required,
		"terrain_speed_modifiers": terrain_speed_modifiers.duplicate(true),
		"impassable_terrain_tags": impassable,
		"deployment_layout_id": String(deployment_layout_id),
		"fitting_slot_types": slots,
		"icon_path": icon_path,
		"artwork_path": artwork_path,
		"is_walking": is_walking,
	}


static func from_dictionary(data: Dictionary) -> SquadTransportDefinition:
	var result := SquadTransportDefinition.new()
	result.id = StringName(data.get("id", ""))
	result.display_name = String(data.get("display_name", "Transport"))
	result.description = String(data.get("description", "Mission transport."))
	result.research_unlock_id = StringName(data.get("research_unlock_id", ""))
	var raw_costs: Variant = data.get("acquisition_costs", {})
	result.acquisition_costs = (raw_costs as Dictionary).duplicate(true) if raw_costs is Dictionary else {}
	result.passenger_capacity = maxi(0, int(data.get("passenger_capacity", 0)))
	result.strategic_speed_multiplier = maxf(0.01, float(data.get("strategic_speed_multiplier", 1.0)))
	result.cargo_capacity_lb = maxf(0.0, float(data.get("cargo_capacity_lb", 0.0)))
	result.journey_notoriety_modifier_percent = int(data.get("journey_notoriety_modifier_percent", 0))
	result.captive_capacity = maxi(0, int(data.get("captive_capacity", 0)))
	result.cage_anchor_capacity = maxi(0, int(data.get("cage_anchor_capacity", 0)))
	result.monster_capacity = maxi(0, int(data.get("monster_capacity", 0)))
	result.siege_anchor_capacity = maxi(0, int(data.get("siege_anchor_capacity", 0)))
	result.oversized_cargo_capacity = maxi(0, int(data.get("oversized_cargo_capacity", 0)))
	result.stable_bays_required = maxi(0, int(data.get("stable_bays_required", data.get("stable_space_required", 1))))
	result.stable_space_required = result.stable_bays_required
	var raw_terrain: Variant = data.get("terrain_speed_modifiers", {})
	result.terrain_speed_modifiers = (raw_terrain as Dictionary).duplicate(true) if raw_terrain is Dictionary else {}
	var raw_impassable: Variant = data.get("impassable_terrain_tags", [])
	if raw_impassable is Array:
		for raw_tag: Variant in raw_impassable as Array:
			var terrain_tag := StringName(raw_tag)
			if not terrain_tag.is_empty():
				result.impassable_terrain_tags.append(terrain_tag)
	result.deployment_layout_id = StringName(data.get("deployment_layout_id", "layout.walking"))
	var raw_slots: Variant = data.get("fitting_slot_types", [])
	if raw_slots is Array:
		for raw_slot: Variant in raw_slots as Array:
			var slot_type := StringName(raw_slot)
			if not slot_type.is_empty():
				result.fitting_slot_types.append(slot_type)
	result.icon_path = String(data.get("icon_path", ""))
	result.artwork_path = String(data.get("artwork_path", ""))
	result.is_walking = bool(data.get("is_walking", false))
	result.maximum_condition = 100
	result.repair_profile_id = &""
	return result
