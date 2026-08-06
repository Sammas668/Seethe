class_name StrongholdDefinitionRegistry
extends RefCounted

const StrongholdDefinitionScript = preload("res://domain/stronghold/stronghold_definition.gd")
const StrongholdStateScript = preload("res://domain/stronghold/stronghold_state.gd")
const StrongholdPlotDefinitionScript = preload("res://domain/stronghold/stronghold_plot_definition.gd")
const StrongholdPlotStateScript = preload("res://domain/stronghold/stronghold_plot_state.gd")
const StrongholdFacilityStateScript = preload("res://domain/stronghold/stronghold_facility_state.gd")
const StrongholdConnectivityServiceScript = preload("res://application/stronghold/stronghold_connectivity_service.gd")
const StartingStrongholdFactoryScript = preload("res://infrastructure/content/stronghold/starting_stronghold_factory.gd")


var _definitions_by_id: Dictionary = {}


func configure() -> Array[String]:
	_definitions_by_id.clear()
	var starter: StrongholdDefinitionScript = StartingStrongholdFactoryScript.create_definition()
	if starter == null:
		return ["The authored starting stronghold could not be loaded."]
	_definitions_by_id[starter.id] = starter
	return validate_registry()


func definition(definition_id: StringName) -> StrongholdDefinitionScript:
	return _definitions_by_id.get(definition_id) as StrongholdDefinitionScript


func starting_definition() -> StrongholdDefinitionScript:
	return definition(StartingStrongholdFactoryScript.STARTING_STRONGHOLD_ID)


func create_initial_state(definition_id: StringName = &"") -> StrongholdStateScript:
	var resolved_id: StringName = (
		StartingStrongholdFactoryScript.STARTING_STRONGHOLD_ID
		if definition_id.is_empty()
		else definition_id
	)
	var definition_value: StrongholdDefinitionScript = definition(resolved_id)
	if definition_value == null:
		return null
	var state := StrongholdStateScript.new()
	state.definition_id = definition_value.id
	state.definition_layout_version = definition_value.layout_version
	for plot_definition: StrongholdPlotDefinitionScript in definition_value.all_plots():
		state.plots_by_key[plot_definition.key()] = _initial_plot_state(plot_definition)
	_create_starting_facility_states(definition_value, state)
	return state


func ensure_campaign_state(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	var definition_value: StrongholdDefinitionScript = starting_definition()
	if definition_value == null:
		return false
	if (
		campaign.stronghold == null
		or campaign.stronghold.definition_id != definition_value.id
		or campaign.stronghold.definition_layout_version != definition_value.layout_version
	):
		campaign.stronghold = create_initial_state(definition_value.id)
		campaign.revision += 1
		return true
	var changed: bool = false
	if campaign.stronghold.facilities_by_id.is_empty():
		_create_starting_facility_states(definition_value, campaign.stronghold)
		changed = true
	var authored_keys: Dictionary = {}
	for plot_definition: StrongholdPlotDefinitionScript in definition_value.all_plots():
		authored_keys[plot_definition.key()] = true
		if campaign.stronghold.get_plot(plot_definition.coord) != null:
			continue
		campaign.stronghold.plots_by_key[plot_definition.key()] = _initial_plot_state(plot_definition)
		changed = true
	for raw_key: Variant in campaign.stronghold.plots_by_key.keys():
		var key := StringName(raw_key)
		if authored_keys.has(key):
			continue
		campaign.stronghold.plots_by_key.erase(key)
		changed = true
	if changed:
		campaign.stronghold.revision += 1
		campaign.revision += 1
	return changed


func _create_starting_facility_states(
	definition_value: StrongholdDefinitionScript,
	state: StrongholdStateScript
) -> void:
	var observed: Dictionary = {}
	for plot_definition: StrongholdPlotDefinitionScript in definition_value.all_plots():
		var instance_id: StringName = plot_definition.fixed_facility_id
		if instance_id.is_empty() or observed.has(instance_id):
			continue
		observed[instance_id] = true
		var coords: Array[Vector2i] = definition_value.fixed_facility_coords(instance_id)
		if coords.is_empty():
			continue
		var facility := StrongholdFacilityStateScript.new()
		facility.instance_id = instance_id
		facility.definition_id = instance_id
		facility.origin = coords[0]
		facility.level = 1
		facility.is_starting_facility = true
		state.facilities_by_id[facility.instance_id] = facility


func validate_registry() -> Array[String]:
	var errors: Array[String] = []
	var connectivity := StrongholdConnectivityServiceScript.new()
	for raw_definition: Variant in _definitions_by_id.values():
		var definition_value: StrongholdDefinitionScript = raw_definition as StrongholdDefinitionScript
		if definition_value == null:
			errors.append("Stronghold registry contains a missing definition.")
			continue
		errors.append_array(definition_value.validate_definition())
		var initial_state: StrongholdStateScript = create_initial_state(definition_value.id)
		errors.append_array(initial_state.validate_state())
		errors.append_array(connectivity.validate_state(definition_value, initial_state))
	return errors


func _initial_plot_state(
	plot_definition: StrongholdPlotDefinitionScript
) -> StrongholdPlotStateScript:
	var plot_state := StrongholdPlotStateScript.new()
	plot_state.coord = plot_definition.coord
	plot_state.current_state = plot_definition.authored_state
	plot_state.facility_id = plot_definition.fixed_facility_id
	plot_state.damage_state = (
		StrongholdPlotStateScript.DAMAGE_RUINED
		if plot_definition.authored_state == StrongholdPlotDefinitionScript.RUINED
		else StrongholdPlotStateScript.DAMAGE_INTACT
	)
	return plot_state
