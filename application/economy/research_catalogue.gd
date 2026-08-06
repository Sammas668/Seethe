class_name ResearchCatalogue
extends RefCounted

var _definitions_by_id: Dictionary = {}


func _init() -> void:
	_register(_project(
		&"research.organised_study",
		"Organised Study",
		"Establish a repeatable method for cataloguing evidence, comparing captured sources and directing Research workers.",
		true,
		[],
		[],
		{&"gold": 20, &"textiles": 5},
		8,
		1,
		2,
		[&"capability.research.organised"],
		[],
		[],
		[&"worker.research.skilled"]
	))
	_register(_project(
		&"research.skilled_craftspeople",
		"Skilled Craftspeople",
		"Formalise improved Workshop training and recruitment standards for skilled Manufacturing workers.",
		true,
		[],
		[],
		{&"gold": 35, &"metal": 5},
		10,
		1,
		3,
		[&"capability.workforce.skilled_craftspeople"],
		[],
		[],
		[&"worker.manufacturing.skilled"]
	))
	_register(_project(
		&"research.master_craftspeople",
		"Master Craft Organisation",
		"Build the contacts and standards required to recruit rare master Manufacturing workers.",
		true,
		[],
		[&"research.skilled_craftspeople"],
		{&"gold": 80, &"metal": 10, &"magic": 2},
		18,
		2,
		4,
		[&"capability.workforce.master_craftspeople"],
		[],
		[],
		[&"worker.manufacturing.master"]
	))
	_register(_project(
		&"research.senior_researchers",
		"Senior Researchers",
		"Create a disciplined scholarly hierarchy capable of attracting highly productive Research workers.",
		true,
		[],
		[&"research.organised_study"],
		{&"gold": 60, &"textiles": 8, &"magic": 1},
		15,
		2,
		4,
		[&"capability.workforce.senior_researchers"],
		[],
		[],
		[&"worker.research.senior"]
	))
	_register(_project(
		&"research.common_weapon_patterns",
		"Common Weapon Patterns",
		"Study captured mundane weapons and record repeatable patterns for broader Workshop manufacture.",
		true,
		[],
		[],
		{&"wood": 10, &"metal": 10, &"gold": 20},
		12,
		1,
		3,
		[&"capability.production.common_weapons"],
		[],
		[&"production.raiders_axe", &"production.guard_shield"],
		[]
	))
	_register(_project(
		&"research.field_medicine",
		"Ilyran Field Medicine",
		"Extract practical treatment methods from captured Life-realm medical knowledge.",
		false,
		[&"source.research.life_medicine"],
		[],
		{&"food": 10, &"textiles": 10, &"gold": 25},
		10,
		1,
		3,
		[&"capability.production.field_medicine"],
		[],
		[&"production.bandage"],
		[]
	))
	_register(_project(
		&"research.military_supply_contacts",
		"Military Supply Contacts",
		"Turn captured command knowledge into a dependable fence for settlement military equipment.",
		false,
		[&"source.research.life_officer"],
		[],
		{&"gold": 50, &"food": 5},
		12,
		1,
		3,
		[&"capability.shop.military_fence"],
		[&"contact.military_fence"],
		[],
		[]
	))


func definition(research_id: StringName) -> ResearchProjectDefinition:
	return _definitions_by_id.get(research_id) as ResearchProjectDefinition


func definitions() -> Array[ResearchProjectDefinition]:
	var result: Array[ResearchProjectDefinition] = []
	for raw: Variant in _definitions_by_id.values():
		var definition_value: ResearchProjectDefinition = raw as ResearchProjectDefinition
		if definition_value != null:
			result.append(definition_value)
	result.sort_custom(func(a: ResearchProjectDefinition, b: ResearchProjectDefinition) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result


func visible_definitions(campaign: CampaignState) -> Array[ResearchProjectDefinition]:
	var result: Array[ResearchProjectDefinition] = []
	for definition_value: ResearchProjectDefinition in definitions():
		if definition_value.is_revealed(campaign):
			result.append(definition_value)
	return result


func validate_catalogue() -> Array[String]:
	var errors: Array[String] = []
	for definition_value: ResearchProjectDefinition in definitions():
		errors.append_array(definition_value.validate_definition())
		for prerequisite_id: StringName in definition_value.prerequisite_research_ids:
			if definition(prerequisite_id) == null:
				errors.append("Research project %s references missing prerequisite %s." % [definition_value.research_id, prerequisite_id])
	return errors


func _register(definition_value: ResearchProjectDefinition) -> void:
	if definition_value != null and not definition_value.research_id.is_empty():
		_definitions_by_id[definition_value.research_id] = definition_value


static func _project(
	id: StringName,
	name: String,
	description: String,
	starting_revealed: bool,
	reveal_sources: Array[StringName],
	prerequisites: Array[StringName],
	costs: Dictionary,
	work: int,
	minimum_workers: int,
	maximum_workers: int,
	capabilities: Array[StringName],
	contacts: Array[StringName],
	recipes: Array[StringName],
	workers: Array[StringName]
) -> ResearchProjectDefinition:
	var result := ResearchProjectDefinition.new()
	result.research_id = id
	result.display_name = name
	result.description = description
	result.starting_revealed = starting_revealed
	result.reveal_source_ids = reveal_sources.duplicate()
	result.prerequisite_research_ids = prerequisites.duplicate()
	result.resource_costs = costs.duplicate(true)
	result.total_work_required = work
	result.minimum_workers = minimum_workers
	result.maximum_workers = maximum_workers
	result.granted_capability_ids = capabilities.duplicate()
	result.unlocked_contact_ids = contacts.duplicate()
	result.unlocked_recipe_ids = recipes.duplicate()
	result.unlocked_worker_definition_ids = workers.duplicate()
	return result
