class_name StrongholdDefinition
extends RefCounted

const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")
const StrongholdFacilityPresentationDefinitionScript = preload("res://domain/stronghold/stronghold_facility_presentation_definition.gd")
const StrongholdFacilityDefinitionScript = preload("res://domain/stronghold/stronghold_facility_definition.gd")


var id: StringName = &""
var display_name: String = ""
var layout_version: int = 1
var width: int = 0
var height: int = 0
var plots_by_key: Dictionary = {}
var facility_presentations_by_id: Dictionary = {}
var facility_definitions_by_id: Dictionary = {}
var available_plot_art_paths: Array[String] = []
var primary_heart_coord: Vector2i = Vector2i.ZERO
var primary_access_coord: Vector2i = Vector2i.ZERO


func add_plot(plot: StrongholdPlotDefinitionScript) -> bool:
	if plot == null:
		return false
	var plot_key: StringName = plot.key()
	if plots_by_key.has(plot_key):
		return false
	plots_by_key[plot_key] = plot
	return true


func add_facility_presentation(
	presentation: StrongholdFacilityPresentationDefinitionScript
) -> bool:
	if presentation == null or presentation.id.is_empty():
		return false
	if facility_presentations_by_id.has(presentation.id):
		return false
	facility_presentations_by_id[presentation.id] = presentation
	return true


func facility_presentation(
	facility_id: StringName
) -> StrongholdFacilityPresentationDefinitionScript:
	return (
		facility_presentations_by_id.get(facility_id)
		as StrongholdFacilityPresentationDefinitionScript
	)


func add_facility_definition(
	definition: StrongholdFacilityDefinitionScript
) -> bool:
	if definition == null or definition.id.is_empty():
		return false
	if facility_definitions_by_id.has(definition.id):
		return false
	facility_definitions_by_id[definition.id] = definition
	return true


func facility_definition(
	definition_id: StringName
) -> StrongholdFacilityDefinitionScript:
	return facility_definitions_by_id.get(definition_id) as StrongholdFacilityDefinitionScript


func buildable_facilities() -> Array[StrongholdFacilityDefinitionScript]:
	var result: Array[StrongholdFacilityDefinitionScript] = []
	for raw_definition: Variant in facility_definitions_by_id.values():
		var definition: StrongholdFacilityDefinitionScript = raw_definition as StrongholdFacilityDefinitionScript
		if definition != null and definition.buildable:
			result.append(definition)
	result.sort_custom(
		func(a: StrongholdFacilityDefinitionScript, b: StrongholdFacilityDefinitionScript) -> bool:
			return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)
	return result


func plot_at(coord: Vector2i) -> StrongholdPlotDefinitionScript:
	return plots_by_key.get(coord_key(coord)) as StrongholdPlotDefinitionScript


func plot_at_xy(column: int, row: int) -> StrongholdPlotDefinitionScript:
	return plot_at(Vector2i(column, row))


func all_plots() -> Array[StrongholdPlotDefinitionScript]:
	var result: Array[StrongholdPlotDefinitionScript] = []
	for row: int in range(height):
		for column: int in range(width):
			var plot: StrongholdPlotDefinitionScript = plot_at_xy(column, row)
			if plot != null:
				result.append(plot)
	return result


func heart_plots() -> Array[StrongholdPlotDefinitionScript]:
	return plots_with_state(StrongholdPlotDefinitionScript.FIXED_HEART)


func plots_with_state(state: StringName) -> Array[StrongholdPlotDefinitionScript]:
	var result: Array[StrongholdPlotDefinitionScript] = []
	for plot: StrongholdPlotDefinitionScript in all_plots():
		if plot.authored_state == state:
			result.append(plot)
	return result


func fixed_facility_coords(facility_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if facility_id.is_empty():
		return result
	for plot: StrongholdPlotDefinitionScript in all_plots():
		if plot.fixed_facility_id == facility_id:
			result.append(plot.coord)
	result.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
	)
	return result


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Stronghold definition has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Stronghold %s has no display name." % id)
	if layout_version <= 0:
		errors.append("Stronghold %s has an invalid layout version." % id)
	if width <= 0 or height <= 0:
		errors.append("Stronghold %s has invalid dimensions." % id)
	if plots_by_key.size() != width * height:
		errors.append(
			"Stronghold %s has %d plots; expected %d."
			% [id, plots_by_key.size(), width * height]
		)
	for plot: StrongholdPlotDefinitionScript in all_plots():
		errors.append_array(plot.validate_definition(width, height))
	for raw_presentation: Variant in facility_presentations_by_id.values():
		var presentation: StrongholdFacilityPresentationDefinitionScript = (
			raw_presentation as StrongholdFacilityPresentationDefinitionScript
		)
		if presentation == null:
			errors.append("Stronghold %s contains an invalid facility presentation." % id)
			continue
		errors.append_array(presentation.validate_definition())
	for raw_facility_definition: Variant in facility_definitions_by_id.values():
		var facility_definition: StrongholdFacilityDefinitionScript = (
			raw_facility_definition as StrongholdFacilityDefinitionScript
		)
		if facility_definition == null:
			errors.append("Stronghold %s contains an invalid facility definition." % id)
			continue
		errors.append_array(facility_definition.validate_definition())
		var facility_art: StrongholdFacilityPresentationDefinitionScript = facility_presentation(
			facility_definition.presentation_id
		)
		if facility_art == null:
			errors.append(
				"Stronghold facility %s references missing presentation %s."
				% [facility_definition.id, facility_definition.presentation_id]
			)
		elif facility_art.expected_footprint != facility_definition.footprint:
			errors.append(
				"Stronghold facility %s footprint does not match presentation %s."
				% [facility_definition.id, facility_definition.presentation_id]
			)
	if heart_plots().is_empty():
		errors.append("Stronghold %s has no fixed Heart." % id)
	if (
		plot_at(primary_heart_coord) == null
		or plot_at(primary_heart_coord).authored_state
		!= StrongholdPlotDefinitionScript.FIXED_HEART
	):
		errors.append("Stronghold %s has an invalid primary Heart coordinate." % id)
	if plot_at(primary_access_coord) == null:
		errors.append("Stronghold %s has an invalid primary access coordinate." % id)
	errors.append_array(_validate_fixed_facility_footprints())
	return errors


func _validate_fixed_facility_footprints() -> Array[String]:
	var errors: Array[String] = []
	var facility_ids: Dictionary = {}
	for plot: StrongholdPlotDefinitionScript in all_plots():
		if not plot.fixed_facility_id.is_empty():
			facility_ids[plot.fixed_facility_id] = true
	for raw_id: Variant in facility_ids.keys():
		var facility_id := StringName(raw_id)
		var coords: Array[Vector2i] = fixed_facility_coords(facility_id)
		if coords.is_empty():
			continue
		var minimum: Vector2i = coords[0]
		var maximum: Vector2i = coords[0]
		for coord: Vector2i in coords:
			minimum.x = mini(minimum.x, coord.x)
			minimum.y = mini(minimum.y, coord.y)
			maximum.x = maxi(maximum.x, coord.x)
			maximum.y = maxi(maximum.y, coord.y)
		var footprint: Vector2i = maximum - minimum + Vector2i.ONE
		if coords.size() != footprint.x * footprint.y:
			errors.append(
				"Fixed facility %s does not occupy one rectangular footprint." % facility_id
			)
		var presentation: StrongholdFacilityPresentationDefinitionScript = (
			facility_presentation(facility_id)
		)
		if presentation != null and presentation.expected_footprint != footprint:
			errors.append(
				"Fixed facility %s occupies %d x %d but its presentation expects %d x %d."
				% [
					facility_id,
					footprint.x,
					footprint.y,
					presentation.expected_footprint.x,
					presentation.expected_footprint.y,
				]
			)
	return errors


static func coord_key(coord: Vector2i) -> StringName:
	return StringName("%d,%d" % [coord.x, coord.y])
