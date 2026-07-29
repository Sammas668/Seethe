class_name RuntimeSpawnHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _deployment_service: TacticalCharacterDeploymentService


func _init(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		deployment_service: TacticalCharacterDeploymentService
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_deployment_service = deployment_service


func spawn_character(
		character: PersistentCharacterState,
		grid_position: Vector2i,
		active_modifier_ids: Array[StringName] = [],
		item_states: Array[CampaignItemState] = []
) -> OperationResult:
	if _state_store == null or _deployment_service == null:
		return OperationResult.fail(
			&"runtime_spawn_unavailable",
			"Runtime spawning is not configured."
		)
	var prepared: OperationResult = _deployment_service.prepare_deployment(
		_state_store.state,
		character,
		grid_position,
		_map_definition,
		active_modifier_ids,
		item_states
	)
	if not prepared.success:
		return prepared
	var plan: TacticalCharacterDeploymentPlan = (
		prepared.data as TacticalCharacterDeploymentPlan
	)
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"runtime_spawn",
		plan.expected_state_revision
	)
	changes.stage(
		Callable(self, "_add_unit").bind(plan.unit),
		Callable(self, "_remove_unit").bind(plan.unit.unit_id),
		"Runtime unit could not be added.",
		&"runtime_spawn_unit_failed"
	)
	for item: TacticalItemInstanceState in plan.items:
		changes.stage(
			Callable(self, "_add_item").bind(item),
			Callable(self, "_remove_item").bind(item.item_id),
			"Runtime item %s could not be added." % item.item_id,
			&"runtime_spawn_item_failed"
		)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	return OperationResult.ok(plan.unit, "Character spawned through tactical commit.")


func _add_unit(unit: TacticalUnitState) -> bool:
	return _state_store.state.add_unit(unit, _map_definition, false)


func _remove_unit(unit_id: StringName) -> void:
	_state_store.state.remove_unit(unit_id, false)


func _add_item(item: TacticalItemInstanceState) -> bool:
	return _state_store.state.add_item(item, _map_definition, false)


func _remove_item(item_id: StringName) -> void:
	_state_store.state.remove_item(item_id, false)
