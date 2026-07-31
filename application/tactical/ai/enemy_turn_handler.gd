class_name EnemyTurnHandler
extends RefCounted

signal movement_committed(event: Dictionary)

const ENEMY_ACTION_PLANNER_SCRIPT: Script = preload(
	"res://application/tactical/ai/enemy_action_planner.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _attack_preview_query: RefCounted
var _attack_handler: RefCounted
var _detection_service: TacticalDetectionService
var _action_planner: RefCounted
var _body_action_handler: TacticalBodyActionHandler
var _reaction_service: TacticalReactionService
var _pending_reaction_context: Dictionary = {}
var _side_turn_participant_ids: Array[StringName] = []
var _side_turn_index: int = 0


func _init() -> void:
	pass


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal_value: RefCounted = null,
		attack_preview_query: RefCounted = null,
		attack_handler: RefCounted = null,
		detection_service: TacticalDetectionService = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal_value
	_attack_preview_query = attack_preview_query
	_attack_handler = attack_handler
	_detection_service = detection_service
	_action_planner = ENEMY_ACTION_PLANNER_SCRIPT.new() as RefCounted
	_action_planner.call(
		"configure",
		_state_store,
		_map_definition,
		_catalogue,
		_attack_preview_query
	)


func performance_snapshot() -> Dictionary:
	return (
		_action_planner.call("performance_snapshot")
		if (
			_action_planner != null
			and _action_planner.has_method("performance_snapshot")
		)
		else {}
	)


func configure_body_actions(handler: TacticalBodyActionHandler) -> void:
	_body_action_handler = handler


func configure_reactions(service: TacticalReactionService) -> void:
	_reaction_service = service


func has_pending_reaction() -> bool:
	return not _pending_reaction_context.is_empty()


func open_pending_reaction_decision() -> OperationResult:
	if _reaction_service == null or _pending_reaction_context.is_empty():
		return OperationResult.fail(&"reaction_decision_missing", "No player Reaction is pending.")
	var candidate: ReactionCandidate = _pending_reaction_context.get("candidate") as ReactionCandidate
	return _reaction_service.open_player_decision(candidate)


func resume_after_reaction() -> OperationResult:
	if _reaction_service == null or _pending_reaction_context.is_empty():
		return OperationResult.fail(&"reaction_resume_missing", "No interrupted enemy activation is waiting.")
	if _reaction_service.has_pending_decision():
		return OperationResult.fail(&"reaction_decision_unresolved", "Resolve the player Reaction decision first.")
	var context: Dictionary = _pending_reaction_context
	var unit: TacticalUnitState = _state_store.state.get_unit(StringName(context.get("unit_id", &"")))
	if unit == null:
		_clear_pending_reaction_context()
		return OperationResult.fail(&"reaction_mover_missing", "The interrupted enemy no longer exists.")
	if StringName(context.get("context_kind", &"movement")) == &"provoking_action":
		return _resume_provoking_action(context, unit)
	if not unit.can_take_actions():
		var stopped_result: OperationResult = _finish_activation(
			unit, true, "%s was stopped by a Reaction." % unit.display_name, true
		)
		_finish_pending_context(context)
		return stopped_result

	var remaining_path: Array[Vector2i] = []
	for tile_value: Variant in context.get("remaining_path", []):
		remaining_path.append(tile_value as Vector2i)
	if remaining_path.size() > 1:
		var continuation: OperationResult = _commit_enemy_path_with_reactions(
			unit,
			remaining_path,
			StringName(context.get("movement_action_id", &"")),
			context.get("post_move", {}) as Dictionary,
			bool(context.get("side_based", false))
		)
		if not continuation.success or continuation.code == &"reaction_pending":
			return continuation

	var result: OperationResult = _complete_post_move_context(
		unit,
		context.get("post_move", {}) as Dictionary,
		bool(context.get("side_based", false)),
		StringName(context.get("movement_action_id", &""))
	)
	if result.code == &"reaction_pending":
		return result
	_finish_pending_context(context)
	return result


func _resume_provoking_action(
		context: Dictionary,
		unit: TacticalUnitState
) -> OperationResult:
	if not unit.can_take_actions():
		var stopped: OperationResult = _finish_activation(
			unit,
			true,
			"%s was stopped before completing a provoking action." % unit.display_name,
			true
		)
		_finish_pending_context(context)
		return stopped
	var target: TacticalUnitState = _state_store.state.get_unit(
		StringName(context.get("target_id", &""))
	)
	var action_id := StringName(context.get("action_id", &""))
	if target == null or target.is_defeated():
		var no_target: OperationResult = _finish_activation(
			unit, false, "%s's provoking action lost its target." % unit.display_name
		)
		_finish_pending_context(context)
		return no_target
	var preview: Variant = _preview_attack(unit, target, action_id)
	if not _preview_succeeds(preview):
		var invalid: OperationResult = _finish_activation(
			unit, false, "%s's provoking action is no longer legal." % unit.display_name
		)
		_finish_pending_context(context)
		return invalid
	var attack_result: OperationResult = _execute_attack(preview)
	if not attack_result.success:
		_finish_pending_context(context)
		return attack_result
	var finished: OperationResult = _finish_activation(
		unit, true, "%s completed its provoking attack." % unit.display_name
	)
	_finish_pending_context(context)
	return finished


func _finish_pending_context(context: Dictionary) -> void:
	if _reaction_service != null:
		_reaction_service.clear_movement_suppression(
			StringName(context.get("movement_action_id", &""))
		)
	if bool(context.get("side_based", false)):
		_side_turn_index += 1
	_clear_pending_reaction_context()


func _clear_pending_reaction_context() -> void:
	_pending_reaction_context.clear()


func resolve_enemy_turn() -> OperationResult:
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(
			&"enemy_turn_state_missing",
			"The tactical state is unavailable."
		)
	if not _state_store.state.phase_state.is_enemy_turn():
		_side_turn_participant_ids.clear()
		_side_turn_index = 0
		return OperationResult.fail(
			&"enemy_turn_wrong_phase",
			"Enemy activations are available only during the Enemy Turn."
		)
	if has_pending_reaction():
		return OperationResult.new(
			true, &"reaction_pending", "A player Reaction decision is pending.",
			_pending_reaction_context, OperationResult.STATUS_COMMITTED
		)

	if _side_turn_participant_ids.is_empty():
		_side_turn_participant_ids = _stable_participant_ids()
		_side_turn_index = 0
		_record_activation_order(_side_turn_participant_ids)

	var summaries: Array[String] = []
	while _side_turn_index < _side_turn_participant_ids.size():
		var unit_id: StringName = _side_turn_participant_ids[_side_turn_index]
		var result: OperationResult = _execute_activation(unit_id)
		if result.code == &"reaction_pending":
			return result
		if not result.success:
			var recovered: OperationResult = _recover_activation_failure(unit_id, result)
			if not recovered.success:
				return recovered
			result = recovered
		if not result.message.is_empty():
			summaries.append(result.message)
		_side_turn_index += 1

	var participant_ids: Array[StringName] = _side_turn_participant_ids.duplicate()
	_side_turn_participant_ids.clear()
	_side_turn_index = 0
	var message: String = "Enemy Turn completed."
	if not summaries.is_empty():
		message = "Enemy Turn completed: %s" % "; ".join(PackedStringArray(summaries))
	return OperationResult.ok(participant_ids, message)


func resolve_initiative_activation(unit_id: StringName) -> OperationResult:
	if _state_store == null or _state_store.state == null:
		return OperationResult.fail(&"initiative_state_missing", "The tactical state is unavailable.")
	var phase: TacticalPhaseState = _state_store.state.phase_state
	if not phase.is_initiative_combat() or not phase.is_active_unit(unit_id):
		return OperationResult.fail(&"wrong_active_unit", "This is not the active initiative unit.")
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null or not unit.is_ai_controlled():
		return OperationResult.fail(&"initiative_ai_missing", "The active unit is not AI-controlled.")
	if unit.squad_id.is_empty() or not _state_store.state.is_squad_aware(unit.squad_id):
		return _finish_activation(
			unit,
			false,
			"%s belongs to an Unaware squad and passes." % unit.display_name
		)
	if not unit.can_take_actions():
		return _finish_activation(
			unit,
			false,
			"%s cannot act and passes." % unit.display_name,
			true
		)
	return _execute_standard_combat(unit, false)


func _stable_participant_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for unit: TacticalUnitState in _state_store.state.get_enemy_turn_units():
		result.append(unit.unit_id)
	result.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return str(a) < str(b)
	)
	return result


func _record_activation_order(participant_ids: Array[StringName]) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var labels: Array[String] = []
	for unit_id: StringName in participant_ids:
		var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
		labels.append(unit.display_name if unit != null else str(unit_id))
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"enemy_activation_order",
		phase.round_number,
		phase.current_phase,
		"Enemy activation order established.",
		{
			"category": &"events",
			"details": [
				"Stable order: %s" % " → ".join(PackedStringArray(labels)),
			],
		}
	)


func _execute_activation(unit_id: StringName) -> OperationResult:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(
			&"enemy_turn_unit_missing",
			"An enemy participant no longer exists."
		)
	if not unit.should_receive_enemy_turn():
		return OperationResult.fail(
			&"enemy_turn_unit_ineligible",
			"%s is not eligible for an Enemy Turn activation."
			% unit.display_name
		)

	if unit.is_defeated():
		return _execute_defeated_skip(unit)
	if unit.is_incapacitated():
		return _execute_incapacitated_skip(unit)
	if (
		not unit.squad_id.is_empty()
		and not _state_store.state.is_squad_aware(unit.squad_id)
	):
		return _execute_auto_pass(unit)
	if unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS:
		return _execute_auto_pass(unit)
	if unit.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_STANDARD:
		return _execute_standard_combat(unit)
	return OperationResult.fail(
		&"enemy_turn_behavior_unimplemented",
		"%s has an unsupported Enemy Turn behaviour." % unit.display_name
	)


func _execute_standard_combat(
		unit: TacticalUnitState,
		refresh_budget: bool = true
) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Standard Combat", refresh_budget)
	if not started.success:
		return started

	var rescue_result: OperationResult = _try_untie_adjacent_ally(unit)
	if rescue_result != null:
		if not rescue_result.success:
			return rescue_result
		return _finish_activation(unit, true, rescue_result.message)

	if _action_planner == null:
		return OperationResult.fail(
			&"enemy_action_planner_missing",
			"The enemy action planner is unavailable."
		)

	var perception_result: OperationResult = _refresh_squad_perception(unit)
	if not perception_result.success:
		return perception_result

	var plan: RefCounted = _action_planner.call("plan_activation", unit) as RefCounted
	if plan == null or not bool(plan.get("valid")):
		var reason: String = (
			str(plan.get("reason"))
			if plan != null
			else "%s could not construct an action plan." % unit.display_name
		)
		var reservation_result: OperationResult = _try_prepare_ai_reaction(unit)
		if reservation_result != null and reservation_result.success:
			return _finish_activation(unit, true, reservation_result.message)
		return _finish_activation(unit, false, reason + " The unit passes.")

	var plan_kind := StringName(plan.get("kind"))
	if plan_kind in [EnemyActionPlan.KIND_SEARCH, EnemyActionPlan.KIND_RETURN_TO_TASK]:
		return _execute_search_or_return_plan(unit, plan, plan_kind)

	var target_id: StringName = plan.get("target_id")
	var action_id: StringName = plan.get("action_id")
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	if target == null or target.is_defeated():
		var reservation_result: OperationResult = _try_prepare_ai_reaction(unit)
		if reservation_result != null and reservation_result.success:
			return _finish_activation(unit, true, reservation_result.message)
		return _finish_activation(
			unit,
			false,
			"%s found no active hostile target and passes." % unit.display_name
		)

	var acted: bool = false
	if bool(plan.get("move_required")):
		var destination: Vector2i = plan.get("move_destination")
		var post_move: Dictionary = {
			"kind": &"combat",
			"target_id": target_id,
			"action_id": action_id,
			"attack_after_move": bool(plan.get("attack_after_move")),
		}
		var movement_result: OperationResult = _commit_enemy_move(
			unit, destination, post_move, refresh_budget
		)
		if not movement_result.success or movement_result.code == &"reaction_pending":
			return movement_result
		acted = true

	if bool(plan.get("attack_after_move")):
		var attack_preview: Variant = _preview_attack(unit, target, action_id)
		if _preview_succeeds(attack_preview):
			var attack_result: OperationResult = _execute_attack_with_player_reaction(
				unit, attack_preview, refresh_budget
			)
			if not attack_result.success or attack_result.code == &"reaction_pending":
				return attack_result
			acted = true

	if not acted:
		var reservation_result: OperationResult = _try_prepare_ai_reaction(unit)
		if reservation_result != null and reservation_result.success:
			acted = true
			return _finish_activation(unit, true, reservation_result.message)
	return _finish_activation(
		unit,
		acted,
		(
			"%s completed its combat activation." % unit.display_name
			if acted
			else "%s has no legal actions and passes." % unit.display_name
		)
	)


func _try_prepare_ai_reaction(unit: TacticalUnitState) -> OperationResult:
	if _reaction_service == null or unit == null:
		return null
	var result: OperationResult = _reaction_service.prepare_best_ai_reservation(
		unit.unit_id
	)
	return result if result.success else null


func _try_untie_adjacent_ally(
		unit: TacticalUnitState
) -> OperationResult:
	if _body_action_handler == null or unit == null:
		return null
	for ally: TacticalUnitState in _state_store.state.get_units():
		if ally.team_id != unit.team_id or not ally.restrained:
			continue
		var body_item: TacticalItemInstanceState = _state_store.state.body_item_for_unit(
			ally.unit_id
		)
		if body_item == null:
			continue
		var reason: String = _body_action_handler.unavailable_reason(
			unit.unit_id, body_item.item_id, TacticalBodyActionHandler.ACTION_UNTIE
		)
		if reason.is_empty():
			return _body_action_handler.untie(unit.unit_id, body_item.item_id)
	return null


func _execute_search_or_return_plan(
		unit: TacticalUnitState,
		plan: RefCounted,
		plan_kind: StringName
) -> OperationResult:
	var acted: bool = false
	if bool(plan.get("move_required")):
		var destination: Vector2i = plan.get("move_destination")
		var post_move: Dictionary = {
			"kind": plan_kind,
			"attack_after_move": false,
		}
		var movement_result: OperationResult = _commit_enemy_move(
			unit, destination, post_move, true
		)
		if not movement_result.success or movement_result.code == &"reaction_pending":
			return movement_result
		acted = true

	var perception_result: OperationResult = _refresh_squad_perception(unit)
	if not perception_result.success:
		return perception_result

	if plan_kind == EnemyActionPlan.KIND_SEARCH:
		var reacquired: bool = _squad_has_revealed_hostile(unit.squad_id)
		var attack_after_search: bool = false
		if reacquired:
			attack_after_search = _attack_reacquired_target_if_ready(unit)
			acted = acted or attack_after_search
		return _finish_activation(
			unit,
			acted,
			(
				"%s reacquired a hostile while searching." % unit.display_name
				if reacquired
				else "%s searched the Last Seen Position." % unit.display_name
			)
		)

	return _finish_activation(
		unit,
		acted,
		"%s returned toward its prior guard task." % unit.display_name
	)


func _refresh_squad_perception(unit: TacticalUnitState) -> OperationResult:
	if _detection_service == null or unit == null or unit.squad_id.is_empty():
		return OperationResult.ok(false, "No squad perception refresh was required.")
	# Enemy planning may need the refreshed result immediately, but the already
	# committed movement/attack must never be reported as rejected. Queue through
	# the same post-commit authority and flush it synchronously for this AI step.
	_detection_service.request_current_perception_for_squad(unit.squad_id)
	return _detection_service.flush_requested_perception_refreshes()


func _squad_has_revealed_hostile(squad_id: StringName) -> bool:
	for player: TacticalUnitState in _state_store.state.get_player_units():
		if (
			not player.is_defeated()
			and player.is_revealed_to_squad(squad_id)
		):
			return true
	return false


func _attack_reacquired_target_if_ready(unit: TacticalUnitState) -> bool:
	var follow_up: RefCounted = _action_planner.call(
		"plan_activation",
		unit
	) as RefCounted
	if (
		follow_up == null
		or not bool(follow_up.get("valid"))
		or StringName(follow_up.get("kind")) != EnemyActionPlan.KIND_COMBAT
		or bool(follow_up.get("move_required"))
		or not bool(follow_up.get("attack_after_move"))
	):
		return false
	var target: TacticalUnitState = _state_store.state.get_unit(
		StringName(follow_up.get("target_id"))
	)
	if target == null or target.is_defeated():
		return false
	var attack_preview: Variant = _preview_attack(
		unit,
		target,
		StringName(follow_up.get("action_id"))
	)
	if not _preview_succeeds(attack_preview):
		return false
	var attack_result: OperationResult = _execute_attack(attack_preview)
	return attack_result.success


func _forget_last_seen(
		squad_id: StringName,
		unit_id: StringName
) -> OperationResult:
	var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
	if squad == null or unit_id.is_empty():
		return OperationResult.ok(false, "No Last Seen Position needed clearing.")
	var previous: Dictionary = squad.last_seen_positions_by_unit_id.duplicate(true)
	var changes := TacticalChangeSet.new(
		&"last_seen_position_searched",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_apply_forget_last_seen").bind(squad, unit_id),
		Callable(self, "_restore_last_seen").bind(squad, previous),
		"The searched Last Seen Position could not be cleared.",
		&"last_seen_clear_failed"
	)
	return _state_store.commit(changes, _map_definition)


func _apply_forget_last_seen(
		squad: TacticalSquadState,
		unit_id: StringName
) -> bool:
	squad.forget_last_seen(unit_id)
	return true


func _restore_last_seen(
		squad: TacticalSquadState,
		previous: Dictionary
) -> void:
	squad.last_seen_positions_by_unit_id = previous.duplicate(true)


func _preview_attack(
		unit: TacticalUnitState,
		target: TacticalUnitState,
		action_id: StringName
) -> Variant:
	if _attack_preview_query == null:
		return null
	return _attack_preview_query.call(
		"execute",
		unit.unit_id,
		target.unit_id,
		action_id,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)


func _preview_succeeds(preview: Variant) -> bool:
	return preview != null and bool(preview.get("success"))


func _execute_attack_with_player_reaction(
		unit: TacticalUnitState,
		preview: Variant,
		side_based: bool,
		movement_action_id: StringName = &""
) -> OperationResult:
	if (
		_reaction_service != null
		and preview != null
		and bool(preview.get("success"))
	):
		var candidate: ReactionCandidate = (
			_reaction_service.first_player_reaction_for_provoking_action(
				unit.unit_id,
				StringName(preview.get("action_id"))
			)
		)
		if candidate != null:
			_pending_reaction_context = {
				"context_kind": &"provoking_action",
				"candidate": candidate,
				"unit_id": unit.unit_id,
				"target_id": StringName(preview.get("target_id")),
				"action_id": StringName(preview.get("action_id")),
				"movement_action_id": movement_action_id,
				"side_based": side_based,
			}
			return OperationResult.new(
				true,
				&"reaction_pending",
				"The provoking action paused for a player Reaction decision.",
				_pending_reaction_context,
				OperationResult.STATUS_COMMITTED
			)
	return _execute_attack(preview)


func _execute_attack(preview: Variant) -> OperationResult:
	if _attack_handler == null:
		return OperationResult.fail(
			&"enemy_attack_handler_missing",
			"The enemy attack resolver is unavailable."
		)
	var value: Variant = _attack_handler.call("execute_preview", preview)
	var result: OperationResult = value as OperationResult
	return (
		result
		if result != null
		else OperationResult.fail(
			&"enemy_attack_result_missing",
			"The enemy attack resolver returned no result."
		)
	)


func _commit_enemy_move(
		unit: TacticalUnitState,
		destination: Vector2i,
		post_move: Dictionary = {},
		side_based: bool = false
) -> OperationResult:
	if _reaction_service != null:
		_reaction_service.cancel_reservation_for_voluntary_move(unit.unit_id)
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition, _state_store.state, unit.unit_id
	)
	var path: MovementPathResult = MovementRules.find_path(
		unit.grid_position, destination, navigation, unit.diagonal_steps_used
	)
	if not path.success:
		return OperationResult.fail(&"enemy_move_invalid", path.failure_reason)
	if path.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"enemy_move_capacity",
			"%s cannot afford its chosen route." % unit.display_name
		)
	var movement_action_id: StringName = (
		_reaction_service.begin_movement_action_id(unit.unit_id)
		if _reaction_service != null
		else &""
	)
	return _commit_enemy_path_with_reactions(
		unit, path.path, movement_action_id, post_move, side_based
	)


func _commit_enemy_path_with_reactions(
		unit: TacticalUnitState,
		planned_path: Array[Vector2i],
		movement_action_id: StringName,
		post_move: Dictionary,
		side_based: bool
) -> OperationResult:
	if planned_path.size() <= 1:
		return OperationResult.ok(planned_path, "No movement was required.")
	if _reaction_service != null:
		var pending: Dictionary = _reaction_service.first_player_reaction_for_path(
			unit.unit_id, planned_path, &"normal", movement_action_id
		)
		var candidate: ReactionCandidate = pending.get("candidate") as ReactionCandidate
		if candidate != null:
			var prefix_path: Array[Vector2i] = []
			for tile_value: Variant in pending.get("prefix_path", []):
				prefix_path.append(tile_value as Vector2i)
			var prefix_result: OperationResult = _commit_enemy_path(unit, prefix_path)
			if not prefix_result.success:
				return prefix_result
			var remaining_path: Array[Vector2i] = [prefix_path.back()]
			var resume_index: int = candidate.path_index
			if candidate.timing_kind == ReactionCandidate.TIMING_AFTER_ENTRY:
				resume_index += 1
			for index: int in range(resume_index, planned_path.size()):
				if remaining_path.back() != planned_path[index]:
					remaining_path.append(planned_path[index])
			_pending_reaction_context = {
				"candidate": candidate,
				"unit_id": unit.unit_id,
				"remaining_path": remaining_path,
				"movement_action_id": movement_action_id,
				"post_move": post_move.duplicate(true),
				"side_based": side_based,
			}
			return OperationResult.new(
				true, &"reaction_pending",
				"Enemy movement paused for a player Reaction decision.",
				prefix_result.data, OperationResult.STATUS_COMMITTED
			)
	return _commit_enemy_path(unit, planned_path)


func _commit_enemy_path(
		unit: TacticalUnitState,
		path_tiles: Array[Vector2i]
) -> OperationResult:
	if path_tiles.is_empty():
		return OperationResult.fail(&"enemy_move_path_empty", "The enemy route is empty.")
	var navigation := TacticalNavigationSnapshot.new(
		_map_definition, _state_store.state, unit.unit_id
	)
	var path: MovementPathResult = MovementRules.calculate_path_cost(
		path_tiles, navigation, unit.diagonal_steps_used
	)
	if not path.success:
		return OperationResult.fail(&"enemy_move_invalid", path.failure_reason)
	if path.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return OperationResult.fail(
			&"enemy_move_capacity",
			"%s cannot afford its chosen route." % unit.display_name
		)
	if path.path.size() <= 1:
		return OperationResult.ok(path, "Enemy movement paused before entering the next tile.")
	var origin: Vector2i = unit.grid_position
	var destination: Vector2i = path.path.back()
	var budget_snapshot: Dictionary = _budget_snapshot(unit)
	var dragged_body_cells_before: Dictionary = _state_store.state.dragged_body_cell_snapshot(unit.unit_id)
	var dragged_body_destination: Vector2i = path.path[path.path.size() - 2]
	var changes := TacticalChangeSet.new(&"enemy_unit_moved", _state_store.state.revision)
	changes.stage(
		Callable(self, "_set_unit_position").bind(
			unit.unit_id, destination, dragged_body_destination
		),
		Callable(self, "_restore_unit_position").bind(
			unit.unit_id, origin, dragged_body_cells_before
		),
		"The enemy destination became invalid.",
		&"enemy_move_destination_failed"
	)
	changes.stage(
		Callable(self, "_spend_move_budget").bind(
			unit, path.cost_feet, path.diagonal_steps
		),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"The enemy movement cost could not be paid.",
		&"enemy_move_cost_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	movement_committed.emit({
		"unit_id": unit.unit_id,
		"path": path.path.duplicate(),
		"dragged_body_cells_before": dragged_body_cells_before.duplicate(true),
	})
	_record_movement_event(unit, origin, destination, path, budget_snapshot)
	return OperationResult.ok(path, "%s moved %d ft." % [unit.display_name, path.cost_feet])


func _complete_post_move_context(
		unit: TacticalUnitState,
		post_move: Dictionary,
		side_based: bool = false,
		movement_action_id: StringName = &""
) -> OperationResult:
	var kind: StringName = StringName(post_move.get("kind", &"combat"))
	if kind in [EnemyActionPlan.KIND_SEARCH, EnemyActionPlan.KIND_RETURN_TO_TASK]:
		var perception_result: OperationResult = _refresh_squad_perception(unit)
		if not perception_result.success:
			return perception_result
		return _finish_activation(
			unit, true,
			"%s completed its search movement." % unit.display_name
		)
	var acted: bool = true
	if bool(post_move.get("attack_after_move", false)):
		var target: TacticalUnitState = _state_store.state.get_unit(
			StringName(post_move.get("target_id", &""))
		)
		if target != null and not target.is_defeated():
			var preview: Variant = _preview_attack(
				unit, target, StringName(post_move.get("action_id", &""))
			)
			if _preview_succeeds(preview):
				var attack_result: OperationResult = _execute_attack_with_player_reaction(
					unit, preview, side_based, movement_action_id
				)
				if not attack_result.success or attack_result.code == &"reaction_pending":
					return attack_result
	return _finish_activation(
		unit, acted, "%s completed its combat activation." % unit.display_name
	)


func _begin_activation(
		unit: TacticalUnitState,
		behavior_label: String,
		refresh_budget: bool = true
) -> OperationResult:
	if not refresh_budget:
		unit.reactivate_without_refresh()
		_record_turn_started(unit, behavior_label)
		return OperationResult.ok(unit.unit_id, "%s began its activation." % unit.display_name)
	var budget_snapshot: Dictionary = _budget_snapshot(unit)
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"enemy_unit_started",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "_refresh_activation").bind(unit),
		Callable(self, "_restore_budget").bind(unit, budget_snapshot),
		"%s could not begin its Enemy Turn activation." % unit.display_name,
		&"enemy_activation_start_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_turn_started(unit, behavior_label)
	return OperationResult.ok(unit.unit_id, "%s began its activation." % unit.display_name)


func _recover_activation_failure(
		unit_id: StringName,
		failure: OperationResult
) -> OperationResult:
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return failure

	_record_ai_failure(unit, failure)
	var summary: String = (
		"%s encountered an AI execution error and safely ends its activation: %s"
		% [unit.display_name, failure.message]
	)
	var finalized: OperationResult = _finish_activation(unit, false, summary)
	if finalized.success:
		return OperationResult.ok(unit.unit_id, summary)
	return OperationResult.fail(
		&"enemy_activation_recovery_failed",
		"%s The activation also could not be finalized: %s"
		% [failure.message, finalized.message]
	)


func _execute_auto_pass(unit: TacticalUnitState) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Automatic Pass")
	if not started.success:
		return started
	return _finish_activation(
		unit,
		false,
		"%s has no legal actions and passes." % unit.display_name
	)


func _execute_incapacitated_skip(unit: TacticalUnitState) -> OperationResult:
	return _finish_activation(
		unit,
		false,
		"%s is incapacitated and skips its activation." % unit.display_name,
		true
	)


func _execute_defeated_skip(unit: TacticalUnitState) -> OperationResult:
	var started: OperationResult = _begin_activation(unit, "Defeated — Skip")
	if not started.success:
		return started
	return _finish_activation(
		unit,
		false,
		"%s is Defeated and skips its activation." % unit.display_name,
		true
	)


func _finish_activation(
		unit: TacticalUnitState,
		acted: bool,
		summary: String,
		defeated_skip: bool = false
) -> OperationResult:
	if not unit.action_budget.ended_activation:
		var ended_before: bool = unit.action_budget.ended_activation
		var changes: TacticalChangeSet = TacticalChangeSet.new(
			&"enemy_unit_ended",
			_state_store.state.revision
		)
		changes.stage(
			Callable(self, "_set_activation_ended").bind(unit, true),
			Callable(self, "_set_activation_ended_rollback").bind(
				unit,
				ended_before
			),
			"%s could not end its activation." % unit.display_name,
			&"enemy_activation_end_failed"
		)
		var committed: OperationResult = _state_store.commit(
			changes,
			_map_definition
		)
		if not committed.success:
			return committed

	_record_turn_finished(unit, acted, summary, defeated_skip)
	return OperationResult.ok(unit.unit_id, summary)


func _refresh_activation(unit: TacticalUnitState) -> bool:
	unit.refresh_for_new_round()
	return true


func _set_activation_ended(
		unit: TacticalUnitState,
		ended: bool
) -> bool:
	if ended:
		unit.mark_activation_ended()
	else:
		unit.action_budget.ended_activation = false
	return true


func _set_activation_ended_rollback(
		unit: TacticalUnitState,
		ended: bool
) -> void:
	unit.action_budget.ended_activation = ended


func _set_unit_position(
		unit_id: StringName,
		destination: Vector2i,
		dragged_body_destination: Vector2i
) -> bool:
	var moved: bool = _state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)
	if moved and dragged_body_destination.x >= 0:
		_state_store.state.move_dragged_bodies_to_cell(
			unit_id,
			dragged_body_destination
		)
	return moved


func _restore_unit_position(
		unit_id: StringName,
		destination: Vector2i,
		dragged_body_cells_before: Dictionary
) -> void:
	_state_store.state.set_unit_position(
		unit_id,
		destination,
		_map_definition,
		false
	)
	_state_store.state.restore_dragged_body_cells(
		dragged_body_cells_before
	)


func _spend_move_budget(
		unit: TacticalUnitState,
		cost_feet: int,
		diagonal_steps: int
) -> bool:
	if cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		return false
	unit.action_budget.spend_normal_capacity(cost_feet)
	unit.diagonal_steps_used += diagonal_steps
	return true


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
		"diagonal": unit.diagonal_steps_used,
	}


func _restore_budget(
		unit: TacticalUnitState,
		snapshot: Dictionary
) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
	unit.action_budget.ordinary_attack_available = bool(
		snapshot["ordinary_attack"]
	)
	unit.action_budget.ended_activation = bool(snapshot["ended"])
	unit.diagonal_steps_used = int(snapshot["diagonal"])


func _record_turn_started(
		unit: TacticalUnitState,
		behavior_label: String
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"unit_turn_started",
		phase.round_number,
		phase.current_phase,
		"%s begins its Enemy Turn activation." % unit.display_name,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": [
				"Team: Enemy",
				"Controller: AI",
				"Turn behaviour: %s" % behavior_label,
			],
		}
	)


func _record_turn_finished(
		unit: TacticalUnitState,
		acted: bool,
		summary: String,
		defeated_skip: bool
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	var event_type: StringName = &"unit_turn_ended" if acted else &"unit_passed"
	var details: Array[String] = [
		"Remaining capacity: %d ft"
		% unit.action_budget.remaining_turn_capacity_feet,
		"Normal attack: %s"
		% (
			"Ready"
			if unit.action_budget.ordinary_attack_available
			else "Spent"
		),
	]
	if defeated_skip:
		details.append("Combat state: Defeated")
	elif not acted:
		details.append("No movement or attack was taken.")
	_event_journal.call(
		"record_event",
		event_type,
		phase.round_number,
		phase.current_phase,
		summary,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": details,
		}
	)


func _record_ai_failure(
		unit: TacticalUnitState,
		failure: OperationResult
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"enemy_ai_failure",
		phase.round_number,
		phase.current_phase,
		"%s encountered an AI execution error and will pass." % unit.display_name,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": [
				"Failure code: %s" % str(failure.code),
				failure.message,
				"The Enemy Turn will continue with the next participant.",
			],
		}
	)


func _record_movement_event(
		unit: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i,
		path: MovementPathResult,
		budget_snapshot: Dictionary
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"movement",
		phase.round_number,
		phase.current_phase,
		"%s moved %d ft." % [unit.display_name, path.cost_feet],
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.move",
			"details": [
				"From: (%d, %d)" % [origin.x, origin.y],
				"To: (%d, %d)" % [destination.x, destination.y],
				"Distance: %d ft" % path.cost_feet,
				"Capacity: %d → %d ft" % [
					int(budget_snapshot.get("remaining", 0)),
					unit.action_budget.remaining_turn_capacity_feet,
				],
			],
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": int(budget_snapshot.get("remaining", 0)),
					"after": unit.action_budget.remaining_turn_capacity_feet,
				},
			],
		}
	)
