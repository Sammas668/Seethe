class_name MovementPreviewQuery
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _sprint_handler: SprintMoveHandler


func _init() -> void:
	pass


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		sprint_handler: SprintMoveHandler
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_sprint_handler = sprint_handler


func execute(
		unit_id: StringName,
		destination: Vector2i,
		mode: StringName = &"normal"
) -> MovementPathResult:
	if _state_store == null or _map_definition == null:
		return MovementPathResult.failed("Movement preview is unavailable.")
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return MovementPathResult.failed("The selected unit does not exist.")
	var occupant: TacticalUnitState = _state_store.state.get_unit_at_tile(
		destination,
		unit_id
	)
	if occupant != null:
		return MovementPathResult.failed(
			"%s occupies that tile." % occupant.display_name
		)
	if mode == &"sprint":
		return _sprint_handler.preview(unit, destination)
	var navigation: TacticalNavigationSnapshot = TacticalNavigationSnapshot.new(
		_map_definition,
		_state_store.state,
		unit_id
	)
	return MovementRules.find_path(
		unit.grid_position,
		destination,
		navigation,
		unit.diagonal_steps_used
	)
