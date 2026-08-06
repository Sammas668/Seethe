class_name WorkforceCatalogue
extends RefCounted

var _definitions_by_id: Dictionary = {}


func _init() -> void:
	_register(_worker(&"worker.manufacturing.basic", WorkforceDefinition.ROLE_MANUFACTURING, "Craft Worker", "An ordinary labourer trained for Workshop production and repair.", 1, 20, 3, true))
	var skilled := _worker(&"worker.manufacturing.skilled", WorkforceDefinition.ROLE_MANUFACTURING, "Skilled Craft Worker", "A trained craftsperson who completes Workshop projects more efficiently.", 2, 55, 2, false)
	skilled.required_research_ids = [&"research.skilled_craftspeople"]
	_register(skilled)
	var master := _worker(&"worker.manufacturing.master", WorkforceDefinition.ROLE_MANUFACTURING, "Master Craft Worker", "An elite specialist capable of producing three times the daily work of an ordinary worker.", 3, 120, 1, false)
	master.required_research_ids = [&"research.master_craftspeople"]
	_register(master)
	_register(_worker(&"worker.research.basic", WorkforceDefinition.ROLE_RESEARCH, "Research Assistant", "An ordinary Research worker capable of supporting the Fifth-God Heart's first projects.", 1, 25, 2, true))
	var skilled_research := _worker(&"worker.research.skilled", WorkforceDefinition.ROLE_RESEARCH, "Skilled Researcher", "A disciplined scholar who completes Research more efficiently.", 2, 65, 2, false)
	skilled_research.required_research_ids = [&"research.organised_study"]
	_register(skilled_research)
	var senior_research := _worker(&"worker.research.senior", WorkforceDefinition.ROLE_RESEARCH, "Senior Researcher", "A rare specialist capable of producing three times the daily Research work of an assistant.", 3, 140, 1, false)
	senior_research.required_research_ids = [&"research.senior_researchers"]
	_register(senior_research)


func definition(worker_definition_id: StringName) -> WorkforceDefinition:
	return _definitions_by_id.get(worker_definition_id) as WorkforceDefinition


func definitions() -> Array[WorkforceDefinition]:
	var result: Array[WorkforceDefinition] = []
	for raw: Variant in _definitions_by_id.values():
		var definition_value: WorkforceDefinition = raw as WorkforceDefinition
		if definition_value != null:
			result.append(definition_value)
	result.sort_custom(func(a: WorkforceDefinition, b: WorkforceDefinition) -> bool:
		if a.role_id != b.role_id:
			return String(a.role_id) < String(b.role_id)
		if a.work_rating != b.work_rating:
			return a.work_rating < b.work_rating
		return String(a.worker_definition_id) < String(b.worker_definition_id)
	)
	return result


func validate_catalogue() -> Array[String]:
	var errors: Array[String] = []
	for definition_value: WorkforceDefinition in definitions():
		errors.append_array(definition_value.validate_definition())
	return errors


func _register(definition_value: WorkforceDefinition) -> void:
	if definition_value == null or definition_value.worker_definition_id.is_empty():
		return
	_definitions_by_id[definition_value.worker_definition_id] = definition_value


static func _worker(id: StringName, role: StringName, name: String, description: String, rating: int, cost: int, offers: int, starting: bool) -> WorkforceDefinition:
	var result := WorkforceDefinition.new()
	result.worker_definition_id = id
	result.role_id = role
	result.display_name = name
	result.description = description
	result.work_rating = rating
	result.hire_gold_cost = cost
	result.market_offer_count = offers
	result.starting_available = starting
	return result
