class_name ResearchService
extends RefCounted

const MINUTES_PER_WORK: int = 1440

var _research_catalogue: ResearchCatalogue
var _assignment_resolver: ResearchAssignmentResolver
var _reservation_service


func configure(
	research_catalogue: ResearchCatalogue,
	assignment_resolver: ResearchAssignmentResolver,
	reservation_service
) -> void:
	_research_catalogue = research_catalogue
	_assignment_resolver = assignment_resolver
	_reservation_service = reservation_service


func project_entries(campaign: CampaignState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if campaign == null or _research_catalogue == null:
		return result
	for definition_value: ResearchProjectDefinition in _research_catalogue.visible_definitions(campaign):
		var active_project: ResearchProjectState = campaign.research_project_for_definition(definition_value.research_id)
		var preview: OperationResult = preview_start(campaign, definition_value.research_id)
		result.append({
			"definition": definition_value,
			"completed": campaign.has_completed_research(definition_value.research_id),
			"active_project": active_project,
			"available": preview.success,
			"reason": "Available" if preview.success else preview.message,
		})
	return result


func preview_start(campaign: CampaignState, research_id: StringName) -> OperationResult:
	if campaign == null or _research_catalogue == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var definition_value: ResearchProjectDefinition = _research_catalogue.definition(research_id)
	if definition_value == null:
		return OperationResult.fail(&"research_definition_missing", "The selected Research project no longer exists.")
	if not definition_value.is_revealed(campaign):
		return OperationResult.fail(&"research_not_revealed", "This Research project has not been revealed.")
	if campaign.has_completed_research(research_id):
		return OperationResult.fail(&"research_already_completed", "This Research has already been completed.")
	if campaign.research_project_for_definition(research_id) != null:
		return OperationResult.fail(&"research_already_active", "This Research project is already active or queued.")
	if not definition_value.prerequisites_met(campaign):
		var missing: Array[String] = []
		for prerequisite_id: StringName in definition_value.prerequisite_research_ids:
			if not campaign.has_completed_research(prerequisite_id):
				var prerequisite: ResearchProjectDefinition = _research_catalogue.definition(prerequisite_id)
				missing.append(prerequisite.display_name if prerequisite != null else String(prerequisite_id))
		return OperationResult.fail(&"research_prerequisite_missing", "Requires: %s." % ", ".join(missing))
	var capacity: Dictionary = _assignment_resolver.research_capacity(campaign) if _assignment_resolver != null else {}
	var matching_facility: Dictionary = _matching_research_facility(capacity, definition_value)
	if matching_facility.is_empty():
		return OperationResult.fail(
			&"research_facility_unavailable",
			"Requires an operational %s at level %d or higher with Research capacity."
			% [_research_facility_name(definition_value.required_facility_definition_id), definition_value.minimum_facility_level]
		)
	for raw_resource_id: Variant in definition_value.resource_costs.keys():
		var resource_id := StringName(raw_resource_id)
		var required: int = int(definition_value.resource_costs[raw_resource_id])
		var available: int = (
			_reservation_service.available_resource_amount(campaign, resource_id)
			if _reservation_service != null
			else campaign.resources.amount(resource_id)
		)
		if available < required:
			return OperationResult.fail(
				&"research_resource_unavailable",
				"Requires %d %s; only %d is unreserved." % [required, String(resource_id).capitalize(), available]
			)
	return OperationResult.ok({
		"definition": definition_value,
		"resource_costs": definition_value.resource_costs.duplicate(true),
		"total_work_required": definition_value.total_work_required,
		"host_facility_id": StringName(matching_facility.get("facility_id", "")),
	}, "Research can begin.")


func start_candidate(campaign: CampaignState, research_id: StringName) -> OperationResult:
	var preview: OperationResult = preview_start(campaign, research_id)
	if not preview.success:
		return preview
	var definition_value: ResearchProjectDefinition = _research_catalogue.definition(research_id)
	var project := ResearchProjectState.new()
	project.project_id = campaign.allocate_research_project_id()
	project.research_id = research_id
	project.priority = campaign.next_research_priority()
	project.requested_worker_count = definition_value.minimum_workers
	project.total_work_required = definition_value.total_work_required
	project.created_tick = campaign.campaign_tick
	project.status = ResearchProjectState.STATUS_QUEUED
	var reservation_id := StringName("reservation.research.%s" % project.project_id)
	var reserved: OperationResult = _reservation_service.reserve_research_candidate(
		campaign,
		reservation_id,
		project.project_id,
		definition_value.display_name,
		definition_value.resource_costs
	)
	if not reserved.success:
		return reserved
	campaign.research_projects_by_id[project.project_id] = project
	campaign.research_reservation_ids_by_project_id[project.project_id] = reservation_id
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(project, "%s queued for Research." % definition_value.display_name)


func set_requested_workers_candidate(
	campaign: CampaignState,
	project_id: StringName,
	requested_count: int
) -> OperationResult:
	var project: ResearchProjectState = campaign.get_research_project(project_id)
	if project == null or not project.is_open():
		return OperationResult.fail(&"research_project_missing", "The selected Research project is no longer active.")
	var definition_value: ResearchProjectDefinition = _research_catalogue.definition(project.research_id)
	if definition_value == null:
		return OperationResult.fail(&"research_definition_missing", "The Research definition is missing.")
	var capacity: Dictionary = _assignment_resolver.research_capacity(campaign) if _assignment_resolver != null else {}
	var maximum: int = mini(
		definition_value.maximum_workers,
		maxi(0, int(capacity.get("per_project", definition_value.maximum_workers)))
	)
	project.requested_worker_count = clampi(requested_count, 0, maximum)
	project.revision += 1
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(project, "Research worker assignment updated.")


func set_priority_candidate(campaign: CampaignState, project_id: StringName, direction: int) -> OperationResult:
	var projects: Array[ResearchProjectState] = campaign.get_open_research_projects()
	var index: int = -1
	for current_index: int in range(projects.size()):
		if projects[current_index].project_id == project_id:
			index = current_index
			break
	if index < 0:
		return OperationResult.fail(&"research_project_missing", "The selected Research project is no longer active.")
	var target_index: int = clampi(index + signi(direction), 0, projects.size() - 1)
	if target_index == index:
		return OperationResult.no_change(projects[index], "Research priority is unchanged.")
	var current_priority: int = projects[index].priority
	projects[index].priority = projects[target_index].priority
	projects[target_index].priority = current_priority
	projects[index].revision += 1
	projects[target_index].revision += 1
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(projects[index], "Research priority updated.")


func cancel_candidate(campaign: CampaignState, project_id: StringName) -> OperationResult:
	var project: ResearchProjectState = campaign.get_research_project(project_id)
	if project == null or not project.is_open():
		return OperationResult.fail(&"research_project_missing", "The selected Research project is no longer active.")
	if project.remaining_work() <= 0:
		return OperationResult.fail(&"research_completion_pending", "Completed Research cannot be cancelled while its result is being applied.")
	var reservation_id: StringName = campaign.research_reservation_id(project_id)
	if _reservation_service != null and not reservation_id.is_empty():
		_reservation_service.release_reservation_candidate(campaign, reservation_id, true)
	campaign.research_reservation_ids_by_project_id.erase(project.project_id)
	project.status = ResearchProjectState.STATUS_CANCELLED
	project.requested_worker_count = 0
	project.pause_reason = "Cancelled"
	project.revision += 1
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(project, "Research project cancelled; reserved inputs released.")


func advance_candidate(campaign: CampaignState, tick_delta: int) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	if campaign == null or tick_delta <= 0:
		return completed
	var remaining_ticks: int = tick_delta
	var guard: int = 0
	while remaining_ticks > 0 and guard < 2048:
		guard += 1
		var completion_applied_before_work: bool = false
		for ready_project: ResearchProjectState in campaign.get_open_research_projects():
			if ready_project.remaining_work() > 0:
				continue
			var ready_completion: OperationResult = _complete_project_candidate(campaign, ready_project)
			if ready_completion.success:
				completed.append(ready_completion.data as Dictionary)
				completion_applied_before_work = true
			else:
				ready_project.status = ResearchProjectState.STATUS_PAUSED
				ready_project.pause_reason = ready_completion.message
				ready_project.revision += 1
		if completion_applied_before_work:
			continue
		_recalculate_assignments(campaign)
		var allocation: Dictionary = _assignment_resolver.resolve(campaign) if _assignment_resolver != null else {"projects": {}}
		var project_entries: Dictionary = allocation.get("projects", {}) as Dictionary
		var active_projects: Array[ResearchProjectState] = []
		var ticks_to_boundary: int = remaining_ticks
		for project: ResearchProjectState in campaign.get_open_research_projects():
			var entry: Dictionary = project_entries.get(project.project_id, {}) as Dictionary
			var daily_work: int = int(entry.get("daily_work", 0))
			if daily_work <= 0:
				project.status = ResearchProjectState.STATUS_PAUSED
				project.pause_reason = String(entry.get("pause_reason", "No Research workers assigned."))
				continue
			project.status = ResearchProjectState.STATUS_ACTIVE
			project.pause_reason = ""
			active_projects.append(project)
			var work_minutes_remaining: int = maxi(
				1,
				project.remaining_work() * MINUTES_PER_WORK - project.work_accumulator_minutes
			)
			var project_boundary: int = ceili(float(work_minutes_remaining) / float(daily_work))
			ticks_to_boundary = mini(ticks_to_boundary, maxi(1, project_boundary))
		if active_projects.is_empty():
			break
		var step_ticks: int = mini(remaining_ticks, ticks_to_boundary)
		for project: ResearchProjectState in active_projects:
			var entry: Dictionary = project_entries.get(project.project_id, {}) as Dictionary
			var daily_work: int = int(entry.get("daily_work", 0))
			var accumulated_minutes: int = project.work_accumulator_minutes
			accumulated_minutes += daily_work * step_ticks
			var gained_work: int = accumulated_minutes / MINUTES_PER_WORK
			accumulated_minutes = posmod(accumulated_minutes, MINUTES_PER_WORK)
			project.work_accumulator_minutes = accumulated_minutes
			if gained_work > 0:
				project.completed_work = mini(project.total_work_required, project.completed_work + gained_work)
				project.revision += 1
		remaining_ticks -= step_ticks
		var boundary_completed: bool = false
		for project: ResearchProjectState in active_projects:
			if project.completed_work < project.total_work_required:
				continue
			var completion: OperationResult = _complete_project_candidate(campaign, project)
			if completion.success:
				boundary_completed = true
				completed.append(completion.data as Dictionary)
		if not boundary_completed and step_ticks <= 0:
			break
	_recalculate_assignments(campaign)
	if not completed.is_empty():
		campaign.revision += 1
	return completed


func project_snapshot(campaign: CampaignState, project: ResearchProjectState) -> Dictionary:
	if campaign == null or project == null:
		return {}
	var definition_value: ResearchProjectDefinition = _research_catalogue.definition(project.research_id) if _research_catalogue != null else null
	var allocation: Dictionary = _assignment_resolver.resolve(campaign) if _assignment_resolver != null else {"projects": {}}
	var entry: Dictionary = (allocation.get("projects", {}) as Dictionary).get(project.project_id, {}) as Dictionary
	var daily_work: int = int(entry.get("daily_work", 0))
	var days_remaining: int = 0
	if daily_work > 0:
		days_remaining = ceili(float(project.remaining_work()) / float(daily_work))
	return {
		"project": project,
		"definition": definition_value,
		"workers_assigned": int(entry.get("assigned_count", 0)),
		"time_remaining_days": days_remaining,
		"paused": daily_work <= 0,
		"pause_reason": String(entry.get("pause_reason", project.pause_reason)),
	}


func _complete_project_candidate(campaign: CampaignState, project: ResearchProjectState) -> OperationResult:
	if project.applied or project.status == ResearchProjectState.STATUS_APPLIED:
		return OperationResult.no_change(project, "Research result already applied.")
	var definition_value: ResearchProjectDefinition = _research_catalogue.definition(project.research_id) if _research_catalogue != null else null
	var reservation_id: StringName = campaign.research_reservation_id(project.project_id)
	var reservation = campaign.get_strategic_reservation(reservation_id)
	if definition_value == null or reservation == null or not reservation.is_active():
		return OperationResult.fail(&"research_reservation_missing", "Reserved Research inputs are missing.")
	for raw_resource_id: Variant in reservation.resource_quantities.keys():
		var resource_id := StringName(raw_resource_id)
		var required_amount: int = int(reservation.resource_quantities[raw_resource_id])
		if campaign.resources == null or campaign.resources.amount(resource_id) < required_amount:
			return OperationResult.fail(&"research_input_commit_failed", "Research resources changed before completion.")
	for raw_resource_id: Variant in reservation.resource_quantities.keys():
		if not campaign.resources.add(StringName(raw_resource_id), -int(reservation.resource_quantities[raw_resource_id])):
			return OperationResult.fail(&"research_input_commit_failed", "Research resources changed before completion.")
	campaign.complete_research(definition_value.research_id)
	for capability_id: StringName in definition_value.granted_capability_ids:
		campaign.unlocked_capability_ids[capability_id] = true
	for contact_id: StringName in definition_value.unlocked_contact_ids:
		campaign.unlocked_shop_contact_ids[contact_id] = true
	_reservation_service.release_reservation_candidate(campaign, reservation_id, false)
	campaign.research_reservation_ids_by_project_id.erase(project.project_id)
	project.completed_work = project.total_work_required
	project.work_accumulator_minutes = 0
	project.status = ResearchProjectState.STATUS_APPLIED
	project.pause_reason = ""
	project.requested_worker_count = 0
	project.applied = true
	project.revision += 1
	return OperationResult.ok({
		"project_id": project.project_id,
		"research_id": project.research_id,
		"unlocked_contact_ids": definition_value.unlocked_contact_ids.duplicate(),
		"unlocked_recipe_ids": definition_value.unlocked_recipe_ids.duplicate(),
		"unlocked_worker_definition_ids": definition_value.unlocked_worker_definition_ids.duplicate(),
	}, "%s complete." % definition_value.display_name)


func _matching_research_facility(
	capacity: Dictionary,
	definition_value: ResearchProjectDefinition
) -> Dictionary:
	if definition_value == null:
		return {}
	var facilities: Array = capacity.get("facilities", []) as Array
	for raw_facility: Variant in facilities:
		if not raw_facility is Dictionary:
			continue
		var facility: Dictionary = raw_facility as Dictionary
		if StringName(facility.get("definition_id", "")) != definition_value.required_facility_definition_id:
			continue
		if int(facility.get("level", 0)) < definition_value.minimum_facility_level:
			continue
		if int(facility.get("positions", 0)) <= 0 or int(facility.get("slots", 0)) <= 0:
			continue
		return facility
	return {}


func _research_facility_name(facility_definition_id: StringName) -> String:
	if facility_definition_id == &"facility.fifth_god_heart":
		return "Fifth-God Heart"
	return String(facility_definition_id).replace("facility.", "").replace("_", " ").capitalize()


func _recalculate_assignments(campaign: CampaignState) -> void:
	if campaign == null or _assignment_resolver == null:
		return
	var allocation: Dictionary = _assignment_resolver.resolve(campaign)
	var entries: Dictionary = allocation.get("projects", {}) as Dictionary
	for project: ResearchProjectState in campaign.get_open_research_projects():
		var entry: Dictionary = entries.get(project.project_id, {}) as Dictionary
		if int(entry.get("assigned_count", 0)) > 0:
			project.status = ResearchProjectState.STATUS_ACTIVE
			project.pause_reason = ""
		else:
			project.status = ResearchProjectState.STATUS_PAUSED
			project.pause_reason = String(entry.get("pause_reason", "No Research workers assigned."))
