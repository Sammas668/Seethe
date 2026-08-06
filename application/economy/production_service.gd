class_name ProductionService
extends RefCounted

const MINUTES_PER_WORK: int = 1440

var _catalogue: ContentCatalogue
var _production_catalogue: ProductionCatalogue
var _workforce_assignment_resolver: WorkforceAssignmentResolver
var _reservation_service
var _inventory_service
var _stronghold_registry


func configure(catalogue: ContentCatalogue, production_catalogue: ProductionCatalogue, workforce_assignment_resolver: WorkforceAssignmentResolver, reservation_service, inventory_service, stronghold_registry) -> void:
	_catalogue = catalogue
	_production_catalogue = production_catalogue
	_workforce_assignment_resolver = workforce_assignment_resolver
	_reservation_service = reservation_service
	_inventory_service = inventory_service
	_stronghold_registry = stronghold_registry


func available_recipe_entries(campaign: CampaignState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if campaign == null or _production_catalogue == null:
		return result
	for recipe_value: ProductionRecipeDefinition in _production_catalogue.recipes():
		if recipe_value.project_type != ProductionRecipeDefinition.TYPE_MANUFACTURE_ITEM:
			continue
		var preview: OperationResult = preview_start(campaign, recipe_value.recipe_id, 1, &"")
		result.append({"recipe": recipe_value, "available": preview.success, "reason": "Available" if preview.success else preview.message})
	return result


func preview_start(campaign: CampaignState, recipe_id: StringName, quantity: int = 1, target_item_id: StringName = &"") -> OperationResult:
	if campaign == null or _production_catalogue == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var recipe_value: ProductionRecipeDefinition = _production_catalogue.recipe(recipe_id)
	if recipe_value == null:
		return OperationResult.fail(&"production_recipe_missing", "The selected Production recipe no longer exists.")
	var requested_quantity: int = maxi(1, quantity)
	if requested_quantity > 99:
		return OperationResult.fail(&"production_quantity_excessive", "A Production batch may contain at most 99 items.")
	for research_id: StringName in recipe_value.required_research_ids:
		if not campaign.completed_research_ids.has(research_id):
			return OperationResult.fail(&"production_research_missing", "Required Research has not been completed.")
	var facility_data: Dictionary = _best_operational_facility(campaign, recipe_value)
	if facility_data.is_empty():
		return OperationResult.fail(&"production_facility_unavailable", "Requires an operational Workshop of the required level.")
	var target_item: CampaignItemState = null
	var target_definition: ItemDefinition = null
	if recipe_value.project_type == ProductionRecipeDefinition.TYPE_REPAIR_ITEM:
		target_item = campaign.get_item(target_item_id) as CampaignItemState
		if target_item == null or target_item.location == null or not target_item.location.is_stronghold_storage():
			return OperationResult.fail(&"repair_item_missing", "Only a recovered item in Storage can be repaired.")
		target_definition = _catalogue.item_definition(target_item.definition_id) if _catalogue != null else null
		if target_definition == null or _production_catalogue.repair_recipe_for_item(target_item, target_definition) != recipe_value:
			return OperationResult.fail(&"repair_recipe_invalid", "This repair project does not support the selected item.")
		if target_item.condition > 0.0:
			return OperationResult.fail(&"repair_item_not_destroyed", "Only an item reduced to zero condition can enter strategic repair.")
		requested_quantity = 1
	var costs: Dictionary = recipe_value.scaled_resource_costs(requested_quantity)
	for raw_resource_id: Variant in costs.keys():
		var resource_id := StringName(raw_resource_id)
		var required: int = int(costs[raw_resource_id])
		var available: int = _reservation_service.available_resource_amount(campaign, resource_id) if _reservation_service != null else campaign.resources.amount(resource_id)
		if available < required:
			return OperationResult.fail(&"production_resource_unavailable", "Requires %d %s; only %d is unreserved." % [required, String(resource_id).capitalize(), available])
	var output_space: int = 0
	if recipe_value.project_type == ProductionRecipeDefinition.TYPE_MANUFACTURE_ITEM:
		var output_definition: ItemDefinition = _catalogue.item_definition(recipe_value.output_item_definition_id) if _catalogue != null else null
		if output_definition == null:
			return OperationResult.fail(&"production_output_missing", "The Production output definition is missing.")
		output_space = output_definition.storage_space_for_quantity(recipe_value.output_quantity * requested_quantity)
		if _inventory_service != null:
			var resource_deltas: Dictionary = {}
			for raw_resource_id: Variant in costs.keys():
				resource_deltas[StringName(raw_resource_id)] = -int(costs[raw_resource_id])
			var projected_item_used: int = _inventory_service.used_item_storage_space(campaign) + output_space
			var projected_resource_used: int = _inventory_service.projected_resource_storage_space(campaign, resource_deltas)
			var reserved_output: int = _reservation_service.reserved_output_storage_space(campaign) if _reservation_service != null else 0
			if projected_item_used + projected_resource_used + reserved_output > _inventory_service.maximum_storage_space(campaign):
				return OperationResult.fail(&"production_storage_capacity_exceeded", "Requires enough Storage Space for the output after reserved inputs are consumed.")
	var total_work: int = recipe_value.scaled_work(requested_quantity)
	return OperationResult.ok({
		"recipe": recipe_value,
		"quantity": requested_quantity,
		"target_item": target_item,
		"resource_costs": costs,
		"output_storage_space": output_space,
		"total_work_required": total_work,
		"host_facility_id": StringName(facility_data.get("facility_id", "")),
		"maximum_workers": mini(recipe_value.maximum_workers, int(facility_data.get("per_project", recipe_value.maximum_workers))),
	}, "Production project is valid.")


func start_candidate(campaign: CampaignState, recipe_id: StringName, quantity: int = 1, target_item_id: StringName = &"") -> OperationResult:
	var preview: OperationResult = preview_start(campaign, recipe_id, quantity, target_item_id)
	if not preview.success:
		return preview
	var data: Dictionary = preview.data as Dictionary
	var recipe_value: ProductionRecipeDefinition = data.get("recipe") as ProductionRecipeDefinition
	var project := ProductionProjectState.new()
	project.project_id = campaign.allocate_production_project_id()
	project.recipe_id = recipe_value.recipe_id
	project.project_type = recipe_value.project_type
	project.target_item_id = target_item_id
	project.quantity = int(data.get("quantity", 1))
	project.priority = campaign.next_production_priority()
	project.requested_worker_count = maxi(recipe_value.minimum_workers, 1)
	project.total_work_required = int(data.get("total_work_required", 1))
	project.host_facility_id = StringName(data.get("host_facility_id", ""))
	project.output_storage_space = int(data.get("output_storage_space", 0))
	project.created_tick = campaign.campaign_tick
	project.last_progress_tick = campaign.campaign_tick
	project.status = ProductionProjectState.STATUS_QUEUED
	project.reservation_id = StringName("reservation.production.%s" % project.project_id)
	var item_ids: Array[StringName] = []
	if not target_item_id.is_empty():
		item_ids.append(target_item_id)
	var reserved: OperationResult = _reservation_service.reserve_production_candidate(campaign, project.reservation_id, project.project_id, recipe_value.display_name, data.get("resource_costs", {}) as Dictionary, item_ids, project.output_storage_space)
	if not reserved.success:
		return reserved
	campaign.production_projects_by_id[project.project_id] = project
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(project, "%s queued in Production." % recipe_value.display_name)


func set_requested_workers_candidate(campaign: CampaignState, project_id: StringName, requested_count: int) -> OperationResult:
	var project: ProductionProjectState = campaign.get_production_project(project_id) if campaign != null else null
	var recipe_value: ProductionRecipeDefinition = _production_catalogue.recipe(project.recipe_id) if project != null and _production_catalogue != null else null
	if project == null or recipe_value == null or not project.is_open():
		return OperationResult.fail(&"production_project_missing", "The selected Production project is unavailable.")
	project.requested_worker_count = clampi(requested_count, 0, recipe_value.maximum_workers)
	project.revision += 1
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(project, "Worker assignment updated.")


func set_priority_candidate(campaign: CampaignState, project_id: StringName, direction: int) -> OperationResult:
	var projects: Array[ProductionProjectState] = campaign.get_open_production_projects()
	var index: int = -1
	for i: int in range(projects.size()):
		if projects[i].project_id == project_id:
			index = i
			break
	if index < 0:
		return OperationResult.fail(&"production_project_missing", "The selected Production project is unavailable.")
	var target_index: int = clampi(index + signi(direction), 0, projects.size() - 1)
	if target_index == index:
		return OperationResult.no_change(projects[index], "Project priority is unchanged.")
	var other_priority: int = projects[target_index].priority
	projects[target_index].priority = projects[index].priority
	projects[index].priority = other_priority
	projects[target_index].revision += 1
	projects[index].revision += 1
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(projects[index], "Project priority updated.")


func cancel_candidate(campaign: CampaignState, project_id: StringName) -> OperationResult:
	var project: ProductionProjectState = campaign.get_production_project(project_id) if campaign != null else null
	if project == null or not project.is_open():
		return OperationResult.fail(&"production_project_missing", "The selected Production project cannot be cancelled.")
	if _reservation_service != null:
		_reservation_service.release_reservation_candidate(campaign, project.reservation_id, true)
	project.status = ProductionProjectState.STATUS_CANCELLED
	project.assigned_worker_count = 0
	project.revision += 1
	campaign.revision += 1
	_recalculate_assignments(campaign)
	return OperationResult.ok(project, "Production project cancelled; reserved inputs were released.")


func advance_candidate(campaign: CampaignState, tick_delta: int) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	if campaign == null or tick_delta <= 0:
		return completed
	var remaining_ticks: int = tick_delta
	var guard: int = 0
	while remaining_ticks > 0 and guard < 2048:
		guard += 1
		var completion_applied_before_work: bool = false
		for ready_project: ProductionProjectState in campaign.get_open_production_projects():
			if ready_project.remaining_work() > 0:
				continue
			var ready_completion: OperationResult = _complete_project_candidate(campaign, ready_project)
			if ready_completion.success:
				completion_applied_before_work = true
				completed.append(
					ready_completion.data as Dictionary
					if ready_completion.data is Dictionary
					else {"project_id": ready_project.project_id, "recipe_id": ready_project.recipe_id}
				)
			else:
				ready_project.status = ProductionProjectState.STATUS_PAUSED
				ready_project.pause_reason = ready_completion.message
				ready_project.assigned_worker_count = 0
				ready_project.revision += 1
		if completion_applied_before_work:
			continue
		_recalculate_assignments(campaign)
		var allocation: Dictionary = _workforce_assignment_resolver.resolve(campaign) if _workforce_assignment_resolver != null else {"projects": {}}
		var project_entries: Dictionary = allocation.get("projects", {}) as Dictionary
		var active_projects: Array[ProductionProjectState] = []
		var ticks_to_boundary: int = remaining_ticks
		for project: ProductionProjectState in campaign.get_open_production_projects():
			var entry: Dictionary = project_entries.get(project.project_id, {}) as Dictionary
			var daily_work: int = int(entry.get("daily_work", 0))
			project.assigned_worker_count = int(entry.get("assigned_count", 0))
			if daily_work <= 0:
				project.status = ProductionProjectState.STATUS_PAUSED
				project.pause_reason = String(entry.get("pause_reason", "No workers assigned."))
				continue
			project.status = ProductionProjectState.STATUS_ACTIVE
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
		for project: ProductionProjectState in active_projects:
			var entry: Dictionary = project_entries.get(project.project_id, {}) as Dictionary
			var daily_work: int = int(entry.get("daily_work", 0))
			project.work_accumulator_minutes += daily_work * step_ticks
			var gained_work: int = project.work_accumulator_minutes / MINUTES_PER_WORK
			project.work_accumulator_minutes = posmod(project.work_accumulator_minutes, MINUTES_PER_WORK)
			if gained_work > 0:
				project.completed_work = mini(project.total_work_required, project.completed_work + gained_work)
				project.last_progress_tick = campaign.campaign_tick - remaining_ticks + step_ticks
				project.revision += 1
		remaining_ticks -= step_ticks
		var boundary_completed: bool = false
		for project: ProductionProjectState in active_projects:
			if project.completed_work < project.total_work_required:
				continue
			var completion: OperationResult = _complete_project_candidate(campaign, project)
			if completion.success:
				boundary_completed = true
				completed.append(
					completion.data as Dictionary
					if completion.data is Dictionary
					else {"project_id": project.project_id, "recipe_id": project.recipe_id}
				)
		if not boundary_completed and step_ticks <= 0:
			break
	_recalculate_assignments(campaign)
	if not completed.is_empty():
		campaign.revision += 1
	return completed


func project_snapshot(campaign: CampaignState, project: ProductionProjectState) -> Dictionary:
	if campaign == null or project == null:
		return {}
	var recipe_value: ProductionRecipeDefinition = _production_catalogue.recipe(project.recipe_id) if _production_catalogue != null else null
	var allocation: Dictionary = _workforce_assignment_resolver.resolve(campaign) if _workforce_assignment_resolver != null else {"projects": {}}
	var entry: Dictionary = (allocation.get("projects", {}) as Dictionary).get(project.project_id, {}) as Dictionary
	var daily_work: int = int(entry.get("daily_work", 0))
	var days_remaining: int = 0
	if daily_work > 0:
		days_remaining = ceili(float(project.remaining_work()) / float(daily_work))
	return {
		"project": project,
		"recipe": recipe_value,
		"workers_assigned": int(entry.get("assigned_count", 0)),
		"time_remaining_days": days_remaining,
		"paused": daily_work <= 0,
		"pause_reason": String(entry.get("pause_reason", project.pause_reason)),
	}


func _complete_project_candidate(campaign: CampaignState, project: ProductionProjectState) -> OperationResult:
	if project.applied or project.status == ProductionProjectState.STATUS_APPLIED:
		return OperationResult.no_change(project, "Production output already applied.")
	var recipe_value: ProductionRecipeDefinition = _production_catalogue.recipe(project.recipe_id) if _production_catalogue != null else null
	var reservation = campaign.get_strategic_reservation(project.reservation_id)
	if recipe_value == null or reservation == null or not reservation.is_active():
		return OperationResult.fail(&"production_reservation_missing", "Reserved inputs are missing.")

	# Validate every irreversible result before consuming any resource. Strategic
	# time advances Production on a candidate campaign state, but the completion
	# operation must still be internally atomic and safe to reuse in tests/tools.
	for raw_resource_id: Variant in reservation.resource_quantities.keys():
		var resource_id := StringName(raw_resource_id)
		var required_amount: int = int(reservation.resource_quantities[raw_resource_id])
		if campaign.resources == null or campaign.resources.amount(resource_id) < required_amount:
			return OperationResult.fail(&"production_input_commit_failed", "Production resources changed before completion.")

	var repair_item: CampaignItemState = null
	var output_definition: ItemDefinition = null
	if recipe_value.project_type == ProductionRecipeDefinition.TYPE_REPAIR_ITEM:
		repair_item = campaign.get_item(project.target_item_id) as CampaignItemState
		if repair_item == null or repair_item.location == null or not repair_item.location.is_stronghold_storage():
			return OperationResult.fail(&"repair_target_changed", "The destroyed repair target is no longer in Storage.")
		if repair_item.condition > 0.0:
			return OperationResult.fail(&"repair_target_changed", "The destroyed repair target is no longer valid.")
		if not reservation.item_ids.has(repair_item.item_id):
			return OperationResult.fail(&"repair_reservation_changed", "The repair project no longer owns the exact target item reservation.")
	else:
		output_definition = _catalogue.item_definition(recipe_value.output_item_definition_id) if _catalogue != null else null
		if output_definition == null:
			return OperationResult.fail(&"production_output_missing", "The Production output definition is missing.")
		if _inventory_service != null:
			var resource_deltas: Dictionary = {}
			for raw_resource_id: Variant in reservation.resource_quantities.keys():
				resource_deltas[StringName(raw_resource_id)] = -int(reservation.resource_quantities[raw_resource_id])
			var projected_item_used: int = _inventory_service.used_item_storage_space(campaign) + project.output_storage_space
			var projected_resource_used: int = _inventory_service.projected_resource_storage_space(campaign, resource_deltas)
			var other_reserved_output: int = (
				_reservation_service.reserved_output_storage_space(campaign, project.reservation_id)
				if _reservation_service != null
				else 0
			)
			if projected_item_used + projected_resource_used + other_reserved_output > _inventory_service.maximum_storage_space(campaign):
				return OperationResult.fail(&"production_output_capacity_changed", "Storage no longer has enough capacity for the completed output.")

	for raw_resource_id: Variant in reservation.resource_quantities.keys():
		if not campaign.resources.add(StringName(raw_resource_id), -int(reservation.resource_quantities[raw_resource_id])):
			return OperationResult.fail(&"production_input_commit_failed", "Production resources changed before completion.")

	var output_item_ids: Array[StringName] = []
	if recipe_value.project_type == ProductionRecipeDefinition.TYPE_REPAIR_ITEM:
		repair_item.condition = (
			1.0
			if recipe_value.restore_to_full_condition
			else clampf(recipe_value.restored_condition, 0.01, 1.0)
		)
		repair_item.revision += 1
		output_item_ids.append(repair_item.item_id)
	else:
		var total_output: int = recipe_value.output_quantity * project.quantity
		var remaining: int = total_output
		while remaining > 0:
			var stack_quantity: int = 1
			if output_definition.stackable:
				stack_quantity = mini(remaining, output_definition.maximum_stack_size)
			var item_id: StringName = campaign.allocate_production_item_id()
			var item := CampaignItemState.new(
				item_id,
				output_definition.id,
				stack_quantity,
				1.0,
				CampaignItemLocationState.stronghold_storage()
			)
			if not campaign.add_item(item):
				return OperationResult.fail(&"production_output_commit_failed", "A manufactured item could not enter Storage.")
			output_item_ids.append(item_id)
			remaining -= stack_quantity

	_reservation_service.release_reservation_candidate(campaign, project.reservation_id, false)
	project.completed_work = project.total_work_required
	project.work_accumulator_minutes = 0
	project.status = ProductionProjectState.STATUS_APPLIED
	project.pause_reason = ""
	project.assigned_worker_count = 0
	project.applied = true
	project.revision += 1
	return OperationResult.ok(
		{
			"project_id": project.project_id,
			"recipe_id": project.recipe_id,
			"output_item_ids": output_item_ids,
		},
		"%s complete." % recipe_value.display_name
	)


func _recalculate_assignments(campaign: CampaignState) -> void:
	if campaign == null or _workforce_assignment_resolver == null:
		return
	var allocation: Dictionary = _workforce_assignment_resolver.resolve(campaign)
	var entries: Dictionary = allocation.get("projects", {}) as Dictionary
	for project: ProductionProjectState in campaign.get_open_production_projects():
		var entry: Dictionary = entries.get(project.project_id, {}) as Dictionary
		project.assigned_worker_count = int(entry.get("assigned_count", 0))
		if project.assigned_worker_count > 0:
			project.status = ProductionProjectState.STATUS_ACTIVE
			project.pause_reason = ""
		else:
			project.status = ProductionProjectState.STATUS_PAUSED
			project.pause_reason = String(entry.get("pause_reason", "No workers assigned."))


func _best_operational_facility(campaign: CampaignState, recipe_value: ProductionRecipeDefinition) -> Dictionary:
	if campaign == null or campaign.stronghold == null or _stronghold_registry == null:
		return {}
	var definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
	if definition == null:
		return {}
	var candidates: Array[Dictionary] = []
	for facility: StrongholdFacilityState in campaign.stronghold.get_facilities():
		if facility == null or facility.condition != StrongholdFacilityState.CONDITION_OPERATIONAL:
			continue
		if facility.definition_id != recipe_value.required_facility_definition_id or facility.level < recipe_value.minimum_facility_level:
			continue
		var facility_definition = definition.facility_definition(facility.definition_id)
		if facility_definition == null:
			continue
		candidates.append({"facility_id": facility.instance_id, "level": facility.level, "per_project": facility_definition.production_max_workers_for_level(facility.level)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("level", 0)) != int(b.get("level", 0)):
			return int(a.get("level", 0)) > int(b.get("level", 0))
		return String(a.get("facility_id", "")) < String(b.get("facility_id", ""))
	)
	return candidates[0] if not candidates.is_empty() else {}
