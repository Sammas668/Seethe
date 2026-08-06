class_name StrategicReservationState
extends RefCounted

const PURPOSE_DEPLOYMENT: StringName = &"deployment"
const PURPOSE_CONSTRUCTION_INPUT: StringName = &"construction_input"
const PURPOSE_UPGRADE_INPUT: StringName = &"upgrade_input"
const PURPOSE_PRODUCTION_INPUT: StringName = &"production_input"
const PURPOSE_RESEARCH_INPUT: StringName = &"research_input"
const PURPOSE_MARKET_COMMISSION: StringName = &"market_commission"

const STATUS_ACTIVE: StringName = &"active"
const STATUS_RELEASED: StringName = &"released"
const STATUS_CANCELLED: StringName = &"cancelled"

var reservation_id: StringName = &""
var purpose: StringName = PURPOSE_DEPLOYMENT
var owner_id: StringName = &""
var mission_instance_id: StringName = &""
var display_name: String = "Reserved operation"
var character_ids: Array[StringName] = []
var item_ids: Array[StringName] = []
# Fungible resource quantities and expected output Storage Space reserved by
# construction, Production and future Research projects. Reservations are locks,
# not second physical locations.
var resource_quantities: Dictionary = {}
var output_storage_space: int = 0
var created_tick: int = 0
var released_tick: int = -1
var status: StringName = STATUS_ACTIVE
var revision: int = 0


func is_active() -> bool:
	return status == STATUS_ACTIVE


func contains_character(character_id: StringName) -> bool:
	return is_active() and character_ids.has(character_id)


func contains_item(item_id: StringName) -> bool:
	return is_active() and item_ids.has(item_id)


func release(tick: int, cancelled: bool = false) -> bool:
	if not is_active():
		return false
	status = STATUS_CANCELLED if cancelled else STATUS_RELEASED
	released_tick = maxi(created_tick, tick)
	revision += 1
	return true


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if reservation_id.is_empty():
		errors.append("Strategic reservation has no ID.")
	if purpose.is_empty():
		errors.append("Strategic reservation %s has no purpose." % reservation_id)
	if owner_id.is_empty():
		errors.append("Strategic reservation %s has no owner." % reservation_id)
	if status not in [STATUS_ACTIVE, STATUS_RELEASED, STATUS_CANCELLED]:
		errors.append(
			"Strategic reservation %s has invalid status %s."
			% [reservation_id, status]
		)
	if created_tick < 0:
		errors.append("Strategic reservation %s has an invalid creation tick." % reservation_id)
	if is_active() and released_tick >= 0:
		errors.append("Active strategic reservation %s has a release tick." % reservation_id)
	if not is_active() and released_tick < created_tick:
		errors.append("Closed strategic reservation %s has an invalid release tick." % reservation_id)
	if purpose == PURPOSE_DEPLOYMENT and character_ids.is_empty():
		errors.append("Deployment reservation %s has no characters." % reservation_id)
	var seen_characters: Dictionary = {}
	for character_id: StringName in character_ids:
		if character_id.is_empty():
			errors.append("Strategic reservation %s contains an empty character ID." % reservation_id)
		elif seen_characters.has(character_id):
			errors.append("Strategic reservation %s repeats character %s." % [reservation_id, character_id])
		seen_characters[character_id] = true
	for raw_resource_id: Variant in resource_quantities.keys():
		var resource_id := StringName(raw_resource_id)
		var amount: int = int(resource_quantities[raw_resource_id])
		if resource_id.is_empty() or amount <= 0:
			errors.append("Strategic reservation %s has an invalid resource quantity." % reservation_id)
	if output_storage_space < 0:
		errors.append("Strategic reservation %s has negative output Storage Space." % reservation_id)
	var seen_items: Dictionary = {}
	for item_id: StringName in item_ids:
		if item_id.is_empty():
			errors.append("Strategic reservation %s contains an empty item ID." % reservation_id)
		elif seen_items.has(item_id):
			errors.append("Strategic reservation %s repeats item %s." % [reservation_id, item_id])
		seen_items[item_id] = true
	return errors


func to_dictionary() -> Dictionary:
	return {
		"reservation_id": String(reservation_id),
		"purpose": String(purpose),
		"owner_id": String(owner_id),
		"mission_instance_id": String(mission_instance_id),
		"display_name": display_name,
		"character_ids": _name_array(character_ids),
		"item_ids": _name_array(item_ids),
		"resource_quantities": resource_quantities.duplicate(true),
		"output_storage_space": output_storage_space,
		"created_tick": created_tick,
		"released_tick": released_tick,
		"status": String(status),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> StrategicReservationState:
	var result := StrategicReservationState.new()
	result.reservation_id = StringName(data.get("reservation_id", ""))
	result.purpose = StringName(data.get("purpose", PURPOSE_DEPLOYMENT))
	result.owner_id = StringName(data.get("owner_id", ""))
	result.mission_instance_id = StringName(data.get("mission_instance_id", ""))
	result.display_name = String(data.get("display_name", "Reserved operation"))
	result.character_ids = _name_array_from(data.get("character_ids", []))
	result.item_ids = _name_array_from(data.get("item_ids", []))
	var raw_resources: Variant = data.get("resource_quantities", {})
	if raw_resources is Dictionary:
		for raw_id: Variant in (raw_resources as Dictionary).keys():
			var resource_id := StringName(raw_id)
			var amount: int = maxi(0, int((raw_resources as Dictionary)[raw_id]))
			if not resource_id.is_empty() and amount > 0:
				result.resource_quantities[resource_id] = amount
	result.output_storage_space = maxi(0, int(data.get("output_storage_space", 0)))
	result.created_tick = maxi(0, int(data.get("created_tick", 0)))
	result.released_tick = int(data.get("released_tick", -1))
	result.status = StringName(data.get("status", STATUS_ACTIVE))
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
