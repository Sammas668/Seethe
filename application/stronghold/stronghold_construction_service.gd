class_name StrongholdConstructionService
extends RefCounted

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdStateScript = preload("res://domain/stronghold/stronghold_state.gd")
const StrongholdFacilityDefinitionScript = preload("res://domain/stronghold/stronghold_facility_definition.gd")
const StrongholdFacilityStateScript = preload("res://domain/stronghold/stronghold_facility_state.gd")
const StrongholdProjectStateScript = preload("res://domain/stronghold/stronghold_project_state.gd")
const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")
const StrongholdPlotStateScript = preload("res://domain/stronghold/stronghold_plot_state.gd")
const StrongholdPrototypeRulesScript = preload("res://domain/stronghold/stronghold_prototype_rules.gd")

var prototype_rules: StrongholdPrototypeRulesScript = StrongholdPrototypeRulesScript.enabled_defaults()


func build_catalogue(definition: StrongholdDefinitionScript) -> Array[StrongholdFacilityDefinitionScript]:
	var result: Array[StrongholdFacilityDefinitionScript] = []
	if definition == null:
		return result
	return definition.buildable_facilities()


func preview_build(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript,
	facility_definition_id: StringName,
	origin: Vector2i
) -> OperationResult:
	if definition == null or state == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold data is unavailable.")
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(facility_definition_id)
	if facility_definition == null:
		return OperationResult.fail(&"facility_definition_missing", "This facility is not available to construct.")
	if not facility_definition.buildable and not prototype_rules.unlock_all_facilities:
		return OperationResult.fail(&"facility_locked", "This facility is not available to construct.")
	if facility_definition.unique and state.count_facilities_with_definition(facility_definition.id) > 0:
		return OperationResult.fail(&"facility_unique", "Only one instance may be constructed.")
	var coords: Array[Vector2i] = footprint_coords(origin, facility_definition.footprint)
	for coord: Vector2i in coords:
		if coord.x < 0 or coord.y < 0 or coord.x >= definition.width or coord.y >= definition.height:
			return OperationResult.fail(&"facility_out_of_bounds", "Extends beyond the stronghold grid.")
		var plot: StrongholdPlotStateScript = state.get_plot(coord)
		if plot == null:
			return OperationResult.fail(&"facility_plot_missing", "One or more plots are unavailable.")
		if plot.current_state == StrongholdPlotDefinitionScript.FIXED_HEART:
			return OperationResult.fail(&"facility_overlaps_heart", "Footprint overlaps the Fifth-God Heart.")
		if not plot.facility_id.is_empty():
			var occupying_definition: StringName = state.facility_definition_id(plot.facility_id)
			if occupying_definition == &"facility.stables":
				return OperationResult.fail(&"facility_overlaps_stables", "Footprint overlaps the Stables.")
			return OperationResult.fail(&"facility_overlap", "One or more plots are already occupied.")
		if plot.current_state != StrongholdPlotDefinitionScript.AVAILABLE:
			return OperationResult.fail(&"facility_plot_unavailable", "One or more plots are not available for construction.")
	return OperationResult.ok(
		{
			"facility_definition_id": facility_definition.id,
			"origin": origin,
			"footprint": facility_definition.footprint,
			"coords": coords,
			"duration_minutes": facility_definition.construction_duration_minutes,
		},
		"Placement is valid."
	)


func construct_candidate(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript,
	facility_definition_id: StringName,
	origin: Vector2i,
	start_tick: int
) -> OperationResult:
	var preview: OperationResult = preview_build(definition, state, facility_definition_id, origin)
	if not preview.success:
		return preview
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(facility_definition_id)
	var instance_id: StringName = state.allocate_facility_instance_id(facility_definition.id)
	var facility := StrongholdFacilityStateScript.new()
	facility.instance_id = instance_id
	facility.definition_id = facility_definition.id
	facility.origin = origin
	facility.level = 1
	facility.condition = StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION
	var project := StrongholdProjectStateScript.new()
	project.project_id = state.allocate_project_id(StrongholdProjectStateScript.KIND_CONSTRUCTION)
	project.project_kind = StrongholdProjectStateScript.KIND_CONSTRUCTION
	project.facility_instance_id = facility.instance_id
	project.facility_definition_id = facility.definition_id
	project.start_tick = maxi(0, start_tick)
	project.completion_tick = project.start_tick + maxi(1, facility_definition.construction_duration_minutes)
	project.target_level = 1
	facility.active_project_id = project.project_id
	state.facilities_by_id[facility.instance_id] = facility
	state.projects_by_id[project.project_id] = project
	var coords: Array = (preview.data as Dictionary).get("coords", []) as Array
	for raw_coord: Variant in coords:
		var coord: Vector2i = raw_coord as Vector2i
		var plot: StrongholdPlotStateScript = state.get_plot(coord)
		plot.current_state = StrongholdPlotDefinitionScript.OCCUPIED
		plot.facility_id = instance_id
		plot.project_id = project.project_id
		plot.damage_state = StrongholdPlotStateScript.DAMAGE_INTACT
		plot.revision += 1
	state.revision += 1
	return OperationResult.ok(
		{
			"facility": facility,
			"project": project,
		},
		"%s construction started." % facility_definition.display_name
	)


func upgrade_candidate(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript,
	facility_instance_id: StringName,
	start_tick: int
) -> OperationResult:
	if definition == null or state == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold data is unavailable.")
	var facility: StrongholdFacilityStateScript = state.get_facility(facility_instance_id)
	if facility == null:
		return OperationResult.fail(&"facility_missing", "The selected facility no longer exists.")
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(facility.definition_id)
	if facility_definition == null:
		return OperationResult.fail(&"facility_definition_missing", "The selected facility definition is missing.")
	if not facility.active_project_id.is_empty():
		return OperationResult.fail(&"facility_busy", "This facility already has an active project.")
	if facility.condition != StrongholdFacilityStateScript.CONDITION_OPERATIONAL:
		return OperationResult.fail(&"facility_not_operational", "This facility cannot be upgraded in its current condition.")
	if facility.level >= facility_definition.max_level:
		return OperationResult.fail(&"facility_max_level", "This facility is already at its maximum level.")
	if not prototype_rules.unlock_all_upgrades:
		return OperationResult.fail(&"facility_upgrade_locked", "The next upgrade is not yet unlocked.")
	var target_level: int = facility.level + 1
	var project := StrongholdProjectStateScript.new()
	project.project_id = state.allocate_project_id(StrongholdProjectStateScript.KIND_UPGRADE)
	project.project_kind = StrongholdProjectStateScript.KIND_UPGRADE
	project.facility_instance_id = facility.instance_id
	project.facility_definition_id = facility.definition_id
	project.start_tick = maxi(0, start_tick)
	project.completion_tick = project.start_tick + facility_definition.upgrade_duration_for_target_level(target_level)
	project.target_level = target_level
	facility.condition = StrongholdFacilityStateScript.CONDITION_UPGRADING
	facility.active_project_id = project.project_id
	facility.revision += 1
	state.projects_by_id[project.project_id] = project
	for plot: StrongholdPlotStateScript in state.plots_for_facility(facility_instance_id):
		plot.project_id = project.project_id
		plot.revision += 1
	state.revision += 1
	return OperationResult.ok(
		{
			"facility": facility,
			"project": project,
		},
		"%s upgrade started." % facility_definition.display_name
	)


func cancel_project_candidate(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript,
	project_id: StringName
) -> OperationResult:
	if definition == null or state == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold data is unavailable.")
	var project: StrongholdProjectStateScript = state.get_project(project_id)
	if project == null:
		return OperationResult.fail(&"stronghold_project_missing", "The selected stronghold project no longer exists.")
	var facility: StrongholdFacilityStateScript = state.get_facility(project.facility_instance_id)
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(project.facility_definition_id)
	var display_name: String = facility_definition.display_name if facility_definition != null else "Facility"
	if project.project_kind == StrongholdProjectStateScript.KIND_CONSTRUCTION:
		for plot: StrongholdPlotStateScript in state.plots_for_facility(project.facility_instance_id):
			plot.current_state = StrongholdPlotDefinitionScript.AVAILABLE
			plot.facility_id = &""
			plot.project_id = &""
			plot.damage_state = StrongholdPlotStateScript.DAMAGE_INTACT
			plot.revision += 1
		state.facilities_by_id.erase(project.facility_instance_id)
	else:
		if facility != null:
			facility.condition = StrongholdFacilityStateScript.CONDITION_OPERATIONAL
			facility.active_project_id = &""
			facility.revision += 1
		for plot: StrongholdPlotStateScript in state.plots_for_facility(project.facility_instance_id):
			plot.project_id = &""
			plot.revision += 1
	state.projects_by_id.erase(project.project_id)
	state.revision += 1
	return OperationResult.ok(null, "%s project cancelled." % display_name)


func demolish_candidate(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript,
	facility_instance_id: StringName
) -> OperationResult:
	if definition == null or state == null:
		return OperationResult.fail(&"stronghold_missing", "Stronghold data is unavailable.")
	var facility: StrongholdFacilityStateScript = state.get_facility(facility_instance_id)
	if facility == null:
		return OperationResult.fail(&"facility_missing", "The selected facility no longer exists.")
	var facility_definition: StrongholdFacilityDefinitionScript = definition.facility_definition(facility.definition_id)
	if facility_definition == null:
		return OperationResult.fail(&"facility_definition_missing", "The selected facility definition is missing.")
	if not facility.active_project_id.is_empty():
		return OperationResult.fail(&"facility_busy", "Cancel the active project before demolishing this facility.")
	if not facility_definition.demolishable:
		return OperationResult.fail(&"facility_not_demolishable", "%s cannot be demolished." % facility_definition.display_name)
	for plot: StrongholdPlotStateScript in state.plots_for_facility(facility_instance_id):
		plot.current_state = StrongholdPlotDefinitionScript.AVAILABLE
		plot.facility_id = &""
		plot.project_id = &""
		plot.damage_state = StrongholdPlotStateScript.DAMAGE_INTACT
		plot.revision += 1
	state.facilities_by_id.erase(facility_instance_id)
	state.revision += 1
	return OperationResult.ok(null, "%s demolished." % facility_definition.display_name)


func advance_candidate(
	definition: StrongholdDefinitionScript,
	state: StrongholdStateScript,
	campaign_tick: int
) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	if definition == null or state == null:
		return completed
	var completed_ids: Array[StringName] = []
	for project: StrongholdProjectStateScript in state.get_projects():
		if not project.is_complete(campaign_tick):
			continue
		var facility: StrongholdFacilityStateScript = state.get_facility(project.facility_instance_id)
		if facility == null:
			completed_ids.append(project.project_id)
			continue
		if project.project_kind == StrongholdProjectStateScript.KIND_UPGRADE:
			facility.level = maxi(facility.level, project.target_level)
		facility.condition = StrongholdFacilityStateScript.CONDITION_OPERATIONAL
		facility.active_project_id = &""
		facility.revision += 1
		for plot: StrongholdPlotStateScript in state.plots_for_facility(facility.instance_id):
			plot.project_id = &""
			plot.revision += 1
		completed.append({
			"project_id": project.project_id,
			"project_kind": project.project_kind,
			"facility_instance_id": project.facility_instance_id,
			"facility_definition_id": project.facility_definition_id,
			"target_level": project.target_level,
		})
		completed_ids.append(project.project_id)
	for project_id: StringName in completed_ids:
		state.projects_by_id.erase(project_id)
	if not completed_ids.is_empty():
		state.revision += 1
	return completed


static func footprint_coords(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row: int in range(footprint.y):
		for column: int in range(footprint.x):
			result.append(origin + Vector2i(column, row))
	return result
