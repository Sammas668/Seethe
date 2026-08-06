class_name StartingStrongholdFactory
extends RefCounted

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")
const StrongholdFacilityPresentationDefinitionScript = preload("res://domain/stronghold/stronghold_facility_presentation_definition.gd")
const StrongholdFacilityDefinitionScript = preload("res://domain/stronghold/stronghold_facility_definition.gd")


const STARTING_STRONGHOLD_ID: StringName = &"stronghold.fifth_god.starting_ruin"
const DEFINITION_PATH: String = "res://content/stronghold/starting_ruin/starting_ruin.json"


static func create_definition() -> StrongholdDefinitionScript:
	var data: Dictionary = _read_json_dictionary(DEFINITION_PATH)
	if data.is_empty():
		push_error("Starting stronghold definition could not be loaded.")
		return null
	var definition := StrongholdDefinitionScript.new()
	definition.id = StringName(data.get("id", ""))
	definition.display_name = String(data.get("display_name", ""))
	definition.layout_version = maxi(1, int(data.get("layout_version", 1)))
	definition.width = int(data.get("width", 0))
	definition.height = int(data.get("height", 0))
	definition.primary_heart_coord = _coord_from_pair(data.get("primary_heart_coord", [0, 0]))
	definition.primary_access_coord = _coord_from_pair(data.get("primary_access_coord", [0, 0]))
	var raw_art_paths: Variant = data.get("available_plot_art_paths", [])
	if raw_art_paths is Array:
		for raw_path: Variant in raw_art_paths as Array:
			var art_path := String(raw_path)
			if not art_path.is_empty():
				definition.available_plot_art_paths.append(art_path)
	_load_facility_presentations(definition, data.get("facility_presentations", []))
	_load_facility_definitions(definition, data.get("facilities", []))
	var raw_plots: Variant = data.get("plots", [])
	if raw_plots is Array:
		for raw_plot: Variant in raw_plots as Array:
			if not raw_plot is Dictionary:
				continue
			var entry: Dictionary = raw_plot as Dictionary
			var plot := StrongholdPlotDefinitionScript.new()
			plot.coord = _coord_from_pair(entry.get("coord", [0, 0]))
			plot.authored_state = StringName(entry.get("state", StrongholdPlotDefinitionScript.AVAILABLE))
			plot.display_name = String(entry.get("display_name", ""))
			plot.description = String(entry.get("description", ""))
			plot.fixed_facility_id = StringName(entry.get("fixed_facility_id", ""))
			var raw_tags: Variant = entry.get("tags", [])
			if raw_tags is Array:
				for raw_tag: Variant in raw_tags as Array:
					var tag := StringName(raw_tag)
					if not tag.is_empty():
						plot.tags.append(tag)
			if not definition.add_plot(plot):
				push_error("Duplicate stronghold plot %s." % plot.key())
				return null
	var errors: Array[String] = definition.validate_definition()
	if not errors.is_empty():
		push_error("Starting stronghold is invalid: %s" % errors[0])
		return null
	return definition


static func _load_facility_presentations(
	definition: StrongholdDefinitionScript,
	raw_presentations: Variant
) -> void:
	if not raw_presentations is Array:
		return
	for raw_presentation: Variant in raw_presentations as Array:
		if not raw_presentation is Dictionary:
			continue
		var entry: Dictionary = raw_presentation as Dictionary
		var presentation := StrongholdFacilityPresentationDefinitionScript.new()
		presentation.id = StringName(entry.get("id", ""))
		presentation.display_name = String(entry.get("display_name", ""))
		presentation.description = String(entry.get("description", ""))
		presentation.art_path = String(entry.get("art_path", ""))
		presentation.fallback_symbol = String(entry.get("fallback_symbol", ""))
		presentation.accent_color = String(entry.get("accent_color", "c5a35b"))
		presentation.expected_footprint = _coord_from_pair(
			entry.get("expected_footprint", [1, 1])
		)
		if not definition.add_facility_presentation(presentation):
			push_error("Duplicate stronghold facility presentation %s." % presentation.id)




static func _load_facility_definitions(
	definition: StrongholdDefinitionScript,
	raw_definitions: Variant
) -> void:
	if not raw_definitions is Array:
		return
	for raw_definition: Variant in raw_definitions as Array:
		if not raw_definition is Dictionary:
			continue
		var entry: Dictionary = raw_definition as Dictionary
		var facility := StrongholdFacilityDefinitionScript.new()
		facility.id = StringName(entry.get("id", ""))
		facility.display_name = String(entry.get("display_name", ""))
		facility.description = String(entry.get("description", ""))
		facility.presentation_id = StringName(entry.get("presentation_id", facility.id))
		facility.footprint = _coord_from_pair(entry.get("footprint", [1, 1]))
		facility.buildable = bool(entry.get("buildable", true))
		facility.unique = bool(entry.get("unique", false))
		facility.max_level = maxi(1, int(entry.get("max_level", 3)))
		facility.demolishable = bool(entry.get("demolishable", true))
		facility.starting_facility = bool(entry.get("starting_facility", false))
		facility.category = StringName(entry.get("category", "support"))
		facility.construction_duration_minutes = maxi(
			1,
			int(entry.get("construction_duration_minutes", 720))
		)
		var raw_upgrade_durations: Variant = entry.get("upgrade_duration_minutes", [])
		if raw_upgrade_durations is Array:
			for raw_duration: Variant in raw_upgrade_durations as Array:
				facility.upgrade_duration_minutes.append(maxi(1, int(raw_duration)))
		var raw_storage_capacity: Variant = entry.get("storage_capacity_by_level", [])
		if raw_storage_capacity is Array:
			for raw_capacity: Variant in raw_storage_capacity as Array:
				facility.storage_capacity_by_level.append(maxi(0, int(raw_capacity)))
		var raw_recovery_bonus: Variant = entry.get("recovery_rate_bonus_by_level", [])
		if raw_recovery_bonus is Array:
			for raw_bonus: Variant in raw_recovery_bonus as Array:
				facility.recovery_rate_bonus_by_level.append(maxi(0, int(raw_bonus)))
		var raw_stable_space: Variant = entry.get("stable_space_by_level", [])
		if raw_stable_space is Array:
			for raw_space: Variant in raw_stable_space as Array:
				facility.stable_space_by_level.append(maxi(0, int(raw_space)))
		var raw_prison_capacity: Variant = entry.get("prison_capacity_by_level", [])
		if raw_prison_capacity is Array:
			for raw_capacity: Variant in raw_prison_capacity as Array:
				facility.prison_capacity_by_level.append(maxi(0, int(raw_capacity)))
		var raw_personnel_capacity: Variant = entry.get("personnel_capacity_by_level", [])
		if raw_personnel_capacity is Array:
			for raw_capacity: Variant in raw_personnel_capacity as Array:
				facility.personnel_capacity_by_level.append(maxi(0, int(raw_capacity)))
		var raw_production_slots: Variant = entry.get("production_project_slots_by_level", [])
		if raw_production_slots is Array:
			for raw_slot_count: Variant in raw_production_slots as Array:
				facility.production_project_slots_by_level.append(maxi(0, int(raw_slot_count)))
		var raw_production_positions: Variant = entry.get("production_worker_positions_by_level", [])
		if raw_production_positions is Array:
			for raw_position_count: Variant in raw_production_positions as Array:
				facility.production_worker_positions_by_level.append(maxi(0, int(raw_position_count)))
		var raw_production_project_limits: Variant = entry.get("production_max_workers_per_project_by_level", [])
		if raw_production_project_limits is Array:
			for raw_project_limit: Variant in raw_production_project_limits as Array:
				facility.production_max_workers_per_project_by_level.append(maxi(0, int(raw_project_limit)))
		var raw_research_slots: Variant = entry.get("research_project_slots_by_level", [])
		if raw_research_slots is Array:
			for raw_slot_count: Variant in raw_research_slots as Array:
				facility.research_project_slots_by_level.append(maxi(0, int(raw_slot_count)))
		var raw_research_positions: Variant = entry.get("research_worker_positions_by_level", [])
		if raw_research_positions is Array:
			for raw_position_count: Variant in raw_research_positions as Array:
				facility.research_worker_positions_by_level.append(maxi(0, int(raw_position_count)))
		var raw_research_project_limits: Variant = entry.get("research_max_workers_per_project_by_level", [])
		if raw_research_project_limits is Array:
			for raw_project_limit: Variant in raw_research_project_limits as Array:
				facility.research_max_workers_per_project_by_level.append(maxi(0, int(raw_project_limit)))
		var raw_benefits: Variant = entry.get("benefits", [])
		if raw_benefits is Array:
			for raw_benefit: Variant in raw_benefits as Array:
				var benefit := String(raw_benefit).strip_edges()
				if not benefit.is_empty():
					facility.benefit_lines.append(benefit)
		if not definition.add_facility_definition(facility):
			push_error("Duplicate stronghold facility definition %s." % facility.id)


static func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


static func _coord_from_pair(raw_value: Variant) -> Vector2i:
	if raw_value is Array and (raw_value as Array).size() >= 2:
		return Vector2i(int((raw_value as Array)[0]), int((raw_value as Array)[1]))
	return Vector2i.ZERO
