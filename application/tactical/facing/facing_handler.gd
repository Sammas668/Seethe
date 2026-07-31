class_name FacingHandler
extends RefCounted

const FACE_DIRECTION_COST_FEET: int = 5

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _detection_service: TacticalDetectionService


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal_value: RefCounted,
		detection_service: TacticalDetectionService
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal_value
	_detection_service = detection_service


func unavailable_reason(unit_id: StringName, target_tile: Vector2i) -> String:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return "The selected unit does not exist."
	if not unit.is_player_controlled():
		return "Only player-controlled units can be manually oriented."
	if not _state_store.state.can_player_unit_act(unit_id):
		return "This unit is not currently active."
	if _map_definition == null or not _map_definition.is_inside(target_tile):
		return "Choose a tile inside the tactical map."
	if target_tile == unit.grid_position:
		return "Choose a different tile to set a facing direction."
	var new_facing: Vector2i = preview_direction(unit_id, target_tile)
	if new_facing == unit.facing_direction:
		return "This unit is already facing that direction."
	if unit.action_budget.remaining_turn_capacity_feet < FACE_DIRECTION_COST_FEET:
		return "Face Direction costs %d ft of turn capacity." % FACE_DIRECTION_COST_FEET
	return ""


func preview_direction(unit_id: StringName, target_tile: Vector2i) -> Vector2i:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null or target_tile == unit.grid_position:
		return Vector2i.ZERO
	return TacticalPerceptionRules.normalized_facing(
		target_tile - unit.grid_position
	)


func execute(unit_id: StringName, target_tile: Vector2i) -> OperationResult:
	var reason: String = unavailable_reason(unit_id, target_tile)
	if not reason.is_empty():
		return OperationResult.fail(&"face_direction_unavailable", reason)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	var new_facing: Vector2i = preview_direction(unit_id, target_tile)
	var facing_before: Vector2i = unit.facing_direction
	var remaining_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var changes := TacticalChangeSet.new(
		&"unit_faced_direction",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_facing").bind(unit, new_facing),
		Callable(self, "_restore_facing").bind(
			unit,
			facing_before,
			remaining_before,
			spent_before
		),
		"The facing change could not be committed.",
		&"face_direction_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed

	_record_event(
		unit,
		facing_before,
		new_facing,
		remaining_before
	)
	if _detection_service != null and not unit.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(unit.squad_id)
	return OperationResult.committed(
		new_facing,
		"%s faced %s for %d ft."
		% [unit.display_name, _direction_label(new_facing), FACE_DIRECTION_COST_FEET],
		_state_store.state.revision
	)


func _apply_facing(unit: TacticalUnitState, direction: Vector2i) -> bool:
	unit.set_facing(direction)
	unit.action_budget.spend_normal_capacity(FACE_DIRECTION_COST_FEET)
	return unit.facing_direction == direction


func _restore_facing(
		unit: TacticalUnitState,
		facing_before: Vector2i,
		remaining_before: int,
		spent_before: int
) -> void:
	unit.facing_direction = facing_before
	unit.action_budget.remaining_turn_capacity_feet = remaining_before
	unit.action_budget.normal_capacity_spent_feet = spent_before


func _record_event(
		unit: TacticalUnitState,
		facing_before: Vector2i,
		facing_after: Vector2i,
		capacity_before: int
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"facing_changed",
		phase.round_number,
		phase.current_phase,
		"%s faced %s." % [unit.display_name, _direction_label(facing_after)],
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.face_direction",
			"details": [
				"Facing: %s → %s"
				% [_direction_label(facing_before), _direction_label(facing_after)],
				"Cost: %d ft" % FACE_DIRECTION_COST_FEET,
				"Capacity: %d → %d ft"
				% [capacity_before, unit.action_budget.remaining_turn_capacity_feet],
				"Passive Perception uses the new focused cone without rerolling stationary hidden units.",
			],
		}
	)


func _direction_label(direction: Vector2i) -> String:
	var facing: Vector2i = TacticalPerceptionRules.normalized_facing(direction)
	if facing == Vector2i(0, -1):
		return "north"
	if facing == Vector2i(1, -1):
		return "north-east"
	if facing == Vector2i(1, 0):
		return "east"
	if facing == Vector2i(1, 1):
		return "south-east"
	if facing == Vector2i(0, 1):
		return "south"
	if facing == Vector2i(-1, 1):
		return "south-west"
	if facing == Vector2i(-1, 0):
		return "west"
	if facing == Vector2i(-1, -1):
		return "north-west"
	return "forward"
