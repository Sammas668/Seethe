class_name ProductionCatalogue
extends RefCounted

var _recipes_by_id: Dictionary = {}
var _catalogue: ContentCatalogue


func configure(catalogue: ContentCatalogue) -> void:
	_catalogue = catalogue
	_register(_manufacture(&"production.mace", "Manufacture Mace", "Forge a basic Mace from stored Wood and Metal.", &"weapons", &"item.mace", {&"metal": 4, &"wood": 2}, 6, 1, 3))
	_register(_manufacture(&"production.rope", "Manufacture Rope", "Twist stored Textiles into a useful coil of Rope.", &"supplies", &"item.rope", {&"textiles": 2}, 2, 1, 3))
	_register(_manufacture(&"production.manacles", "Manufacture Manacles", "Forge a set of reusable restraints.", &"supplies", &"item.manacles", {&"metal": 3}, 4, 1, 3))
	var raiders_axe := _manufacture(&"production.raiders_axe", "Manufacture Raider's Axe", "Forge a practical Reaver axe from stored Wood and Metal.", &"weapons", &"item.raiders_axe", {&"metal": 6, &"wood": 2}, 8, 1, 4)
	raiders_axe.required_research_ids = [&"research.common_weapon_patterns"]
	_register(raiders_axe)
	var guard_shield := _manufacture(&"production.guard_shield", "Manufacture Settlement Shield", "Build a sturdy wooden shield from an organised captured pattern.", &"armour", &"item.guard_shield", {&"wood": 6, &"metal": 2}, 7, 1, 4)
	guard_shield.required_research_ids = [&"research.common_weapon_patterns"]
	_register(guard_shield)
	var bandage := _manufacture(&"production.bandage", "Manufacture Bandage", "Produce medical dressings from Textiles using captured Ilyran field methods.", &"supplies", &"item.bandage", {&"textiles": 2}, 2, 1, 3)
	bandage.required_research_ids = [&"research.field_medicine"]
	_register(bandage)
	_register(_repair(&"repair.mace", "Repair Mace", &"item.mace", {&"metal": 2, &"wood": 1}, 3, 1, 3))
	_register(_repair(&"repair.rope", "Repair Rope", &"item.rope", {&"textiles": 1}, 1, 1, 2))
	_register(_repair(&"repair.manacles", "Repair Manacles", &"item.manacles", {&"metal": 2}, 2, 1, 3))


func recipe(recipe_id: StringName) -> ProductionRecipeDefinition:
	return _recipes_by_id.get(recipe_id) as ProductionRecipeDefinition


func recipes() -> Array[ProductionRecipeDefinition]:
	var result: Array[ProductionRecipeDefinition] = []
	for raw: Variant in _recipes_by_id.values():
		var recipe_value: ProductionRecipeDefinition = raw as ProductionRecipeDefinition
		if recipe_value != null:
			result.append(recipe_value)
	result.sort_custom(func(a: ProductionRecipeDefinition, b: ProductionRecipeDefinition) -> bool:
		if a.category_id != b.category_id:
			return String(a.category_id) < String(b.category_id)
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result


func repair_recipe_for_item(item: CampaignItemState, item_definition: ItemDefinition) -> ProductionRecipeDefinition:
	if item == null or item_definition == null:
		return null
	for recipe_value: ProductionRecipeDefinition in recipes():
		if recipe_value.project_type != ProductionRecipeDefinition.TYPE_REPAIR_ITEM:
			continue
		if recipe_value.repair_item_definition_ids.has(item.definition_id):
			return recipe_value
		for tag: StringName in recipe_value.repair_item_tags:
			if item_definition.has_tag(tag):
				return recipe_value
	return null


func validate_catalogue() -> Array[String]:
	var errors: Array[String] = []
	for recipe_value: ProductionRecipeDefinition in recipes():
		errors.append_array(recipe_value.validate_definition())
		if _catalogue != null:
			if recipe_value.project_type == ProductionRecipeDefinition.TYPE_MANUFACTURE_ITEM and _catalogue.item_definition(recipe_value.output_item_definition_id) == null:
				errors.append("Production recipe %s references missing output %s." % [recipe_value.recipe_id, recipe_value.output_item_definition_id])
			for item_id: StringName in recipe_value.repair_item_definition_ids:
				if _catalogue.item_definition(item_id) == null:
					errors.append("Repair recipe %s references missing item %s." % [recipe_value.recipe_id, item_id])
	return errors


func _register(recipe_value: ProductionRecipeDefinition) -> void:
	if recipe_value != null and not recipe_value.recipe_id.is_empty():
		_recipes_by_id[recipe_value.recipe_id] = recipe_value


static func _manufacture(id: StringName, name: String, description: String, category: StringName, output: StringName, costs: Dictionary, work: int, minimum_workers: int, maximum_workers: int) -> ProductionRecipeDefinition:
	var result := ProductionRecipeDefinition.new()
	result.recipe_id = id
	result.project_type = ProductionRecipeDefinition.TYPE_MANUFACTURE_ITEM
	result.display_name = name
	result.description = description
	result.category_id = category
	result.resource_costs = costs.duplicate(true)
	result.output_item_definition_id = output
	result.output_quantity = 1
	result.total_work_required = work
	result.minimum_workers = minimum_workers
	result.maximum_workers = maximum_workers
	return result


static func _repair(id: StringName, name: String, item_id: StringName, costs: Dictionary, work: int, minimum_workers: int, maximum_workers: int) -> ProductionRecipeDefinition:
	var result := ProductionRecipeDefinition.new()
	result.recipe_id = id
	result.project_type = ProductionRecipeDefinition.TYPE_REPAIR_ITEM
	result.display_name = name
	result.description = "Restore the recovered destroyed item to full serviceability."
	result.category_id = &"repairs"
	result.resource_costs = costs.duplicate(true)
	result.repair_item_definition_ids = [item_id]
	result.total_work_required = work
	result.minimum_workers = minimum_workers
	result.maximum_workers = maximum_workers
	return result
