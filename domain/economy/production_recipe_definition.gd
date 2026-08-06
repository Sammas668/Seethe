class_name ProductionRecipeDefinition
extends Resource

const TYPE_MANUFACTURE_ITEM: StringName = &"manufacture_item"
const TYPE_REPAIR_ITEM: StringName = &"repair_item"

@export var recipe_id: StringName = &""
@export var project_type: StringName = TYPE_MANUFACTURE_ITEM
@export var display_name: String = "Production project"
@export_multiline var description: String = ""
@export var category_id: StringName = &"supplies"
@export var recipe_tags: Array[StringName] = []
@export var required_research_ids: Array[StringName] = []
@export var required_facility_definition_id: StringName = &"facility.workshop"
@export var minimum_facility_level: int = 1
@export var resource_costs: Dictionary = {}
@export var output_item_definition_id: StringName = &""
@export var output_quantity: int = 1
@export var total_work_required: int = 1
@export var minimum_workers: int = 1
@export var maximum_workers: int = 1
@export var repair_item_definition_ids: Array[StringName] = []
@export var repair_item_tags: Array[StringName] = []
@export var restore_to_full_condition: bool = true
@export var restored_condition: float = 1.0


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if recipe_id.is_empty():
		errors.append("Production recipe has no ID.")
	if project_type not in [TYPE_MANUFACTURE_ITEM, TYPE_REPAIR_ITEM]:
		errors.append("Production recipe %s has invalid project type %s." % [recipe_id, project_type])
	if display_name.strip_edges().is_empty():
		errors.append("Production recipe %s has no display name." % recipe_id)
	if minimum_facility_level <= 0:
		errors.append("Production recipe %s has an invalid facility level." % recipe_id)
	if total_work_required <= 0:
		errors.append("Production recipe %s has non-positive work." % recipe_id)
	if minimum_workers < 0 or maximum_workers <= 0 or minimum_workers > maximum_workers:
		errors.append("Production recipe %s has invalid worker limits." % recipe_id)
	if project_type == TYPE_MANUFACTURE_ITEM and output_item_definition_id.is_empty():
		errors.append("Manufacturing recipe %s has no output item." % recipe_id)
	if project_type == TYPE_MANUFACTURE_ITEM and output_quantity <= 0:
		errors.append("Manufacturing recipe %s has invalid output quantity." % recipe_id)
	if project_type == TYPE_REPAIR_ITEM and repair_item_definition_ids.is_empty() and repair_item_tags.is_empty():
		errors.append("Repair recipe %s accepts no item." % recipe_id)
	for raw_resource_id: Variant in resource_costs.keys():
		if StringName(raw_resource_id).is_empty() or int(resource_costs[raw_resource_id]) < 0:
			errors.append("Production recipe %s has an invalid resource cost." % recipe_id)
	return errors


func scaled_resource_costs(quantity: int) -> Dictionary:
	var result: Dictionary = {}
	var multiplier: int = maxi(1, quantity)
	for raw_id: Variant in resource_costs.keys():
		result[StringName(raw_id)] = int(resource_costs[raw_id]) * multiplier
	return result


func scaled_work(quantity: int) -> int:
	return total_work_required * maxi(1, quantity)
