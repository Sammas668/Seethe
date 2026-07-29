class_name TacticalScreenFacade
extends RefCounted

const MOVEMENT_PREVIEW_QUERY_SCRIPT: Script = preload(
	"res://application/tactical/queries/movement_preview_query.gd"
)
const ACTION_AVAILABILITY_QUERY_SCRIPT: Script = preload(
	"res://application/tactical/queries/action_availability_query.gd"
)
const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)

signal state_changed(reason: StringName)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _movement_handler: TacticalCommandHandler
var _spend_action_handler: SpendActionHandler
var _sprint_handler: SprintMoveHandler
var _end_phase_handler: EndPhaseHandler
var _inventory_handler: TacticalInventoryTransferHandler
var _movement_query
var _action_query
var _player_unit_order: Array[StringName] = []
var _modifier_toggle: Callable
var _attack_preview_query: RefCounted
var _attack_handler: RefCounted
var _combat_dice_roller: RefCounted
var _enemy_turn_handler: RefCounted


func _init() -> void:
	pass


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal: RefCounted,
		movement_handler: TacticalCommandHandler,
		spend_action_handler: SpendActionHandler,
		sprint_handler: SprintMoveHandler,
		end_phase_handler: EndPhaseHandler,
		inventory_handler: TacticalInventoryTransferHandler,
		unit_order: Array[StringName],
		modifier_toggle: Callable,
		attack_preview_query: RefCounted = null,
		attack_handler: RefCounted = null,
		combat_dice_roller: RefCounted = null,
		enemy_turn_handler: RefCounted = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal
	_movement_handler = movement_handler
	_spend_action_handler = spend_action_handler
	_sprint_handler = sprint_handler
	_end_phase_handler = end_phase_handler
	_inventory_handler = inventory_handler
	_player_unit_order = unit_order.duplicate()
	_modifier_toggle = modifier_toggle
	_attack_preview_query = attack_preview_query
	_attack_handler = attack_handler
	_combat_dice_roller = combat_dice_roller
	_enemy_turn_handler = enemy_turn_handler
	_movement_query = MOVEMENT_PREVIEW_QUERY_SCRIPT.new()
	_movement_query.configure(
		_state_store,
		_map_definition,
		_sprint_handler
	)
	_action_query = ACTION_AVAILABILITY_QUERY_SCRIPT.new()
	_action_query.configure(_state_store, _catalogue)
	_state_store.state_changed.connect(_on_state_changed)


func _on_state_changed(reason: StringName) -> void:
	state_changed.emit(reason)


func state() -> TacticalState:
	return _state_store.state


func map_definition() -> TacticalMapDefinition:
	return _map_definition


func player_unit_order() -> Array[StringName]:
	return _player_unit_order.duplicate()


func event_journal() -> RefCounted:
	return _event_journal


func preview_movement(
		unit_id: StringName,
		destination: Vector2i,
		mode: StringName = &"normal"
) -> MovementPathResult:
	return _movement_query.execute(unit_id, destination, mode)


func execute_movement(
		unit_id: StringName,
		destination: Vector2i,
		mode: StringName = &"normal"
) -> OperationResult:
	if mode == &"sprint":
		return _sprint_handler.execute(SprintMoveCommand.new(unit_id, destination))
	return _movement_handler.execute_move(MoveCommand.new(unit_id, destination))


func reactivate_unit(unit_id: StringName) -> OperationResult:
	return _movement_handler.reactivate_unit(unit_id)


func end_unit(unit_id: StringName) -> OperationResult:
	return _movement_handler.mark_unit_ended(unit_id)


func spend_action(
		unit_id: StringName,
		action_name: String,
		action_id: StringName
) -> OperationResult:
	var cost: ActionCost = _action_query.cost_for_action(action_id)
	if cost == null:
		return OperationResult.fail(
			&"action_cost_missing",
			"The action has no authored cost."
		)
	return _spend_action_handler.execute(
		SpendActionCommand.new(unit_id, action_name, cost)
	)


func action_unavailable_reason(
		unit_id: StringName,
		action_id: StringName
) -> String:
	return _action_query.unavailable_reason(unit_id, action_id)


func half_action_cost_feet(unit_id: StringName) -> int:
	return _action_query.half_action_cost_feet(unit_id)


func begin_world_phase() -> OperationResult:
	return _end_phase_handler.begin_world_phase(EndPhaseCommand.new())


func complete_world_phase() -> OperationResult:
	return _end_phase_handler.complete_world_phase()


func resolve_enemy_turn() -> OperationResult:
	if _enemy_turn_handler == null:
		return OperationResult.fail(
			&"enemy_turn_handler_missing",
			"The Enemy Turn handler is unavailable."
		)
	var value: Variant = _enemy_turn_handler.call("resolve_enemy_turn")
	var result: OperationResult = value as OperationResult
	return (
		result
		if result != null
		else OperationResult.fail(
			&"enemy_turn_result_missing",
			"The Enemy Turn handler returned no result."
		)
	)


func set_character_modifier_active(
		unit_id: StringName,
		modifier_id: StringName,
		active: bool
) -> bool:
	if not _modifier_toggle.is_valid():
		return false
	return bool(_modifier_toggle.call(unit_id, modifier_id, active))


func action_definition(action_id: StringName) -> ActionDefinition:
	return _catalogue.action_definition(action_id) if _catalogue != null else null


func attack_definition(action_id: StringName) -> AttackDefinition:
	return _catalogue.attack_definition(action_id) if _catalogue != null else null


func defence_profile(profile_id: StringName) -> DefenceProfile:
	return _catalogue.defence_profile(profile_id) if _catalogue != null else null


func has_character_modifier(modifier_id: StringName) -> bool:
	return (
		_catalogue != null
		and _catalogue.character_modifier(modifier_id) != null
	)


func granted_action_ids_for_unit(unit_id: StringName) -> Array[StringName]:
	return state().granted_action_ids_for_unit(unit_id)


func preview_inventory_transfer(
		command: TacticalInventoryTransferCommand
) -> TacticalInventoryTransferPreview:
	return _inventory_handler.preview(command)


func execute_inventory_transfer_plan(
		plan: TacticalInventoryTransferPlan,
		preview: TacticalInventoryTransferPreview
) -> OperationResult:
	return _inventory_handler.execute_plan(plan, preview)


func resolve_inventory_source_item(
		command: TacticalInventoryTransferCommand
) -> TacticalItemInstanceState:
	return _inventory_handler.resolve_source_item(command)


func first_fit_for_item(
		unit_id: StringName,
		item: TacticalItemInstanceState,
		target_kind: StringName
) -> int:
	return _inventory_handler.first_fit_for_item(unit_id, item, target_kind)

func are_units_hostile(
	attacker_id: StringName,
	target_id: StringName
) -> bool:
	var attacker: TacticalUnitState = state().get_unit(attacker_id)
	var target: TacticalUnitState = state().get_unit(target_id)
	if attacker == null or target == null:
		return false
	return TEAM_RELATIONS_SCRIPT.are_hostile(
		attacker.team_id,
		target.team_id
	)


func is_stage_4_attack(action_id: StringName) -> bool:
	if _attack_preview_query == null:
		return false
	return bool(_attack_preview_query.call("is_supported_action", action_id))


func preview_attack(
		attacker_id: StringName,
		target_id: StringName,
		action_id: StringName,
		power_attack_value: int = 0,
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL
):
	if _attack_preview_query == null:
		return null
	return _attack_preview_query.call(
		"execute",
		attacker_id,
		target_id,
		action_id,
		power_attack_value,
		damage_channel
	)


func legal_attack_target_ids(
		attacker_id: StringName,
		action_id: StringName,
		power_attack_value: int = 0,
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL
) -> Array[StringName]:
	var result: Array[StringName] = []
	if _attack_preview_query == null:
		return result
	var value: Variant = _attack_preview_query.call(
		"legal_target_ids",
		attacker_id,
		action_id,
		power_attack_value,
		damage_channel
	)
	if value is Array:
		for target_id: Variant in value:
			result.append(StringName(target_id))
	return result


func execute_attack_preview(preview) -> OperationResult:
	if _attack_handler == null:
		return OperationResult.fail(
			&"attack_handler_missing",
			"The attack handler is unavailable."
		)
	var value: Variant = _attack_handler.call("execute_preview", preview)
	var result: OperationResult = value as OperationResult
	return (
		result
		if result != null
		else OperationResult.fail(
			&"attack_result_missing",
			"The attack handler returned no result."
		)
	)


func set_combat_seed_for_tests(seed_value: int) -> void:
	if _combat_dice_roller != null:
		_combat_dice_roller.call("set_seed", seed_value)


func set_combat_scripted_rolls_for_tests(results: Array[int]) -> void:
	if _combat_dice_roller != null:
		_combat_dice_roller.call("set_scripted_results", results)

