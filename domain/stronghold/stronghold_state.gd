class_name StrongholdState
extends RefCounted

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdPlotStateScript = preload("res://domain/stronghold/stronghold_plot_state.gd")
const StrongholdFacilityStateScript = preload("res://domain/stronghold/stronghold_facility_state.gd")
const StrongholdProjectStateScript = preload("res://domain/stronghold/stronghold_project_state.gd")


var definition_id: StringName = &""
var definition_layout_version: int = 0
var plots_by_key: Dictionary = {}
var facilities_by_id: Dictionary = {}
var projects_by_id: Dictionary = {}
var next_facility_serial: int = 1
var next_project_serial: int = 1
var revision: int = 0


func get_plot(coord: Vector2i) -> StrongholdPlotStateScript:
	return plots_by_key.get(StrongholdDefinitionScript.coord_key(coord)) as StrongholdPlotStateScript


func get_plots() -> Array[StrongholdPlotStateScript]:
	var result: Array[StrongholdPlotStateScript] = []
	for raw_plot: Variant in plots_by_key.values():
		var plot: StrongholdPlotStateScript = raw_plot as StrongholdPlotStateScript
		if plot != null:
			result.append(plot)
	result.sort_custom(
		func(a: StrongholdPlotStateScript, b: StrongholdPlotStateScript) -> bool:
			if a.coord.y != b.coord.y:
				return a.coord.y < b.coord.y
			return a.coord.x < b.coord.x
	)
	return result


func get_facility(instance_id: StringName) -> StrongholdFacilityStateScript:
	return facilities_by_id.get(instance_id) as StrongholdFacilityStateScript


func get_facilities() -> Array[StrongholdFacilityStateScript]:
	var result: Array[StrongholdFacilityStateScript] = []
	for raw_facility: Variant in facilities_by_id.values():
		var facility: StrongholdFacilityStateScript = raw_facility as StrongholdFacilityStateScript
		if facility != null:
			result.append(facility)
	result.sort_custom(
		func(a: StrongholdFacilityStateScript, b: StrongholdFacilityStateScript) -> bool:
			if a.origin.y != b.origin.y:
				return a.origin.y < b.origin.y
			return a.origin.x < b.origin.x
	)
	return result


func get_project(project_id: StringName) -> StrongholdProjectStateScript:
	return projects_by_id.get(project_id) as StrongholdProjectStateScript


func get_projects() -> Array[StrongholdProjectStateScript]:
	var result: Array[StrongholdProjectStateScript] = []
	for raw_project: Variant in projects_by_id.values():
		var project: StrongholdProjectStateScript = raw_project as StrongholdProjectStateScript
		if project != null:
			result.append(project)
	result.sort_custom(
		func(a: StrongholdProjectStateScript, b: StrongholdProjectStateScript) -> bool:
			if a.completion_tick != b.completion_tick:
				return a.completion_tick < b.completion_tick
			return String(a.project_id) < String(b.project_id)
	)
	return result


func project_for_facility(facility_id: StringName) -> StrongholdProjectStateScript:
	var facility: StrongholdFacilityStateScript = get_facility(facility_id)
	if facility != null and not facility.active_project_id.is_empty():
		return get_project(facility.active_project_id)
	for project: StrongholdProjectStateScript in get_projects():
		if project.facility_instance_id == facility_id:
			return project
	return null


func count_facilities_with_definition(definition_id_value: StringName) -> int:
	var count: int = 0
	for facility: StrongholdFacilityStateScript in get_facilities():
		if facility.definition_id == definition_id_value:
			count += 1
	return count


func plots_for_facility(facility_id: StringName) -> Array[StrongholdPlotStateScript]:
	var result: Array[StrongholdPlotStateScript] = []
	if facility_id.is_empty():
		return result
	for plot: StrongholdPlotStateScript in get_plots():
		if plot.facility_id == facility_id:
			result.append(plot)
	return result


func facility_origin(facility_id: StringName) -> Vector2i:
	var facility: StrongholdFacilityStateScript = get_facility(facility_id)
	if facility != null:
		return facility.origin
	var plots: Array[StrongholdPlotStateScript] = plots_for_facility(facility_id)
	if plots.is_empty():
		return Vector2i(-1, -1)
	var origin: Vector2i = plots[0].coord
	for plot: StrongholdPlotStateScript in plots:
		origin.x = mini(origin.x, plot.coord.x)
		origin.y = mini(origin.y, plot.coord.y)
	return origin


func facility_footprint(facility_id: StringName) -> Vector2i:
	var plots: Array[StrongholdPlotStateScript] = plots_for_facility(facility_id)
	if plots.is_empty():
		return Vector2i.ZERO
	var minimum: Vector2i = plots[0].coord
	var maximum: Vector2i = plots[0].coord
	for plot: StrongholdPlotStateScript in plots:
		minimum.x = mini(minimum.x, plot.coord.x)
		minimum.y = mini(minimum.y, plot.coord.y)
		maximum.x = maxi(maximum.x, plot.coord.x)
		maximum.y = maxi(maximum.y, plot.coord.y)
	return maximum - minimum + Vector2i.ONE


func facility_definition_id(facility_id: StringName) -> StringName:
	var facility: StrongholdFacilityStateScript = get_facility(facility_id)
	return facility.definition_id if facility != null else facility_id


func canonical_coord(coord: Vector2i) -> Vector2i:
	var plot: StrongholdPlotStateScript = get_plot(coord)
	if plot == null or plot.facility_id.is_empty():
		return coord
	var origin: Vector2i = facility_origin(plot.facility_id)
	return coord if origin.x < 0 else origin


func allocate_facility_instance_id(definition_id_value: StringName) -> StringName:
	var safe_name: String = String(definition_id_value).replace("facility.", "").replace(".", "_")
	var result := StringName("facility_instance.%s.%04d" % [safe_name, next_facility_serial])
	next_facility_serial += 1
	return result


func allocate_project_id(project_kind: StringName) -> StringName:
	var safe_kind: String = String(project_kind).replace(".", "_")
	var result := StringName("stronghold_project.%s.%04d" % [safe_kind, next_project_serial])
	next_project_serial += 1
	return result


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if definition_id.is_empty():
		errors.append("Campaign stronghold has no definition ID.")
	if definition_layout_version < 0:
		errors.append("Campaign stronghold has an invalid definition layout version.")
	if plots_by_key.is_empty():
		errors.append("Campaign stronghold has no plot states.")
	var observed: Dictionary = {}
	for plot: StrongholdPlotStateScript in get_plots():
		errors.append_array(plot.validate_state())
		if observed.has(plot.key()):
			errors.append("Campaign stronghold repeats plot %s." % plot.key())
		observed[plot.key()] = true
		if not plot.facility_id.is_empty() and not facilities_by_id.has(plot.facility_id):
			errors.append("Plot %s references missing facility %s." % [plot.key(), plot.facility_id])
		if not plot.project_id.is_empty() and not projects_by_id.has(plot.project_id):
			errors.append("Plot %s references missing stronghold project %s." % [plot.key(), plot.project_id])
	for facility: StrongholdFacilityStateScript in get_facilities():
		errors.append_array(facility.validate_state())
		if plots_for_facility(facility.instance_id).is_empty():
			errors.append("Stronghold facility %s occupies no plots." % facility.instance_id)
		if not facility.active_project_id.is_empty() and not projects_by_id.has(facility.active_project_id):
			errors.append("Stronghold facility %s references missing project %s." % [facility.instance_id, facility.active_project_id])
	for project: StrongholdProjectStateScript in get_projects():
		errors.append_array(project.validate_state())
		if not facilities_by_id.has(project.facility_instance_id):
			errors.append("Stronghold project %s references missing facility %s." % [project.project_id, project.facility_instance_id])
	return errors


func to_dictionary() -> Dictionary:
	var serialized_plots: Array[Dictionary] = []
	for plot: StrongholdPlotStateScript in get_plots():
		serialized_plots.append(plot.to_dictionary())
	var serialized_facilities: Array[Dictionary] = []
	for facility: StrongholdFacilityStateScript in get_facilities():
		serialized_facilities.append(facility.to_dictionary())
	var serialized_projects: Array[Dictionary] = []
	for project: StrongholdProjectStateScript in get_projects():
		serialized_projects.append(project.to_dictionary())
	return {
		"definition_id": String(definition_id),
		"definition_layout_version": definition_layout_version,
		"plots": serialized_plots,
		"facilities": serialized_facilities,
		"projects": serialized_projects,
		"next_facility_serial": next_facility_serial,
		"next_project_serial": next_project_serial,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> StrongholdState:
	var result := StrongholdState.new()
	result.definition_id = StringName(data.get("definition_id", ""))
	result.definition_layout_version = maxi(0, int(data.get("definition_layout_version", 0)))
	var raw_plots: Variant = data.get("plots", [])
	if raw_plots is Array:
		for raw_plot: Variant in raw_plots as Array:
			if not raw_plot is Dictionary:
				continue
			var plot := StrongholdPlotStateScript.from_dictionary(raw_plot as Dictionary)
			result.plots_by_key[plot.key()] = plot
	var raw_facilities: Variant = data.get("facilities", [])
	if raw_facilities is Array:
		for raw_facility: Variant in raw_facilities as Array:
			if not raw_facility is Dictionary:
				continue
			var facility := StrongholdFacilityStateScript.from_dictionary(raw_facility as Dictionary)
			if not facility.instance_id.is_empty():
				result.facilities_by_id[facility.instance_id] = facility
	var raw_projects: Variant = data.get("projects", [])
	if raw_projects is Array:
		for raw_project: Variant in raw_projects as Array:
			if not raw_project is Dictionary:
				continue
			var project := StrongholdProjectStateScript.from_dictionary(raw_project as Dictionary)
			if not project.project_id.is_empty():
				result.projects_by_id[project.project_id] = project
	result.next_facility_serial = maxi(1, int(data.get("next_facility_serial", 1)))
	result.next_project_serial = maxi(1, int(data.get("next_project_serial", 1)))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result
