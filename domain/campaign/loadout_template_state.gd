class_name LoadoutTemplateState
extends RefCounted

const POLICY_STRICT: StringName = &"strict"
const POLICY_EQUIVALENT: StringName = &"equivalent"
const POLICY_BEST_AVAILABLE: StringName = &"best_available"
const POLICY_CONSERVE_VALUABLE: StringName = &"conserve_valuable"

var template_id: StringName = &""
var display_name: String = "Unnamed Loadout"
var description: String = ""
var is_authored: bool = false
var source_definition_id: StringName = &""
var allowed_troop_type_ids: Array[StringName] = []
var allowed_role_tags: Array[StringName] = []
var rules: Array[LoadoutItemRule] = []
var weight_limit_policy: StringName = &"respect_capacity"
var substitution_policy: StringName = POLICY_CONSERVE_VALUABLE
var template_version: int = 1


func clone() -> LoadoutTemplateState:
	return LoadoutTemplateState.from_dictionary(to_dictionary())


func rules_for_container(container_id: StringName) -> Array[LoadoutItemRule]:
	var result: Array[LoadoutItemRule] = []
	for rule: LoadoutItemRule in rules:
		if rule != null and rule.preferred_container_id == container_id:
			result.append(rule)
	return result


func is_compatible_with(template: CharacterTemplateDefinition) -> bool:
	if template == null:
		return false
	if not allowed_troop_type_ids.is_empty():
		var troop_id := StringName(template.troop_type.to_snake_case())
		if not allowed_troop_type_ids.has(troop_id) and not allowed_troop_type_ids.has(template.id):
			return false
	if allowed_role_tags.is_empty():
		return true
	for tag: StringName in allowed_role_tags:
		if template.role_tags.has(tag):
			return true
	return false


func to_dictionary() -> Dictionary:
	var serialized_rules: Array[Dictionary] = []
	for rule: LoadoutItemRule in rules:
		if rule != null:
			serialized_rules.append(rule.to_dictionary())
	return {
		"template_id": String(template_id),
		"display_name": display_name,
		"description": description,
		"is_authored": is_authored,
		"source_definition_id": String(source_definition_id),
		"allowed_troop_type_ids": _string_array(allowed_troop_type_ids),
		"allowed_role_tags": _string_array(allowed_role_tags),
		"rules": serialized_rules,
		"weight_limit_policy": String(weight_limit_policy),
		"substitution_policy": String(substitution_policy),
		"template_version": template_version,
	}


static func from_dictionary(data: Dictionary) -> LoadoutTemplateState:
	var result := LoadoutTemplateState.new()
	result.template_id = StringName(data.get("template_id", ""))
	result.display_name = String(data.get("display_name", "Unnamed Loadout"))
	result.description = String(data.get("description", ""))
	result.is_authored = bool(data.get("is_authored", false))
	result.source_definition_id = StringName(data.get("source_definition_id", ""))
	result.allowed_troop_type_ids = _string_name_array(data.get("allowed_troop_type_ids", []))
	result.allowed_role_tags = _string_name_array(data.get("allowed_role_tags", []))
	var raw_rules: Variant = data.get("rules", [])
	if raw_rules is Array:
		for raw_rule: Variant in raw_rules as Array:
			if raw_rule is Dictionary:
				result.rules.append(LoadoutItemRule.from_dictionary(raw_rule as Dictionary))
	result.weight_limit_policy = StringName(data.get("weight_limit_policy", "respect_capacity"))
	result.substitution_policy = StringName(data.get("substitution_policy", POLICY_CONSERVE_VALUABLE))
	result.template_version = maxi(1, int(data.get("template_version", 1)))
	return result


static func _string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for entry: Variant in value as Array:
		var parsed := StringName(entry)
		if not parsed.is_empty():
			result.append(parsed)
	return result
