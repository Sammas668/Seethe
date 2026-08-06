class_name Stage52aUpdate1UnifiedFacilityTests
extends RefCounted

const StrongholdDefinitionRegistryScript = preload("res://application/stronghold/stronghold_definition_registry.gd")
const StrongholdConstructionServiceScript = preload("res://application/stronghold/stronghold_construction_service.gd")
const StrongholdGridViewScript = preload("res://presentation/campaign/widgets/stronghold_grid_view.gd")
const StrongholdFacilityStateScript = preload("res://domain/stronghold/stronghold_facility_state.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var registry := StrongholdDefinitionRegistryScript.new()
	var registry_errors: Array[String] = registry.configure()
	_expect(registry_errors.is_empty(), "Stronghold registry failed: %s" % registry_errors, failures)
	if not registry_errors.is_empty():
		return failures
	var definition = registry.starting_definition()
	var state = registry.create_initial_state()
	_expect(definition != null, "Starting stronghold definition is unavailable.", failures)
	_expect(state != null, "Starting stronghold state is unavailable.", failures)
	if definition == null or state == null:
		return failures
	_expect(definition.width == 7 and definition.height == 7, "Starting ruin is not 7 × 7.", failures)
	_expect(definition.layout_version == 3, "Starting ruin layout version is not 3.", failures)
	_expect(definition.primary_heart_coord == Vector2i(3, 3), "Heart is not at the true centre.", failures)
	_expect(state.facility_footprint(&"facility.fifth_god_heart") == Vector2i.ONE, "Heart is not 1 × 1.", failures)
	_expect(state.facility_origin(&"facility.stables") == Vector2i(2, 5), "Stables origin is not 2,5.", failures)
	_expect(state.facility_footprint(&"facility.stables") == Vector2i(2, 2), "Stables are not one 2 × 2 footprint.", failures)
	for coord: Vector2i in [Vector2i(2, 5), Vector2i(3, 5), Vector2i(2, 6), Vector2i(3, 6)]:
		_expect(state.canonical_coord(coord) == Vector2i(2, 5), "Stables coordinate %s did not resolve to the shared origin." % coord, failures)
	var construction := StrongholdConstructionServiceScript.new()
	var preview: OperationResult = construction.preview_build(definition, state, &"facility.reaver_warcamp", Vector2i(0, 0))
	_expect(preview.success, "Warcamp preview at 0,0 was rejected: %s" % preview.message, failures)
	var start_tick: int = 100
	var built: OperationResult = construction.construct_candidate(
		definition,
		state,
		&"facility.reaver_warcamp",
		Vector2i(0, 0),
		start_tick
	)
	_expect(built.success, "Warcamp construction failed: %s" % built.message, failures)
	if built.success:
		var instance_id: StringName = state.get_plot(Vector2i(0, 0)).facility_id
		var facility = state.get_facility(instance_id)
		var project = state.project_for_facility(instance_id)
		_expect(state.facility_footprint(instance_id) == Vector2i(2, 2), "Constructed Warcamp footprint is not 2 × 2.", failures)
		_expect(facility.condition == StrongholdFacilityStateScript.CONDITION_UNDER_CONSTRUCTION, "Warcamp did not enter construction state.", failures)
		_expect(project != null, "Warcamp construction project was not created.", failures)
		if project != null:
			construction.advance_candidate(definition, state, project.completion_tick)
		_expect(state.get_facility(instance_id).condition == StrongholdFacilityStateScript.CONDITION_OPERATIONAL, "Warcamp did not complete construction.", failures)
		var upgrade_started: OperationResult = construction.upgrade_candidate(
			definition,
			state,
			instance_id,
			start_tick + 5000
		)
		_expect(upgrade_started.success, "Warcamp upgrade failed to start.", failures)
		var upgrade_project = state.project_for_facility(instance_id)
		_expect(upgrade_project != null, "Warcamp upgrade project was not created.", failures)
		if upgrade_project != null:
			construction.advance_candidate(definition, state, upgrade_project.completion_tick)
		_expect(state.get_facility(instance_id).level == 2, "Warcamp level did not advance after the timed upgrade.", failures)
		_expect(construction.demolish_candidate(definition, state, instance_id).success, "Warcamp demolition failed.", failures)
		_expect(state.get_plot(Vector2i(0, 0)).current_state == &"available", "Demolished footprint did not return to Available.", failures)
	var view := StrongholdGridViewScript.new()
	view.configure(definition, state, {}, 0)
	view.select_plot(Vector2i(3, 6))
	_expect(view.selected_coord() == Vector2i(2, 5), "Grid selection did not select the whole Stables.", failures)
	view.free()
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
