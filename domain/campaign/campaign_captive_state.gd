class_name CampaignCaptiveState
extends RefCounted

const STATUS_INCOMING: StringName = &"incoming"
const STATUS_HELD: StringName = &"held"
const STATUS_RANSOMED: StringName = &"ransomed"
const STATUS_RELEASED: StringName = &"released"
const STATUS_DEAD: StringName = &"dead"
const STATUS_RESCUED: StringName = &"rescued"
const STATUS_ESCAPED: StringName = &"escaped"
const STATUS_TRANSFERRED: StringName = &"transferred"
const STATUS_CONVERTED: StringName = &"converted"

var captive_id: StringName = &""
var source_character_id: StringName = &""
var source_definition_id: StringName = &""
var display_name: String = ""
var identity_known: bool = false
var faction_id: StringName = &""
var troop_type_id: StringName = &""
var level: int = 1

var current_hp: int = 0
var maximum_hp: int = 1
var nonlethal_damage: int = 0
var lethal_recovery_units: int = 0
var nonlethal_recovery_units: int = 0
var condition_ids: Array[StringName] = []
var injury_entries: Array[String] = []

var equipment_item_ids: Array[StringName] = []
var restraint_item_id: StringName = &""
var containment_profile_id: StringName = &"containment.standard_humanoid"
var containment_tags: Array[StringName] = [&"humanoid", &"ordinary_cell"]
var cell_cost: int = 1

var captured_mission_id: StringName = &""
var captor_character_id: StringName = &""
var capture_location_label: String = "Unknown location"
var source_region_id: StringName = &""
var source_subregion_id: StringName = &""
var captured_at_tick: int = 0
var admitted_at_tick: int = -1
var assigned_prison_id: StringName = &""
var holding_location_id: StringName = &"stronghold.awaiting_admission"

var ransom_allowed: bool = false
var ransom_value: int = 0
var ransom_faction_id: StringName = &""
var release_allowed: bool = true
var release_notoriety_delta: int = 0
var available_action_ids: Array[StringName] = [&"release"]
# Stage 5.4C authored interrogation is a one-time knowledge action. Captives
# remain individual custody records and are not converted into generic Intel.
var interrogation_completed: bool = false
var interrogation_result_ids: Array[StringName] = []

var status: StringName = STATUS_INCOMING
var history_entries: Array[String] = []
var revision: int = 0


func is_active_custody() -> bool:
	return status in [STATUS_INCOMING, STATUS_HELD]


func is_incoming() -> bool:
	return status == STATUS_INCOMING


func is_held() -> bool:
	return status == STATUS_HELD


func is_living() -> bool:
	return status != STATUS_DEAD and current_hp > 0


func days_held(current_tick: int) -> int:
	if admitted_at_tick < 0:
		return 0
	return maxi(0, current_tick - admitted_at_tick) / 1440


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if captive_id.is_empty():
		errors.append("Campaign captive has no ID.")
	if source_character_id.is_empty():
		errors.append("Campaign captive %s has no source character." % captive_id)
	if source_definition_id.is_empty():
		errors.append("Campaign captive %s has no source definition." % captive_id)
	if display_name.strip_edges().is_empty():
		errors.append("Campaign captive %s has no display name." % captive_id)
	if captured_mission_id.is_empty():
		errors.append("Campaign captive %s has no capture mission." % captive_id)
	if holding_location_id.is_empty():
		errors.append("Campaign captive %s has no holding location." % captive_id)
	if level <= 0:
		errors.append("Campaign captive %s has an invalid level." % captive_id)
	if maximum_hp <= 0 or current_hp < 0 or current_hp > maximum_hp:
		errors.append("Campaign captive %s has invalid persistent health." % captive_id)
	if nonlethal_damage < 0:
		errors.append("Campaign captive %s has negative nonlethal damage." % captive_id)
	if cell_cost <= 0:
		errors.append("Campaign captive %s has an invalid cell cost." % captive_id)
	if ransom_value < 0:
		errors.append("Campaign captive %s has a negative ransom value." % captive_id)
	if status not in [
		STATUS_INCOMING,
		STATUS_HELD,
		STATUS_RANSOMED,
		STATUS_RELEASED,
		STATUS_DEAD,
		STATUS_RESCUED,
		STATUS_ESCAPED,
		STATUS_TRANSFERRED,
		STATUS_CONVERTED,
	]:
		errors.append("Campaign captive %s has invalid status %s." % [captive_id, status])
	if status == STATUS_HELD and assigned_prison_id.is_empty():
		errors.append("Held captive %s has no assigned Prison." % captive_id)
	if status == STATUS_INCOMING and not assigned_prison_id.is_empty():
		errors.append("Incoming captive %s cannot already occupy a Prison." % captive_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"captive_id": String(captive_id),
		"source_character_id": String(source_character_id),
		"source_definition_id": String(source_definition_id),
		"display_name": display_name,
		"identity_known": identity_known,
		"faction_id": String(faction_id),
		"troop_type_id": String(troop_type_id),
		"level": level,
		"current_hp": current_hp,
		"maximum_hp": maximum_hp,
		"nonlethal_damage": nonlethal_damage,
		"lethal_recovery_units": lethal_recovery_units,
		"nonlethal_recovery_units": nonlethal_recovery_units,
		"condition_ids": _strings(condition_ids),
		"injury_entries": injury_entries.duplicate(),
		"equipment_item_ids": _strings(equipment_item_ids),
		"restraint_item_id": String(restraint_item_id),
		"containment_profile_id": String(containment_profile_id),
		"containment_tags": _strings(containment_tags),
		"cell_cost": cell_cost,
		"captured_mission_id": String(captured_mission_id),
		"captor_character_id": String(captor_character_id),
		"capture_location_label": capture_location_label,
		"source_region_id": String(source_region_id),
		"source_subregion_id": String(source_subregion_id),
		"captured_at_tick": captured_at_tick,
		"admitted_at_tick": admitted_at_tick,
		"assigned_prison_id": String(assigned_prison_id),
		"holding_location_id": String(holding_location_id),
		"ransom_allowed": ransom_allowed,
		"ransom_value": ransom_value,
		"ransom_faction_id": String(ransom_faction_id),
		"release_allowed": release_allowed,
		"release_notoriety_delta": release_notoriety_delta,
		"available_action_ids": _strings(available_action_ids),
		"interrogation_completed": interrogation_completed,
		"interrogation_result_ids": _strings(interrogation_result_ids),
		"status": String(status),
		"history_entries": history_entries.duplicate(),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> CampaignCaptiveState:
	var result := CampaignCaptiveState.new()
	result.captive_id = StringName(data.get("captive_id", ""))
	result.source_character_id = StringName(data.get("source_character_id", ""))
	result.source_definition_id = StringName(data.get("source_definition_id", ""))
	result.display_name = String(data.get("display_name", ""))
	result.identity_known = bool(data.get("identity_known", false))
	result.faction_id = StringName(data.get("faction_id", ""))
	result.troop_type_id = StringName(data.get("troop_type_id", data.get("source_definition_id", "")))
	result.level = maxi(1, int(data.get("level", 1)))
	result.current_hp = maxi(0, int(data.get("current_hp", 0)))
	result.maximum_hp = maxi(result.current_hp, int(data.get("maximum_hp", maxi(1, result.current_hp))))
	result.nonlethal_damage = maxi(0, int(data.get("nonlethal_damage", 0)))
	result.lethal_recovery_units = maxi(0, int(data.get("lethal_recovery_units", 0)))
	result.nonlethal_recovery_units = maxi(0, int(data.get("nonlethal_recovery_units", 0)))
	result.restraint_item_id = StringName(data.get("restraint_item_id", ""))
	result.captured_mission_id = StringName(data.get("captured_mission_id", ""))
	result.captor_character_id = StringName(data.get("captor_character_id", ""))
	result.capture_location_label = String(data.get("capture_location_label", "Unknown location"))
	result.source_region_id = StringName(data.get("source_region_id", ""))
	result.source_subregion_id = StringName(data.get("source_subregion_id", ""))
	result.captured_at_tick = maxi(0, int(data.get("captured_at_tick", 0)))
	result.admitted_at_tick = int(data.get("admitted_at_tick", -1))
	result.assigned_prison_id = StringName(data.get("assigned_prison_id", ""))
	result.holding_location_id = StringName(data.get("holding_location_id", "stronghold.awaiting_admission"))
	result.containment_profile_id = StringName(data.get("containment_profile_id", "containment.standard_humanoid"))
	result.cell_cost = maxi(1, int(data.get("cell_cost", 1)))
	result.ransom_allowed = bool(data.get("ransom_allowed", false))
	result.ransom_value = maxi(0, int(data.get("ransom_value", 0)))
	result.ransom_faction_id = StringName(data.get("ransom_faction_id", ""))
	result.release_allowed = bool(data.get("release_allowed", true))
	result.release_notoriety_delta = int(data.get("release_notoriety_delta", 0))
	result.status = StringName(data.get("status", ""))
	if result.status.is_empty():
		# Legacy temporary-holding captives had already reached the stronghold.
		result.status = (
			STATUS_INCOMING
			if String(result.holding_location_id).begins_with("return_transit.")
			else STATUS_HELD
		)
	if result.status == STATUS_HELD and result.assigned_prison_id.is_empty():
		# Repository validation runs before CampaignSession can execute migrations.
		# Keep legacy temporary-holding captives as incoming until the Prison service
		# transactionally assigns them to a real constructed Prison.
		result.status = STATUS_INCOMING
		result.holding_location_id = &"stronghold.awaiting_admission"
	result.condition_ids = _names(data.get("condition_ids", []))
	result.injury_entries = _plain_strings(data.get("injury_entries", []))
	result.equipment_item_ids = _names(data.get("equipment_item_ids", []))
	result.containment_tags = _names(data.get("containment_tags", [&"humanoid", &"ordinary_cell"]))
	result.available_action_ids = _names(data.get("available_action_ids", [&"release"]))
	result.interrogation_completed = bool(data.get("interrogation_completed", false))
	result.interrogation_result_ids = _names(data.get("interrogation_result_ids", []))
	result.history_entries = _plain_strings(data.get("history_entries", []))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for raw_value: Variant in value as Array:
			result.append(StringName(raw_value))
	return result


static func _plain_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw_value: Variant in value as Array:
			result.append(String(raw_value))
	return result
