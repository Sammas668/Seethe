class_name MissionObjectiveDefinition
extends Resource

const KIND_EXTRACT_ITEMS: StringName = &"extract_items"
const KIND_EXTRACT_CAPTIVE: StringName = &"extract_captive"
const KIND_AVOID_CIVILIAN_DEATHS: StringName = &"avoid_civilian_deaths"
const KIND_EXTRACT_BEFORE_ROUND: StringName = &"extract_before_round"

@export var objective_id: StringName = &""
@export var display_name: String = "Mission objective"
@export_multiline var description: String = ""
@export var objective_kind: StringName = KIND_EXTRACT_ITEMS
@export var optional: bool = false
@export var hidden_until_revealed: bool = false
@export var qualifying_tags: Array[StringName] = []
@export var required_quantity: int = 1
@export var deadline_round: int = -1
@export_range(0.0, 1.0, 0.01) var minimum_condition: float = 0.0
@export var success_result_code: StringName = &"objective_completed"
@export var failure_result_code: StringName = &"objective_failed"


func matches_item(item: TacticalItemInstanceState) -> bool:
	if item == null or item.definition == null:
		return false
	if item.condition + 0.0001 < minimum_condition:
		return false
	for tag: StringName in qualifying_tags:
		if not item.definition.has_tag(tag):
			return false
	return true


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if objective_id.is_empty():
		errors.append("Mission objective has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Mission objective %s has no display name." % objective_id)
	if objective_kind not in [
		KIND_EXTRACT_ITEMS,
		KIND_EXTRACT_CAPTIVE,
		KIND_AVOID_CIVILIAN_DEATHS,
		KIND_EXTRACT_BEFORE_ROUND,
	]:
		errors.append("Mission objective %s has unknown kind %s." % [objective_id, objective_kind])
	if required_quantity < 1:
		errors.append("Mission objective %s requires fewer than one result." % objective_id)
	if objective_kind in [KIND_EXTRACT_ITEMS, KIND_EXTRACT_CAPTIVE] and qualifying_tags.is_empty():
		errors.append("Mission objective %s has no qualifying tags." % objective_id)
	if objective_kind == KIND_EXTRACT_BEFORE_ROUND and deadline_round < 1:
		errors.append("Mission objective %s has no valid deadline round." % objective_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"objective_id": String(objective_id),
		"display_name": display_name,
		"description": description,
		"objective_kind": String(objective_kind),
		"optional": optional,
		"hidden_until_revealed": hidden_until_revealed,
		"qualifying_tags": _strings(qualifying_tags),
		"required_quantity": required_quantity,
		"deadline_round": deadline_round,
		"minimum_condition": minimum_condition,
		"success_result_code": String(success_result_code),
		"failure_result_code": String(failure_result_code),
	}


static func from_dictionary(data: Dictionary) -> MissionObjectiveDefinition:
	var result := MissionObjectiveDefinition.new()
	result.objective_id = StringName(data.get("objective_id", ""))
	result.display_name = String(data.get("display_name", "Mission objective"))
	result.description = String(data.get("description", ""))
	result.objective_kind = StringName(data.get("objective_kind", KIND_EXTRACT_ITEMS))
	result.optional = bool(data.get("optional", false))
	result.hidden_until_revealed = bool(data.get("hidden_until_revealed", false))
	for raw_tag: Variant in data.get("qualifying_tags", []):
		result.qualifying_tags.append(StringName(raw_tag))
	result.required_quantity = maxi(1, int(data.get("required_quantity", 1)))
	result.deadline_round = int(data.get("deadline_round", -1))
	result.minimum_condition = clampf(float(data.get("minimum_condition", 0.0)), 0.0, 1.0)
	result.success_result_code = StringName(data.get("success_result_code", "objective_completed"))
	result.failure_result_code = StringName(data.get("failure_result_code", "objective_failed"))
	return result


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
