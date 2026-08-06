class_name ResearchAssignmentResolver
extends RefCounted

var _workforce_catalogue: WorkforceCatalogue
var _research_catalogue: ResearchCatalogue
var _stronghold_registry


func configure(
	workforce_catalogue: WorkforceCatalogue,
	research_catalogue: ResearchCatalogue,
	stronghold_registry
) -> void:
	_workforce_catalogue = workforce_catalogue
	_research_catalogue = research_catalogue
	_stronghold_registry = stronghold_registry


func resolve(campaign: CampaignState) -> Dictionary:
	var result: Dictionary = {
		"projects": {},
		"owned": 0,
		"positions": 0,
		"slots": 0,
		"assigned": 0,
		"free": 0,
	}
	if campaign == null or _workforce_catalogue == null:
		return result
	var available_ratings: Array[int] = []
	for definition_value: WorkforceDefinition in _workforce_catalogue.definitions():
		if definition_value.role_id != WorkforceDefinition.ROLE_RESEARCH:
			continue
		var count: int = campaign.workforce_count(definition_value.worker_definition_id)
		for _index: int in range(count):
			available_ratings.append(definition_value.work_rating)
	available_ratings.sort()
	available_ratings.reverse()
	result["owned"] = available_ratings.size()

	var capacity: Dictionary = research_capacity(campaign)
	var total_positions: int = int(capacity.get("positions", 0))
	var project_slots: int = int(capacity.get("slots", 0))
	var per_project_limit: int = int(capacity.get("per_project", 0))
	result["positions"] = total_positions
	result["slots"] = project_slots

	var projects: Array[ResearchProjectState] = campaign.get_open_research_projects()
	projects.sort_custom(func(a: ResearchProjectState, b: ResearchProjectState) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		if a.created_tick != b.created_tick:
			return a.created_tick < b.created_tick
		return String(a.project_id) < String(b.project_id)
	)
	var used_positions: int = 0
	var used_slots: int = 0
	var worker_index: int = 0
	for project: ResearchProjectState in projects:
		var definition_value: ResearchProjectDefinition = (
			_research_catalogue.definition(project.research_id)
			if _research_catalogue != null
			else null
		)
		var entry: Dictionary = {
			"assigned_count": 0,
			"daily_work": 0,
			"status": &"paused",
			"pause_reason": "No operational Research positions.",
		}
		if definition_value == null:
			entry["pause_reason"] = "Research definition missing."
			result["projects"][project.project_id] = entry
			continue
		var matching_facility: Dictionary = _matching_facility(capacity, definition_value)
		if matching_facility.is_empty():
			entry["pause_reason"] = "Required Research facility is unavailable."
			result["projects"][project.project_id] = entry
			continue
		if project.remaining_work() <= 0:
			entry["pause_reason"] = (
				project.pause_reason
				if not project.pause_reason.is_empty()
				else "Completion is waiting for its reserved inputs and validation."
			)
			result["projects"][project.project_id] = entry
			continue
		if used_slots >= project_slots or used_positions >= total_positions:
			result["projects"][project.project_id] = entry
			continue
		var requested: int = mini(project.requested_worker_count, definition_value.maximum_workers)
		requested = mini(requested, per_project_limit)
		requested = mini(requested, int(matching_facility.get("per_project", requested)))
		requested = mini(requested, total_positions - used_positions)
		requested = mini(requested, available_ratings.size() - worker_index)
		if requested < definition_value.minimum_workers:
			entry["pause_reason"] = (
				"Requires at least %d Research worker%s."
				% [definition_value.minimum_workers, "" if definition_value.minimum_workers == 1 else "s"]
			)
			result["projects"][project.project_id] = entry
			continue
		var daily_work: int = 0
		for _index: int in range(requested):
			daily_work += available_ratings[worker_index]
			worker_index += 1
		used_positions += requested
		used_slots += 1
		entry["assigned_count"] = requested
		entry["daily_work"] = daily_work
		entry["status"] = &"active"
		entry["pause_reason"] = ""
		result["projects"][project.project_id] = entry
	result["assigned"] = worker_index
	result["free"] = maxi(0, available_ratings.size() - worker_index)
	return result


func _matching_facility(
	capacity: Dictionary,
	definition_value: ResearchProjectDefinition
) -> Dictionary:
	if definition_value == null:
		return {}
	for raw_facility: Variant in capacity.get("facilities", []) as Array:
		if not raw_facility is Dictionary:
			continue
		var facility: Dictionary = raw_facility as Dictionary
		if StringName(facility.get("definition_id", "")) != definition_value.required_facility_definition_id:
			continue
		if int(facility.get("level", 0)) < definition_value.minimum_facility_level:
			continue
		return facility
	return {}


func research_capacity(campaign: CampaignState) -> Dictionary:
	var result: Dictionary = {
		"positions": 0,
		"slots": 0,
		"per_project": 0,
		"facilities": [],
	}
	if campaign == null or campaign.stronghold == null or _stronghold_registry == null:
		return result
	var stronghold_definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
	if stronghold_definition == null:
		return result
	var facilities: Array[Dictionary] = []
	for facility: StrongholdFacilityState in campaign.stronghold.get_facilities():
		if facility == null or facility.condition != StrongholdFacilityState.CONDITION_OPERATIONAL:
			continue
		var facility_definition = stronghold_definition.facility_definition(facility.definition_id)
		if facility_definition == null:
			continue
		var positions: int = facility_definition.research_worker_positions_for_level(facility.level)
		var slots: int = facility_definition.research_project_slots_for_level(facility.level)
		var per_project: int = facility_definition.research_max_workers_for_level(facility.level)
		if positions <= 0 or slots <= 0:
			continue
		facilities.append({
			"facility_id": facility.instance_id,
			"definition_id": facility.definition_id,
			"level": facility.level,
			"positions": positions,
			"slots": slots,
			"per_project": per_project,
		})
		result["positions"] = int(result["positions"]) + positions
		result["slots"] = int(result["slots"]) + slots
		result["per_project"] = maxi(int(result["per_project"]), per_project)
	result["facilities"] = facilities
	return result
