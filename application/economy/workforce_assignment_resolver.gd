class_name WorkforceAssignmentResolver
extends RefCounted

var _workforce_catalogue: WorkforceCatalogue
var _production_catalogue: ProductionCatalogue
var _stronghold_registry


func configure(workforce_catalogue: WorkforceCatalogue, production_catalogue: ProductionCatalogue, stronghold_registry) -> void:
	_workforce_catalogue = workforce_catalogue
	_production_catalogue = production_catalogue
	_stronghold_registry = stronghold_registry


func resolve(campaign: CampaignState) -> Dictionary:
	var result: Dictionary = {"projects": {}, "owned": 0, "positions": 0, "slots": 0, "assigned": 0, "free": 0}
	if campaign == null or _workforce_catalogue == null:
		return result
	var available_ratings: Array[int] = []
	for definition_value: WorkforceDefinition in _workforce_catalogue.definitions():
		if definition_value.role_id != WorkforceDefinition.ROLE_MANUFACTURING:
			continue
		var count: int = campaign.workforce_count(definition_value.worker_definition_id)
		for _index: int in range(count):
			available_ratings.append(definition_value.work_rating)
	available_ratings.sort()
	available_ratings.reverse()
	result["owned"] = available_ratings.size()
	var facilities: Array[Dictionary] = _operational_workshops(campaign)
	var total_positions: int = 0
	var project_slots: int = 0
	var per_project_limit: int = 0
	for facility: Dictionary in facilities:
		total_positions += int(facility.get("positions", 0))
		project_slots += int(facility.get("slots", 0))
		per_project_limit = maxi(per_project_limit, int(facility.get("per_project", 0)))
	result["positions"] = total_positions
	result["slots"] = project_slots
	var projects: Array[ProductionProjectState] = []
	for project: ProductionProjectState in campaign.get_production_projects():
		if project != null and project.is_open():
			projects.append(project)
	projects.sort_custom(func(a: ProductionProjectState, b: ProductionProjectState) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		if a.created_tick != b.created_tick:
			return a.created_tick < b.created_tick
		return String(a.project_id) < String(b.project_id)
	)
	var used_positions: int = 0
	var used_slots: int = 0
	var worker_index: int = 0
	for project: ProductionProjectState in projects:
		var recipe_value: ProductionRecipeDefinition = _production_catalogue.recipe(project.recipe_id) if _production_catalogue != null else null
		var entry: Dictionary = {"assigned_count": 0, "daily_work": 0, "ratings": [], "status": &"paused", "pause_reason": "No operational Workshop positions."}
		if recipe_value == null:
			entry["pause_reason"] = "Production recipe missing."
			result["projects"][project.project_id] = entry
			continue
		if project.remaining_work() <= 0:
			entry["pause_reason"] = (
				project.pause_reason
				if not project.pause_reason.is_empty()
				else "Completion is waiting for its reserved inputs and output validation."
			)
			result["projects"][project.project_id] = entry
			continue
		if used_slots >= project_slots or total_positions <= used_positions:
			result["projects"][project.project_id] = entry
			continue
		var requested: int = mini(project.requested_worker_count, recipe_value.maximum_workers)
		requested = mini(requested, per_project_limit)
		requested = mini(requested, total_positions - used_positions)
		requested = mini(requested, available_ratings.size() - worker_index)
		if requested < recipe_value.minimum_workers:
			entry["pause_reason"] = (
				"Requires at least %d Manufacturing worker%s."
				% [recipe_value.minimum_workers, "" if recipe_value.minimum_workers == 1 else "s"]
			)
			result["projects"][project.project_id] = entry
			continue
		var ratings: Array[int] = []
		var daily_work: int = 0
		for _index: int in range(requested):
			var rating: int = available_ratings[worker_index]
			worker_index += 1
			ratings.append(rating)
			daily_work += rating
		used_positions += requested
		used_slots += 1
		entry["assigned_count"] = requested
		entry["daily_work"] = daily_work
		entry["ratings"] = ratings
		entry["status"] = &"active"
		entry["pause_reason"] = ""
		result["projects"][project.project_id] = entry
	result["assigned"] = worker_index
	result["free"] = maxi(0, available_ratings.size() - worker_index)
	return result


func _operational_workshops(campaign: CampaignState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if campaign == null or campaign.stronghold == null or _stronghold_registry == null:
		return result
	var definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
	if definition == null:
		return result
	for facility: StrongholdFacilityState in campaign.stronghold.get_facilities():
		if facility == null or facility.condition != StrongholdFacilityState.CONDITION_OPERATIONAL:
			continue
		var facility_definition = definition.facility_definition(facility.definition_id)
		if facility_definition == null:
			continue
		var positions: int = facility_definition.production_worker_positions_for_level(facility.level)
		var slots: int = facility_definition.production_project_slots_for_level(facility.level)
		if positions <= 0 or slots <= 0:
			continue
		result.append({"facility_id": facility.instance_id, "positions": positions, "slots": slots, "per_project": facility_definition.production_max_workers_for_level(facility.level)})
	return result
