class_name CampaignItemState
extends RefCounted

var item_id: StringName = &""
var definition_id: StringName = &""
var quantity: int = 1
var condition: float = 1.0
var location: CampaignItemLocationState = CampaignItemLocationState.new()
var persistent_modifiers: Dictionary = {}
var revision: int = 0


func _init(
		item_id_value: StringName = &"",
		definition_id_value: StringName = &"",
		quantity_value: int = 1,
		condition_value: float = 1.0,
		location_value: CampaignItemLocationState = null,
		persistent_modifiers_value: Dictionary = {}
) -> void:
	item_id = item_id_value
	definition_id = definition_id_value
	quantity = maxi(1, quantity_value)
	condition = clampf(condition_value, 0.0, 1.0)
	location = (
		location_value
		if location_value != null
		else CampaignItemLocationState.new()
	)
	persistent_modifiers = persistent_modifiers_value.duplicate(true)


func set_location(value: CampaignItemLocationState) -> void:
	if value == null:
		return
	location = value.clone()
	revision += 1


func clone() -> CampaignItemState:
	var cloned_location: CampaignItemLocationState = (
		location.clone() if location != null else CampaignItemLocationState.new()
	)
	var result: CampaignItemState = CampaignItemState.new(
		item_id,
		definition_id,
		quantity,
		condition,
		cloned_location,
		persistent_modifiers
	)
	result.revision = revision
	return result


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if item_id.is_empty():
		errors.append("Campaign item has no item ID.")
	if definition_id.is_empty():
		errors.append("Campaign item %s has no definition ID." % item_id)
	if quantity < 1:
		errors.append("Campaign item %s has an invalid quantity." % item_id)
	if condition < 0.0 or condition > 1.0:
		errors.append("Campaign item %s has an invalid condition." % item_id)
	if location == null:
		errors.append("Campaign item %s has no location." % item_id)
	else:
		errors.append_array(location.validate_state())
	return errors


func to_dictionary() -> Dictionary:
	var location_data: Dictionary = (
		location.to_dictionary()
		if location != null
		else CampaignItemLocationState.new().to_dictionary()
	)
	return {
		"item_id": String(item_id),
		"definition_id": String(definition_id),
		"quantity": quantity,
		"condition": condition,
		"location": location_data,
		"persistent_modifiers": persistent_modifiers.duplicate(true),
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> CampaignItemState:
	var location_data: Dictionary = {}
	var raw_location: Variant = data.get("location", {})
	if raw_location is Dictionary:
		location_data = raw_location as Dictionary
	var modifiers: Dictionary = (
		data.get("persistent_modifiers", {}) as Dictionary
	).duplicate(true)
	var result: CampaignItemState = CampaignItemState.new(
		StringName(data.get("item_id", data.get("instance_id", ""))),
		StringName(data.get("definition_id", "")),
		maxi(1, int(data.get("quantity", 1))),
		clampf(float(data.get("condition", 1.0)), 0.0, 1.0),
		CampaignItemLocationState.from_dictionary(location_data),
		modifiers
	)
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
