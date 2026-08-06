class_name DismantlingRecipeDefinition
extends Resource

const VALID_RESOURCE_IDS: Array[StringName] = [
	&"wood",
	&"stone",
	&"metal",
	&"food",
	&"textiles",
	&"magic",
	&"gold",
]

@export var id: StringName = &""
@export var input_item_definition_id: StringName = &""
@export var resource_yields: Dictionary = {}
@export var basic_dismantling_allowed: bool = true
@export var required_facility_definition_id: StringName = &""
@export var required_facility_level: int = 0
@export var required_research_id: StringName = &""
@export_multiline var description: String = ""


func clean_resource_yields() -> Dictionary:
	var result: Dictionary = {}
	for raw_resource_id: Variant in resource_yields.keys():
		var resource_id := StringName(raw_resource_id)
		var amount: int = int(resource_yields[raw_resource_id])
		if not resource_id.is_empty() and amount > 0:
			result[resource_id] = amount
	return result


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Dismantling recipe has an empty ID.")
	if input_item_definition_id.is_empty():
		errors.append("Dismantling recipe %s has no input item definition." % id)
	if required_facility_level < 0:
		errors.append("Dismantling recipe %s has a negative facility level." % id)
	var yields: Dictionary = clean_resource_yields()
	if yields.is_empty():
		errors.append("Dismantling recipe %s has no positive resource yields." % id)
	for raw_resource_id: Variant in resource_yields.keys():
		var resource_id := StringName(raw_resource_id)
		if resource_id not in VALID_RESOURCE_IDS:
			errors.append(
				"Dismantling recipe %s grants unknown resource %s."
				% [id, resource_id]
			)
		if int(resource_yields[raw_resource_id]) <= 0:
			errors.append(
				"Dismantling recipe %s has a non-positive yield for %s."
				% [id, resource_id]
			)
	return errors
