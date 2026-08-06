class_name TacticalReactionService
extends RefCounted

signal reaction_decision_requested(request: ReactionDecisionRequest)
signal reaction_decision_cleared(request_id: StringName)

const HALF_ACTION_COST_SCRIPT: Script = preload(
	"res://domain/tactical/action_cost.gd"
)
const MELEE_REACH_RULES_SCRIPT: Script = preload(
	"res://domain/tactical/combat/tactical_melee_reach_rules.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _attack_preview_query: RefCounted
var _attack_handler: RefCounted
var _visibility_service: RefCounted

var _request_sequence: int = 0
var _movement_sequence: int = 0
var _action_sequence: int = 0
var _reaction_index_revision: int = -1
var _threat_source_ids_by_tile: Dictionary = {}
var _reserved_source_ids_by_tile: Dictionary = {}
var _performance: Dictionary = {
	"reaction_windows_opened": 0,
	"reaction_candidates_examined": 0,
	"valid_reactions_resolved": 0,
	"player_reaction_prompts_opened": 0,
	"player_reactions_used": 0,
	"player_reactions_declined_or_held": 0,
	"stale_reaction_decisions_rejected": 0,
	"reaction_preview_queries": 0,
	"threat_cache_rebuilds": 0,
	"overwatch_area_intersections": 0,
	"brace_area_intersections": 0,
	"reaction_chains_suppressed": 0,
}


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal: RefCounted,
		attack_preview_query: RefCounted,
		attack_handler: RefCounted,
		visibility_service: RefCounted
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal
	_attack_preview_query = attack_preview_query
	_attack_handler = attack_handler
	_visibility_service = visibility_service
	_invalidate_reaction_indexes()


func performance_snapshot() -> Dictionary:
	return _performance.duplicate(true)


func pending_decision() -> ReactionDecisionRequest:
	var pending: PendingMovementReactionState = _pending_state()
	if pending == null or not pending.has_unresolved_decision():
		return null
	return pending.request


func has_pending_decision() -> bool:
	return pending_decision() != null


func begin_movement_action_id(mover_id: StringName) -> StringName:
	_movement_sequence += 1
	var revision: int = (
		_state_store.state.revision
		if _state_store != null and _state_store.state != null
		else 0
	)
	return StringName(
		"movement.%s.r%d.%d" % [mover_id, revision, _movement_sequence]
	)


func clear_movement_suppression(movement_action_id: StringName) -> void:
	# Suppression belongs to PendingMovementReactionState and disappears when the
	# authoritative interrupted movement is cleared. Retained as a compatibility
	# entry point for older callers.
	if movement_action_id.is_empty():
		return


func preview_path_reactions(
		unit_id: StringName,
		path_result: MovementPathResult,
		movement_kind: StringName = &"normal"
) -> MovementReactionPreview:
	_performance["reaction_preview_queries"] = int(
		_performance["reaction_preview_queries"]
	) + 1
	var result := MovementReactionPreview.new()
	result.unit_id = unit_id
	result.query_count = 1
	if (
		_state_store == null
		or path_result == null
		or not path_result.success
		or path_result.path.size() <= 1
	):
		return result
	var mover: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if mover == null:
		return result
	var movement_action_id := StringName("preview.%s" % unit_id)
	for path_index: int in range(1, path_result.path.size()):
		var origin: Vector2i = path_result.path[path_index - 1]
		var destination: Vector2i = path_result.path[path_index]
		var candidates: Array[ReactionCandidate] = _candidates_for_step(
			mover,
			origin,
			destination,
			path_index,
			movement_kind,
			movement_action_id,
			true
		)
		if candidates.is_empty():
			continue
		var tile: Vector2i = (
			origin
			if candidates[0].timing_kind == ReactionCandidate.TIMING_BEFORE_ENTRY
			else destination
		)
		var tile_preview: MovementReactionTilePreview = result.preview_for_tile(tile)
		if tile_preview == null:
			tile_preview = MovementReactionTilePreview.new()
			tile_preview.tile = tile
			tile_preview.path_index = path_index
			result.tile_previews.append(tile_preview)
		for candidate: ReactionCandidate in candidates:
			result.candidate_summaries.append(_candidate_summary(candidate))
			if not tile_preview.source_unit_ids.has(candidate.source_unit_id):
				tile_preview.source_unit_ids.append(candidate.source_unit_id)
			tile_preview.reaction_count = tile_preview.source_unit_ids.size()
			if (
				tile_preview.reaction_kind.is_empty()
				or candidate.predicted_hit_chance > tile_preview.hit_chance_percent
			):
				tile_preview.reaction_kind = candidate.reaction_kind
				tile_preview.hit_chance_percent = candidate.predicted_hit_chance
	return result


func reaction_unavailable_reason(
		unit_id: StringName,
		reaction_kind: StringName
) -> String:
	if _state_store == null:
		return "Reaction services are unavailable."
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return "The selected unit does not exist."
	if not _state_store.state.can_unit_act(unit_id):
		return "This unit is not active in the current turn mode."
	if not unit.can_take_actions() or unit.is_disabled():
		return "This unit cannot prepare a Reaction."
	if unit.action_budget.reaction_state != ReactionResourceState.AVAILABLE:
		return "The unit's Reaction is not available."
	var cost_reason: String = ActionEconomyRules.unavailable_reason(
		unit,
		ActionCost.half_action()
	)
	if not cost_reason.is_empty():
		return cost_reason
	match reaction_kind:
		ReactionReservationState.KIND_OVERWATCH:
			if _ranged_attack_action_id(unit).is_empty():
				return "Equip a supported ranged weapon before preparing Overwatch."
		ReactionReservationState.KIND_BRACE:
			if _brace_attack_action_id(unit).is_empty():
				return "Equip a spear or another Brace-capable melee weapon."
		_:
			return "That Reaction reservation is not implemented."
	return ""


func prepare_overwatch(
		unit_id: StringName,
		direction: Vector2i
) -> OperationResult:
	return _prepare_reservation(
		unit_id,
		ReactionReservationState.KIND_OVERWATCH,
		direction
	)


func prepare_brace(
		unit_id: StringName,
		direction: Vector2i
) -> OperationResult:
	return _prepare_reservation(
		unit_id,
		ReactionReservationState.KIND_BRACE,
		direction
	)


func prepare_best_ai_reservation(unit_id: StringName) -> OperationResult:
	if _state_store == null:
		return OperationResult.fail(
			&"reaction_service_missing",
			"Reaction services are unavailable."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null or not unit.is_ai_controlled():
		return OperationResult.fail(
			&"ai_reaction_unit_invalid",
			"Only an AI-controlled unit may use the AI reservation policy."
		)
	var target: TacticalUnitState = _nearest_perceived_hostile(unit)
	if target == null:
		return OperationResult.fail(
			&"ai_reaction_target_missing",
			"No perceived hostile is available for a Reaction reservation."
		)
	var direction: Vector2i = TacticalPerceptionRules.normalized_facing(
		target.grid_position - unit.grid_position
	)
	if direction == Vector2i.ZERO:
		return OperationResult.fail(
			&"ai_reaction_direction_invalid",
			"The AI could not determine a Reaction direction."
		)
	if not _ranged_attack_action_id(unit).is_empty():
		return _prepare_reservation(
			unit_id,
			ReactionReservationState.KIND_OVERWATCH,
			direction
		)
	if not _brace_attack_action_id(unit).is_empty():
		return _prepare_reservation(
			unit_id,
			ReactionReservationState.KIND_BRACE,
			direction
		)
	return OperationResult.fail(
		&"ai_reaction_option_missing",
		"This AI unit has no supported Overwatch or Brace option."
	)


func preview_reservation_tiles(
		unit_id: StringName,
		reaction_kind: StringName,
		direction_value: Vector2i
) -> Array[Vector2i]:
	if _state_store == null:
		return []
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return []
	var direction: Vector2i = TacticalPerceptionRules.normalized_facing(direction_value)
	if direction == Vector2i.ZERO:
		return []
	var action_id: StringName = (
		_ranged_attack_action_id(unit)
		if reaction_kind == ReactionReservationState.KIND_OVERWATCH
		else _brace_attack_action_id(unit)
	)
	return _reservation_tiles(unit, reaction_kind, direction, action_id)


func cancel_reservation_for_voluntary_move(unit_id: StringName) -> OperationResult:
	if _state_store == null:
		return OperationResult.fail(
			&"reaction_service_missing",
			"Reaction services are unavailable."
		)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
	if unit.action_budget.reaction_state != ReactionResourceState.RESERVED:
		return OperationResult.no_change(
			unit_id,
			"No prepared Reaction reservation needed cancelling."
		)
	var snapshot: Dictionary = unit.action_budget.reaction_snapshot()
	var changes := TacticalChangeSet.new(
		&"reaction_reservation_cancelled",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget([unit.unit_id])
	)
	changes.stage(
		func() -> bool:
			return unit.action_budget.cancel_reaction_reservation(),
		func() -> void:
			unit.action_budget.restore_reaction_snapshot(snapshot),
		"The Reaction reservation could not be cancelled.",
		&"reaction_reservation_cancel_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_simple_event(
		&"reaction_reservation_cancelled",
		"%s cancelled the prepared Reaction by moving." % unit.display_name,
		unit,
		["Reaction returned to Ready; the Half Action remains spent."]
	)
	return OperationResult.committed(
		unit_id,
		"%s cancelled the prepared Reaction reservation." % unit.display_name,
		_state_store.state.revision
	)


func use_disengage(unit_id: StringName) -> OperationResult:
	if _state_store == null:
		return OperationResult.fail(&"reaction_service_missing", "Reaction services are unavailable.")
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(&"unknown_unit", "The selected unit does not exist.")
	if not _state_store.state.can_unit_act(unit_id):
		return OperationResult.fail(&"wrong_active_unit", "This unit is not currently active.")
	var reason: String = ActionEconomyRules.unavailable_reason(unit, ActionCost.half_action())
	if not reason.is_empty():
		return OperationResult.fail(&"disengage_unavailable", reason)
	var remaining_before: int = unit.action_budget.remaining_turn_capacity_feet
	var disengage_before: bool = unit.disengage_active
	var changes := TacticalChangeSet.new(
		&"disengage_activated",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget([unit.unit_id])
	)
	changes.stage(
		func() -> bool:
			if ActionEconomyRules.spend(unit, ActionCost.half_action()) < 0:
				return false
			unit.activate_disengage()
			return true,
		func() -> void:
			unit.action_budget.remaining_turn_capacity_feet = remaining_before
			unit.action_budget.normal_capacity_spent_feet = (
				unit.action_budget.maximum_turn_capacity_feet - remaining_before
			)
			unit.disengage_active = disengage_before,
		"Disengage could not be activated.",
		&"disengage_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_simple_event(
		&"disengage_activated",
		"%s used Disengage." % unit.display_name,
		unit,
		[
			"Protected from ordinary movement-based Attacks of Opportunity until this activation ends.",
			"Overwatch, Brace and separately provoking actions remain legal.",
		]
	)
	return OperationResult.ok(unit_id, "%s used Disengage." % unit.display_name)


func resolve_ai_reactions_along_path(
		mover_id: StringName,
		planned_path: Array[Vector2i],
		movement_kind: StringName,
		detection_resolution: TacticalDetectionResolution = null
) -> Dictionary:
	# Stage 4.5f deliberately retires this speculative API. It used to commit
	# reaction attacks against future path cells before the movement transaction
	# had committed. Movement handlers must now use first_*_reaction_for_path(),
	# candidates_for_movement_step(), and authoritative segment commits.
	push_error(
		"resolve_ai_reactions_along_path() is retired; use the authoritative movement coordinator."
	)
	return {
		"committed_path": planned_path.duplicate(),
		"reaction_resolutions": [],
		"stopped": false,
		"stop_reason": &"retired_speculative_reaction_api",
		"mover_id": mover_id,
		"movement_kind": movement_kind,
		"detection_resolution": detection_resolution,
	}


func preview_provoking_action_reactions(
		actor_id: StringName,
		action_id: StringName
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _action_provokes(action_id) or _state_store == null:
		return result
	var actor: TacticalUnitState = _state_store.state.get_unit(actor_id)
	if actor == null:
		return result
	var event_id := StringName("preview.action.%s.%s" % [actor_id, action_id])
	for candidate: ReactionCandidate in _candidates_for_provoking_action(
		actor, action_id, event_id, true
	):
		result.append(_candidate_summary(candidate))
	return result


func resolve_ai_reactions_for_provoking_action(
		actor_id: StringName,
		action_id: StringName
) -> Dictionary:
	var result: Dictionary = {
		"reaction_resolutions": [],
		"stopped": false,
		"stop_reason": &"",
	}
	if not _action_provokes(action_id) or _state_store == null:
		return result
	var actor: TacticalUnitState = _state_store.state.get_unit(actor_id)
	if actor == null:
		return result
	_action_sequence += 1
	var event_id := StringName("action.%s.%d" % [actor_id, _action_sequence])
	for candidate: ReactionCandidate in _candidates_for_provoking_action(
		actor, action_id, event_id, false
	):
		var reactor: TacticalUnitState = _state_store.state.get_unit(candidate.source_unit_id)
		if reactor == null or not reactor.is_ai_controlled():
			continue
		var attack_result: OperationResult = _execute_candidate(candidate)
		(result["reaction_resolutions"] as Array).append({
			"candidate": candidate,
			"result": attack_result,
			"reaction_kind": candidate.reaction_kind,
			"source_unit_id": candidate.source_unit_id,
			"target_unit_id": candidate.target_unit_id,
			"hit_chance_percent": candidate.predicted_hit_chance,
		})
		if attack_result.success and _movement_stopped_by_state(actor):
			result["stopped"] = true
			result["stop_reason"] = &"reaction_incapacitated"
			break
	return result


func first_player_reaction_for_provoking_action(
		actor_id: StringName,
		action_id: StringName
) -> ReactionCandidate:
	if not _action_provokes(action_id) or _state_store == null:
		return null
	var actor: TacticalUnitState = _state_store.state.get_unit(actor_id)
	if actor == null:
		return null
	_action_sequence += 1
	var event_id := StringName("action.%s.%d" % [actor_id, _action_sequence])
	for candidate: ReactionCandidate in _candidates_for_provoking_action(
		actor, action_id, event_id, false
	):
		var reactor: TacticalUnitState = _state_store.state.get_unit(candidate.source_unit_id)
		if reactor != null and reactor.is_player_controlled():
			return candidate
	return null


func candidates_for_movement_step(
		mover_id: StringName,
		origin: Vector2i,
		destination: Vector2i,
		path_index: int,
		movement_kind: StringName,
		movement_action_id: StringName
) -> Array[ReactionCandidate]:
	if _state_store == null:
		return []
	var mover: TacticalUnitState = _state_store.state.get_unit(mover_id)
	if mover == null:
		return []
	return _candidates_for_step(
		mover,
		origin,
		destination,
		path_index,
		movement_kind,
		movement_action_id,
		false
	)


func first_ai_reaction_for_path(
		mover_id: StringName,
		planned_path: Array[Vector2i],
		movement_kind: StringName = &"normal",
		movement_action_id_value: StringName = &""
) -> Dictionary:
	var result: Dictionary = {
		"candidate": null,
		"prefix_path": planned_path.duplicate(),
		"movement_action_id": &"",
	}
	if planned_path.size() <= 1 or _state_store == null:
		return result
	var mover: TacticalUnitState = _state_store.state.get_unit(mover_id)
	if mover == null:
		return result
	var movement_action_id: StringName = (
		movement_action_id_value
		if not movement_action_id_value.is_empty()
		else begin_movement_action_id(mover_id)
	)
	result["movement_action_id"] = movement_action_id
	for path_index: int in range(1, planned_path.size()):
		var origin: Vector2i = planned_path[path_index - 1]
		var destination: Vector2i = planned_path[path_index]
		for candidate: ReactionCandidate in _candidates_for_step(
			mover,
			origin,
			destination,
			path_index,
			movement_kind,
			movement_action_id,
			false
		):
			var reactor: TacticalUnitState = _state_store.state.get_unit(
				candidate.source_unit_id
			)
			if reactor == null or not reactor.is_ai_controlled():
				continue
			var prefix_end: int = (
				path_index
				if candidate.timing_kind == ReactionCandidate.TIMING_AFTER_ENTRY
				else path_index - 1
			)
			var prefix: Array[Vector2i] = []
			for index: int in range(0, prefix_end + 1):
				prefix.append(planned_path[index])
			result["candidate"] = candidate
			result["prefix_path"] = prefix
			return result
	return result


func first_player_reaction_for_path(
		mover_id: StringName,
		planned_path: Array[Vector2i],
		movement_kind: StringName = &"normal",
		movement_action_id_value: StringName = &""
) -> Dictionary:
	var result: Dictionary = {
		"candidate": null,
		"prefix_path": planned_path.duplicate(),
		"movement_action_id": &"",
	}
	if planned_path.size() <= 1 or _state_store == null:
		return result
	var mover: TacticalUnitState = _state_store.state.get_unit(mover_id)
	if mover == null:
		return result
	var movement_action_id: StringName = (
		movement_action_id_value
		if not movement_action_id_value.is_empty()
		else begin_movement_action_id(mover_id)
	)
	result["movement_action_id"] = movement_action_id
	for path_index: int in range(1, planned_path.size()):
		var origin: Vector2i = planned_path[path_index - 1]
		var destination: Vector2i = planned_path[path_index]
		var candidates: Array[ReactionCandidate] = _candidates_for_step(
			mover,
			origin,
			destination,
			path_index,
			movement_kind,
			movement_action_id,
			false
		)
		for candidate: ReactionCandidate in candidates:
			var reactor: TacticalUnitState = _state_store.state.get_unit(candidate.source_unit_id)
			if reactor == null or not reactor.is_player_controlled():
				continue
			var prefix_end: int = (
				path_index
				if candidate.timing_kind == ReactionCandidate.TIMING_AFTER_ENTRY
				else path_index - 1
			)
			var prefix: Array[Vector2i] = []
			for index: int in range(0, prefix_end + 1):
				prefix.append(planned_path[index])
			result["candidate"] = candidate
			result["prefix_path"] = prefix
			return result
	return result


func open_player_decision(candidate: ReactionCandidate) -> OperationResult:
	if candidate == null or not candidate.legal:
		return OperationResult.fail(&"reaction_candidate_invalid", "The Reaction is no longer legal.")
	if has_pending_decision():
		return OperationResult.fail(&"reaction_decision_pending", "Another Reaction decision is already pending.")
	var reactor: TacticalUnitState = _state_store.state.get_unit(candidate.source_unit_id)
	var target: TacticalUnitState = _state_store.state.get_unit(candidate.target_unit_id)
	if reactor == null or target == null or not reactor.is_player_controlled():
		return OperationResult.fail(
			&"reaction_controller_invalid",
			"The Reaction does not belong to a player-controlled unit."
		)
	var pending: PendingMovementReactionState = _pending_state()
	if pending != null and pending.candidate != null:
		if _candidate_suppression_key(pending.candidate) != _candidate_suppression_key(candidate):
			return OperationResult.fail(
				&"reaction_decision_stale",
				"The authoritative interrupted movement now references another Reaction."
			)
	if pending == null:
		pending = PendingMovementReactionState.new()
		pending.movement_action_id = candidate.movement_action_id
		pending.mover_unit_id = candidate.target_unit_id
		pending.candidate = candidate
		pending.continuation_kind = PendingMovementReactionState.CONTINUATION_STANDALONE_REACTION
		pending.source_revision = _state_store.state.revision
	else:
		pending = pending.duplicate_state()

	_request_sequence += 1
	var request := ReactionDecisionRequest.new()
	request.request_id = StringName(
		"reaction.request.r%d.%d"
		% [_state_store.state.revision, _request_sequence]
	)
	request.candidate = candidate
	request.controller_id = reactor.controller_type
	request.reacting_unit_id = reactor.unit_id
	request.triggering_unit_id = target.unit_id
	request.triggering_action_name = candidate.triggering_action_name
	request.reaction_display_name = _reaction_display_name(candidate.reaction_kind)
	request.weapon_display_name = _weapon_display_name(reactor, candidate.attack_action_id)
	request.predicted_hit_chance = candidate.predicted_hit_chance
	request.predicted_damage_text = candidate.predicted_damage_text
	request.created_event_id = candidate.triggering_event_id
	match candidate.reaction_kind:
		ReactionCandidate.KIND_OVERWATCH:
			request.use_label = "Fire"
			request.decline_label = "Hold Fire"
			request.use_choice = ReactionDecisionRequest.CHOICE_FIRE
			request.decline_choice = ReactionDecisionRequest.CHOICE_HOLD
			request.decline_keeps_reservation = true
			var reserved_attack: AttackDefinition = _catalogue.attack_definition(
				candidate.attack_action_id
			)
			var overwatch_modifier: int = _patient_overwatch_modifier(
				reactor, reserved_attack
			)
			var modifier_text: String = (
				"Patient Overwatch modifier: %+d" % overwatch_modifier
				if overwatch_modifier != -2
				else "Overwatch attack modifier: −2"
			)
			request.modifier_lines.append(modifier_text)
		ReactionCandidate.KIND_BRACE:
			request.use_label = "Use Brace"
			request.decline_label = "Hold Brace"
			request.use_choice = ReactionDecisionRequest.CHOICE_USE_BRACE
			request.decline_choice = ReactionDecisionRequest.CHOICE_HOLD_BRACE
			request.decline_keeps_reservation = true
		_:
			request.use_label = "Use Reaction"
			request.decline_label = "Decline"
			request.use_choice = ReactionDecisionRequest.CHOICE_USE
			request.decline_choice = ReactionDecisionRequest.CHOICE_DECLINE
	pending.candidate = candidate
	pending.request = request
	pending.decision_resolved = false
	pending.resolved_choice = &""
	pending.source_revision = _state_store.state.revision
	var committed: OperationResult = commit_pending_movement_reaction(
		pending,
		&"movement_reaction_decision_opened"
	)
	if not committed.success:
		return committed
	_performance["player_reaction_prompts_opened"] = int(
		_performance["player_reaction_prompts_opened"]
	) + 1
	_record_decision_event(request, "Offered")
	reaction_decision_requested.emit(request)
	return OperationResult.pending(
		&"reaction_decision_pending",
		request,
		"%s may use %s." % [reactor.display_name, request.reaction_display_name],
		_state_store.state.revision
	)


func resolve_pending_decision(
		request_id: StringName,
		choice: StringName
) -> OperationResult:
	var pending: PendingMovementReactionState = _pending_state()
	var request: ReactionDecisionRequest = pending.request if pending != null else null
	var candidate: ReactionCandidate = pending.candidate if pending != null else null
	if pending == null or request == null or candidate == null or not pending.has_unresolved_decision():
		_performance["stale_reaction_decisions_rejected"] = int(
			_performance["stale_reaction_decisions_rejected"]
		) + 1
		return OperationResult.fail(&"reaction_decision_missing", "There is no active Reaction decision.")
	if request_id != request.request_id or not request.is_valid_choice(choice):
		_performance["stale_reaction_decisions_rejected"] = int(
			_performance["stale_reaction_decisions_rejected"]
		) + 1
		return OperationResult.fail(&"reaction_decision_stale", "That Reaction decision is stale or invalid.")
	var use_reaction: bool = choice == request.use_choice
	var attack_result: OperationResult = null
	if use_reaction:
		attack_result = execute_candidate(candidate)
		if not attack_result.success:
			return attack_result
		_performance["player_reactions_used"] = int(
			_performance["player_reactions_used"]
		) + 1
	else:
		_performance["player_reactions_declined_or_held"] = int(
			_performance["player_reactions_declined_or_held"]
		) + 1

	# The attack may have advanced the tactical revision. Read the authoritative
	# pending state again and commit the decision outcome separately.
	pending = _pending_state()
	if pending == null or pending.request == null or pending.request.request_id != request_id:
		return OperationResult.fail(
			&"reaction_decision_stale",
			"The interrupted movement changed while the Reaction resolved."
		)
	var updated: PendingMovementReactionState = pending.duplicate_state()
	var resolved_request: ReactionDecisionRequest = _duplicate_request(request)
	resolved_request.resolved = true
	updated.request = resolved_request
	updated.decision_resolved = true
	updated.resolved_choice = choice
	updated.source_revision = _state_store.state.revision
	if not use_reaction:
		updated.suppressed_candidate_keys[_candidate_suppression_key(candidate)] = true
	var committed: OperationResult = commit_pending_movement_reaction(
		updated,
		&"movement_reaction_decision_resolved"
	)
	if not committed.success:
		return committed
	_record_decision_event(
		request,
		"Used" if use_reaction else "Held" if request.decline_keeps_reservation else "Declined"
	)
	var resolution := ReactionDecisionResolution.new()
	resolution.request_id = request.request_id
	resolution.choice = choice
	resolution.resolved_by_controller_id = request.controller_id
	resolution.candidate_selected = use_reaction
	resolution.reaction_state_changed = use_reaction
	resolution.attack_result = attack_result
	reaction_decision_cleared.emit(request.request_id)
	return OperationResult.committed(
		resolution,
		"Reaction decision resolved.",
		_state_store.state.revision
	)


func commit_pending_movement_reaction(
		pending: PendingMovementReactionState,
		reason: StringName = &"movement_reaction_pending"
) -> OperationResult:
	if _state_store == null or _state_store.state == null or pending == null:
		return OperationResult.fail(
			&"pending_reaction_state_missing",
			"An authoritative pending movement Reaction is required."
		)
	var previous: PendingMovementReactionState = _state_store.state.pending_movement_reaction
	var affected_units: Array[StringName] = [pending.mover_unit_id]
	if pending.candidate != null:
		affected_units.append(pending.candidate.source_unit_id)
	var changes := TacticalChangeSet.new(
		reason,
		_state_store.state.revision,
		TacticalInvalidationContract.pending_decision(affected_units)
	)
	changes.set_allow_while_pending(true)
	changes.set_commit_validation_policy(false, false)
	changes.stage(
		Callable(self, "_set_pending_state").bind(pending),
		Callable(self, "_set_pending_state").bind(previous),
		"The interrupted movement Reaction could not become authoritative.",
		&"pending_reaction_commit_failed"
	)
	changes.require(
		func() -> bool:
			return _state_store.state.validate_pending_reaction_invariants().is_empty(),
		"The interrupted movement Reaction violates tactical-state invariants.",
		&"pending_reaction_invariant_failed"
	)
	return _state_store.commit(changes, _map_definition)


func clear_pending_movement_reaction(
		movement_action_id: StringName = &""
) -> OperationResult:
	var pending: PendingMovementReactionState = _pending_state()
	if pending == null:
		return OperationResult.no_change(null, "No interrupted movement Reaction remains.")
	if not movement_action_id.is_empty() and pending.movement_action_id != movement_action_id:
		return OperationResult.fail(
			&"pending_reaction_stale",
			"Another interrupted movement has replaced this continuation."
		)
	var request_id: StringName = pending.request.request_id if pending.request != null else &""
	var changes := TacticalChangeSet.new(
		&"movement_reaction_cleared",
		_state_store.state.revision,
		TacticalInvalidationContract.pending_decision([pending.mover_unit_id])
	)
	changes.set_allow_while_pending(true)
	changes.set_commit_validation_policy(false, false)
	changes.stage(
		Callable(self, "_set_pending_state").bind(null),
		Callable(self, "_set_pending_state").bind(pending),
		"The interrupted movement Reaction could not be cleared.",
		&"pending_reaction_clear_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if committed.success and not request_id.is_empty():
		reaction_decision_cleared.emit(request_id)
	return committed


func execute_candidate(candidate: ReactionCandidate) -> OperationResult:
	return _execute_candidate(candidate)


func _pending_state() -> PendingMovementReactionState:
	if _state_store == null or _state_store.state == null:
		return null
	return _state_store.state.pending_movement_reaction


func _set_pending_state(value: PendingMovementReactionState) -> bool:
	if _state_store == null or _state_store.state == null:
		return false
	_state_store.state.pending_movement_reaction = value
	return true


func _duplicate_request(request: ReactionDecisionRequest) -> ReactionDecisionRequest:
	var result := ReactionDecisionRequest.new()
	result.request_id = request.request_id
	result.candidate = request.candidate
	result.controller_id = request.controller_id
	result.reacting_unit_id = request.reacting_unit_id
	result.triggering_unit_id = request.triggering_unit_id
	result.triggering_action_name = request.triggering_action_name
	result.reaction_display_name = request.reaction_display_name
	result.weapon_display_name = request.weapon_display_name
	result.predicted_hit_chance = request.predicted_hit_chance
	result.predicted_damage_text = request.predicted_damage_text
	result.modifier_lines = request.modifier_lines.duplicate()
	result.use_label = request.use_label
	result.decline_label = request.decline_label
	result.use_choice = request.use_choice
	result.decline_choice = request.decline_choice
	result.decline_keeps_reservation = request.decline_keeps_reservation
	result.created_event_id = request.created_event_id
	result.resolved = request.resolved
	return result


func _prepare_reservation(
		unit_id: StringName,
		reaction_kind: StringName,
		direction_value: Vector2i
) -> OperationResult:
	var reason: String = reaction_unavailable_reason(unit_id, reaction_kind)
	if not reason.is_empty():
		return OperationResult.fail(&"reaction_reservation_unavailable", reason)
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	var direction: Vector2i = TacticalPerceptionRules.normalized_facing(direction_value)
	if direction == Vector2i.ZERO:
		return OperationResult.fail(&"reaction_direction_invalid", "Choose a direction for the Reaction area.")
	var attack_action_id: StringName = (
		_ranged_attack_action_id(unit)
		if reaction_kind == ReactionReservationState.KIND_OVERWATCH
		else _brace_attack_action_id(unit)
	)
	var reservation := ReactionReservationState.new()
	reservation.reaction_kind = reaction_kind
	reservation.reaction_definition_id = StringName("reaction.%s" % reaction_kind)
	reservation.source_unit_id = unit.unit_id
	reservation.controller_id = unit.controller_type
	reservation.reserved_attack_action_id = attack_action_id
	reservation.reserved_weapon_item_id = _source_item_id(unit, attack_action_id)
	reservation.direction = direction
	reservation.created_round = _state_store.state.phase_state.round_number
	reservation.created_activation_id = StringName(
		"round.%d.%s" % [reservation.created_round, unit.unit_id]
	)
	reservation.covered_tiles = _reservation_tiles(unit, reaction_kind, direction, attack_action_id)
	if reservation.covered_tiles.is_empty():
		return OperationResult.fail(&"reaction_area_empty", "No legal tiles exist in that Reaction area.")
	var budget_before: Dictionary = unit.action_budget.reaction_snapshot()
	var remaining_before: int = unit.action_budget.remaining_turn_capacity_feet
	var spent_before: int = unit.action_budget.normal_capacity_spent_feet
	var facing_before: Vector2i = unit.facing_direction
	var changes := TacticalChangeSet.new(
		&"reaction_reserved",
		_state_store.state.revision,
		TacticalInvalidationContract.action_budget([unit.unit_id])
	)
	changes.stage(
		func() -> bool:
			if ActionEconomyRules.spend(unit, ActionCost.half_action()) < 0:
				return false
			if not unit.action_budget.reserve_reaction(reservation):
				return false
			unit.set_facing(direction)
			return true,
		func() -> void:
			unit.action_budget.remaining_turn_capacity_feet = remaining_before
			unit.action_budget.normal_capacity_spent_feet = spent_before
			unit.action_budget.restore_reaction_snapshot(budget_before)
			unit.facing_direction = facing_before,
		"The Reaction reservation could not be committed.",
		&"reaction_reservation_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		return committed
	_record_simple_event(
		&"reaction_reserved",
		"%s prepared %s." % [unit.display_name, _reaction_display_name(reaction_kind)],
		unit,
		[
			"Reaction: Ready → %s" % _reaction_display_name(reaction_kind),
			"Direction: (%d, %d)" % [direction.x, direction.y],
			"Covered tiles: %d" % reservation.covered_tiles.size(),
		]
	)
	return OperationResult.ok(reservation, "%s prepared %s." % [
		unit.display_name,
		_reaction_display_name(reaction_kind),
	])


func _candidates_for_provoking_action(
		actor: TacticalUnitState,
		action_id: StringName,
		event_id: StringName,
		preview_only: bool
) -> Array[ReactionCandidate]:
	var result: Array[ReactionCandidate] = []
	if actor == null or not _action_provokes(action_id):
		return result
	var action: ActionDefinition = _catalogue.action_definition(action_id)
	_ensure_reaction_indexes()
	var source_ids: Array[StringName] = _indexed_source_ids(
		_threat_source_ids_by_tile, actor.grid_position
	)
	for reactor_id: StringName in source_ids:
		var reactor: TacticalUnitState = _state_store.state.get_unit(reactor_id)
		if reactor == null or reactor.unit_id == actor.unit_id:
			continue
		if not TacticalTeamRelations.are_hostile(reactor.team_id, actor.team_id):
			continue
		if reactor.action_budget.reaction_state != ReactionResourceState.AVAILABLE:
			continue
		if not _can_perceive(reactor, actor):
			continue
		if not _threatens_tile(reactor, actor, actor.grid_position):
			continue
		var candidate := _build_candidate(
			reactor,
			actor,
			ReactionCandidate.KIND_ATTACK_OF_OPPORTUNITY,
			_melee_attack_action_id(reactor),
			actor.grid_position,
			actor.grid_position,
			actor.grid_position,
			0,
			ReactionCandidate.TIMING_BEFORE_ENTRY,
			0,
			event_id,
			preview_only
		)
		if candidate == null:
			continue
		candidate.triggering_action_name = (
			action.display_name if action != null else "Provoking Action"
		)
		result.append(candidate)
	result.sort_custom(_candidate_precedes)
	return result


func _action_provokes(action_id: StringName) -> bool:
	if _catalogue == null or action_id.is_empty():
		return false
	var action: ActionDefinition = _catalogue.action_definition(action_id)
	return action != null and action.provokes


func _candidates_for_step(
		mover: TacticalUnitState,
		origin: Vector2i,
		destination: Vector2i,
		path_index: int,
		movement_kind: StringName,
		movement_action_id: StringName,
		preview_only: bool,
		virtual_revealed_squad_ids: Dictionary = {}
) -> Array[ReactionCandidate]:
	_performance["reaction_windows_opened"] = int(
		_performance["reaction_windows_opened"]
	) + 1
	var result: Array[ReactionCandidate] = []
	_ensure_reaction_indexes()
	var source_id_set: Dictionary = {}
	for source_id: StringName in _indexed_source_ids(
		_threat_source_ids_by_tile, origin
	):
		source_id_set[source_id] = true
	for source_id: StringName in _indexed_source_ids(
		_reserved_source_ids_by_tile, destination
	):
		source_id_set[source_id] = true
	var source_ids: Array[StringName] = []
	for source_id_value: Variant in source_id_set.keys():
		source_ids.append(StringName(source_id_value))
	source_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	for reactor_id: StringName in source_ids:
		var reactor: TacticalUnitState = _state_store.state.get_unit(reactor_id)
		if reactor == null or reactor.unit_id == mover.unit_id:
			continue
		if not TacticalTeamRelations.are_hostile(reactor.team_id, mover.team_id):
			continue
		_performance["reaction_candidates_examined"] = int(
			_performance["reaction_candidates_examined"]
		) + 1
		if not _can_perceive(reactor, mover, virtual_revealed_squad_ids):
			continue
		if reactor.action_budget.reaction_state == ReactionResourceState.AVAILABLE:
			if (
				movement_kind in [&"normal", &"sprint"]
				and not mover.disengage_active
				and _threatens_tile(reactor, mover, origin)
			):
				var candidate := _build_candidate(
					reactor,
					mover,
					ReactionCandidate.KIND_ATTACK_OF_OPPORTUNITY,
					_melee_attack_action_id(reactor),
					origin,
					destination,
					origin,
					path_index,
					ReactionCandidate.TIMING_BEFORE_ENTRY,
					0,
					movement_action_id,
					preview_only
				)
				if candidate != null:
					result.append(candidate)
		elif reactor.action_budget.reaction_state == ReactionResourceState.RESERVED:
			var reservation: ReactionReservationState = reactor.action_budget.reaction_reservation
			if reservation == null or not reservation.contains(destination):
				continue
			var kind: StringName = &""
			var modifier: int = 0
			if reservation.reaction_kind == ReactionReservationState.KIND_OVERWATCH:
				kind = ReactionCandidate.KIND_OVERWATCH
				var reserved_attack: AttackDefinition = _catalogue.attack_definition(
					reservation.reserved_attack_action_id
				)
				modifier = _patient_overwatch_modifier(reactor, reserved_attack)
				_performance["overwatch_area_intersections"] = int(
					_performance["overwatch_area_intersections"]
				) + 1
			elif reservation.reaction_kind == ReactionReservationState.KIND_BRACE:
				kind = ReactionCandidate.KIND_BRACE
				_performance["brace_area_intersections"] = int(
					_performance["brace_area_intersections"]
				) + 1
			if kind.is_empty():
				continue
			var reserved_candidate := _build_candidate(
				reactor,
				mover,
				kind,
				reservation.reserved_attack_action_id,
				origin,
				destination,
				destination,
				path_index,
				ReactionCandidate.TIMING_AFTER_ENTRY,
				modifier,
				movement_action_id,
				preview_only
			)
			if reserved_candidate != null:
				result.append(reserved_candidate)
	result.sort_custom(_candidate_precedes)
	return result


func _patient_overwatch_modifier(
		reactor: TacticalUnitState,
		attack: AttackDefinition
) -> int:
	if (
		reactor == null
		or reactor.resolved_character == null
		or attack == null
		or not attack.attack_tags.has(&"capture_bow")
		or not reactor.resolved_character.has_trait(&"feat.patient_overwatch")
	):
		return -2
	return int(reactor.resolved_character.feature_parameter(
		&"feat.patient_overwatch",
		&"reaction_attack_modifier",
		-1
	))


func _build_candidate(
		reactor: TacticalUnitState,
		mover: TacticalUnitState,
		reaction_kind: StringName,
		attack_action_id: StringName,
		origin: Vector2i,
		destination: Vector2i,
		target_position: Vector2i,
		path_index: int,
		timing_kind: StringName,
		attack_modifier: int,
		movement_action_id: StringName,
		preview_only: bool
) -> ReactionCandidate:
	if attack_action_id.is_empty():
		return null
	var candidate := ReactionCandidate.new()
	candidate.reaction_kind = reaction_kind
	candidate.source_unit_id = reactor.unit_id
	candidate.target_unit_id = mover.unit_id
	candidate.attack_action_id = attack_action_id
	candidate.trigger_origin = origin
	candidate.trigger_destination = destination
	candidate.target_position = target_position
	candidate.path_index = path_index
	candidate.timing_kind = timing_kind
	candidate.attack_modifier = attack_modifier
	candidate.movement_action_id = movement_action_id
	candidate.triggering_event_id = StringName(
		"%s.step.%d.%s" % [movement_action_id, path_index, reaction_kind]
	)
	candidate.player_decision_required = reactor.is_player_controlled()
	if _candidate_is_suppressed(candidate):
		return null
	var preview = _attack_preview_query.call(
		"execute_reaction",
		reactor.unit_id,
		mover.unit_id,
		attack_action_id,
		reaction_kind,
		attack_modifier,
		target_position
	)
	if preview == null or not bool(preview.get("success")):
		candidate.invalidity_reason = (
			str(preview.get("reason")) if preview != null else "Reaction attack preview failed."
		)
		return null
	candidate.predicted_hit_chance = int(preview.get("hit_chance_percent"))
	candidate.predicted_damage_text = str(preview.get("damage_notation"))
	candidate.legal = true
	candidate.priority_key = [
		0 if timing_kind == ReactionCandidate.TIMING_BEFORE_ENTRY else 1,
		-_initiative_total(reactor),
		-reactor.initiative_modifier(),
		-_dexterity_score(reactor),
		_reaction_tie_break(reactor.unit_id),
		String(reactor.unit_id),
	]
	return candidate


func _execute_candidate(candidate: ReactionCandidate) -> OperationResult:
	if candidate == null or not candidate.legal:
		return OperationResult.fail(&"reaction_candidate_invalid", "The Reaction is no longer legal.")
	var preview = _attack_preview_query.call(
		"execute_reaction",
		candidate.source_unit_id,
		candidate.target_unit_id,
		candidate.attack_action_id,
		candidate.reaction_kind,
		candidate.attack_modifier,
		candidate.target_position
	)
	if preview == null or not bool(preview.get("success")):
		return OperationResult.fail(
			&"reaction_attack_invalid",
			str(preview.get("reason")) if preview != null else "The Reaction attack is unavailable."
		)
	var result: OperationResult = _attack_handler.call("execute_preview", preview) as OperationResult
	if result != null and result.success:
		_performance["valid_reactions_resolved"] = int(
			_performance["valid_reactions_resolved"]
		) + 1
	return result if result != null else OperationResult.fail(
		&"reaction_attack_missing_result",
		"The Reaction attack returned no result."
	)


func _candidate_precedes(first: ReactionCandidate, second: ReactionCandidate) -> bool:
	for index: int in range(mini(first.priority_key.size(), second.priority_key.size())):
		var a: Variant = first.priority_key[index]
		var b: Variant = second.priority_key[index]
		if a == b:
			continue
		return a < b
	return String(first.source_unit_id) < String(second.source_unit_id)


func _candidate_suppression_key(candidate: ReactionCandidate) -> String:
	return "%s|%s|%s|%s" % [
		candidate.movement_action_id,
		candidate.source_unit_id,
		candidate.target_unit_id,
		candidate.reaction_kind,
	]


func _candidate_is_suppressed(candidate: ReactionCandidate) -> bool:
	var pending: PendingMovementReactionState = _pending_state()
	return (
		pending != null
		and pending.movement_action_id == candidate.movement_action_id
		and pending.candidate_is_suppressed(_candidate_suppression_key(candidate))
	)


func _candidate_summary(candidate: ReactionCandidate) -> Dictionary:
	var source: TacticalUnitState = _state_store.state.get_unit(candidate.source_unit_id)
	return {
		"source_unit_id": candidate.source_unit_id,
		"source_name": source.display_name if source != null else String(candidate.source_unit_id),
		"reaction_kind": candidate.reaction_kind,
		"hit_chance_percent": candidate.predicted_hit_chance,
		"damage_text": candidate.predicted_damage_text,
		"trigger_tile": candidate.target_position,
	}


func _invalidate_reaction_indexes() -> void:
	_reaction_index_revision = -1
	_threat_source_ids_by_tile.clear()
	_reserved_source_ids_by_tile.clear()


func _ensure_reaction_indexes() -> void:
	if _state_store == null or _state_store.state == null:
		return
	if _reaction_index_revision == _state_store.state.revision:
		return
	_threat_source_ids_by_tile.clear()
	_reserved_source_ids_by_tile.clear()
	for source: TacticalUnitState in _state_store.state.get_units():
		if source == null or not source.can_take_actions():
			continue
		if source.action_budget.reaction_state == ReactionResourceState.AVAILABLE:
			for tile: Vector2i in _threatened_tiles_for_unit(source):
				_index_source(_threat_source_ids_by_tile, tile, source.unit_id)
		elif (
			source.action_budget.reaction_state == ReactionResourceState.RESERVED
			and source.action_budget.reaction_reservation != null
		):
			for tile: Vector2i in source.action_budget.reaction_reservation.covered_tiles:
				_index_source(_reserved_source_ids_by_tile, tile, source.unit_id)
	_reaction_index_revision = _state_store.state.revision
	_performance["threat_cache_rebuilds"] = int(
		_performance["threat_cache_rebuilds"]
	) + 1


func _index_source(index: Dictionary, tile: Vector2i, source_id: StringName) -> void:
	var values: Array[StringName] = []
	var existing: Variant = index.get(tile)
	if existing is Array:
		for value: Variant in existing:
			values.append(StringName(value))
	if not values.has(source_id):
		values.append(source_id)
	index[tile] = values


func _indexed_source_ids(index: Dictionary, tile: Vector2i) -> Array[StringName]:
	var result: Array[StringName] = []
	var values: Variant = index.get(tile)
	if values is Array:
		for value: Variant in values:
			result.append(StringName(value))
	return result


func _threatened_tiles_for_unit(source: TacticalUnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var action_id: StringName = _melee_attack_action_id(source)
	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	if attack == null or attack.range_profile == null:
		return result
	var range_tiles: int = maxi(1, attack.range_profile.reach_feet / 5)
	var preview_target := TacticalUnitState.new(&"reaction.threat.preview", "Preview")
	preview_target.footprint = Vector2i.ONE
	for y: int in range(
		maxi(0, source.grid_position.y - range_tiles),
		mini(_map_definition.grid_size.y, source.grid_position.y + range_tiles + 1)
	):
		for x: int in range(
			maxi(0, source.grid_position.x - range_tiles),
			mini(_map_definition.grid_size.x, source.grid_position.x + range_tiles + 1)
		):
			var tile := Vector2i(x, y)
			if tile == source.grid_position:
				continue
			preview_target.grid_position = tile
			if _threatens_tile(source, preview_target, tile):
				result.append(tile)
	return result


func _reaction_tie_break(unit_id: StringName) -> int:
	# Stable for the lifetime of this tactical session and deterministic across
	# replay/save restoration without rerolling every Reaction window.
	return absi(hash("reaction.tie.%s" % String(unit_id)))


func _nearest_perceived_hostile(unit: TacticalUnitState) -> TacticalUnitState:
	var best: TacticalUnitState = null
	var best_distance: int = 2147483647
	for candidate: TacticalUnitState in _state_store.state.get_units():
		if candidate == null or candidate.is_defeated():
			continue
		if not TacticalTeamRelations.are_hostile(unit.team_id, candidate.team_id):
			continue
		if not _can_perceive(unit, candidate):
			continue
		var distance: int = maxi(
			absi(candidate.grid_position.x - unit.grid_position.x),
			absi(candidate.grid_position.y - unit.grid_position.y)
		)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _can_perceive(
		reactor: TacticalUnitState,
		mover: TacticalUnitState,
		virtual_revealed_squad_ids: Dictionary = {}
) -> bool:
	if reactor == null or mover == null or not reactor.can_take_actions():
		return false
	if mover.stealth_enabled:
		if reactor.squad_id.is_empty():
			return false
		if (
			not mover.is_revealed_to_squad(reactor.squad_id)
			and not virtual_revealed_squad_ids.has(reactor.squad_id)
		):
			return false
	# Exact line of sight and line of effect at the proposed tile are revalidated
	# by the reaction attack preview. Squad revelation is the authoritative
	# hidden-target gate; do not query the mover's current tile here when
	# evaluating a future path step.
	return true


func _threatens_tile(
		reactor: TacticalUnitState,
		mover: TacticalUnitState,
		target_position: Vector2i
) -> bool:
	var action_id: StringName = _melee_attack_action_id(reactor)
	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	if attack == null or attack.range_profile == null:
		return false
	var attacker_cells: Array[Vector2i] = _cells_at(reactor, reactor.grid_position)
	var target_cells: Array[Vector2i] = _cells_at(mover, target_position)
	return TacticalMeleeReachRules.can_reach(
		attacker_cells,
		target_cells,
		_map_definition,
		maxi(5, attack.range_profile.reach_feet)
	)


func _cells_at(unit: TacticalUnitState, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(maxi(1, unit.footprint.y)):
		for x: int in range(maxi(1, unit.footprint.x)):
			result.append(origin + Vector2i(x, y))
	return result


func _source_item_id(
		unit: TacticalUnitState,
		action_id: StringName
) -> StringName:
	if unit == null or action_id.is_empty():
		return &""
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = _state_store.state.get_hand_item(
			unit.unit_id, hand_kind
		)
		if (
			item != null
			and item.definition != null
			and item.definition.granted_action_ids.has(action_id)
		):
			return item.item_id
	return &""


func _melee_attack_action_id(unit: TacticalUnitState) -> StringName:
	if unit == null:
		return &""
	for action_id: StringName in _state_store.state.granted_action_ids_for_unit(unit.unit_id):
		var attack: AttackDefinition = _catalogue.attack_definition(action_id)
		if attack != null and attack.is_implemented_melee_weapon_attack():
			return action_id
	return &""


func _brace_attack_action_id(unit: TacticalUnitState) -> StringName:
	if unit == null:
		return &""
	for action_id: StringName in _state_store.state.granted_action_ids_for_unit(unit.unit_id):
		var attack: AttackDefinition = _catalogue.attack_definition(action_id)
		if (
			attack != null
			and attack.is_implemented_melee_weapon_attack()
			and attack.attack_tags.has(&"spear")
		):
			return action_id
	return &""


func _ranged_attack_action_id(unit: TacticalUnitState) -> StringName:
	if unit == null:
		return &""
	for action_id: StringName in _state_store.state.granted_action_ids_for_unit(unit.unit_id):
		var attack: AttackDefinition = _catalogue.attack_definition(action_id)
		if attack != null and attack.is_implemented_ranged_weapon_attack():
			return action_id
	return &""


func _reservation_tiles(
		unit: TacticalUnitState,
		reaction_kind: StringName,
		direction: Vector2i,
		attack_action_id: StringName
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var attack: AttackDefinition = _catalogue.attack_definition(attack_action_id)
	if attack == null or attack.range_profile == null:
		return result
	var range_tiles: int = 1
	if reaction_kind == ReactionReservationState.KIND_OVERWATCH:
		range_tiles = maxi(1, attack.range_profile.range_increment_feet / 5)
	else:
		range_tiles = maxi(1, attack.range_profile.reach_feet / 5)
	var forward: Vector2 = Vector2(direction).normalized()
	for y: int in range(
		maxi(0, unit.grid_position.y - range_tiles),
		mini(_map_definition.grid_size.y, unit.grid_position.y + range_tiles + 1)
	):
		for x: int in range(
			maxi(0, unit.grid_position.x - range_tiles),
			mini(_map_definition.grid_size.x, unit.grid_position.x + range_tiles + 1)
		):
			var tile := Vector2i(x, y)
			if tile == unit.grid_position:
				continue
			var offset: Vector2 = Vector2(tile - unit.grid_position)
			var distance_tiles: float = maxf(absf(offset.x), absf(offset.y))
			if distance_tiles > float(range_tiles):
				continue
			var normalized: Vector2 = offset.normalized()
			if normalized == Vector2.ZERO or forward.dot(normalized) < 0.707:
				continue
			if not _map_definition.is_inside(tile):
				continue
			if reaction_kind == ReactionReservationState.KIND_BRACE:
				var dummy_target := TacticalUnitState.new(&"preview", "Preview", tile)
				dummy_target.footprint = Vector2i.ONE
				if not _threatens_tile(unit, dummy_target, tile):
					continue
			result.append(tile)
	return result


func _apply_virtual_detection_for_index(
		detection_resolution: TacticalDetectionResolution,
		path_index: int,
		virtual_revealed_squad_ids: Dictionary
) -> void:
	if detection_resolution == null:
		return
	for check: TacticalDetectionTileCheck in detection_resolution.tile_checks:
		if check.path_index != path_index or not check.detected():
			continue
		for squad_id: StringName in check.detected_squad_ids:
			virtual_revealed_squad_ids[squad_id] = true


func _movement_stopped_by_state(unit: TacticalUnitState) -> bool:
	return unit == null or not unit.can_take_actions()


func _initiative_total(unit: TacticalUnitState) -> int:
	if unit == null:
		return 0
	return _state_store.state.phase_state.initiative_total(unit.unit_id)


func _dexterity_score(unit: TacticalUnitState) -> int:
	return (
		unit.resolved_character.ability_score("DEX")
		if unit != null and unit.resolved_character != null
		else 10
	)


func _weapon_display_name(unit: TacticalUnitState, action_id: StringName) -> String:
	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	return attack.display_name if attack != null else "Weapon"


func _reaction_display_name(kind: StringName) -> String:
	match kind:
		ReactionCandidate.KIND_ATTACK_OF_OPPORTUNITY:
			return "Attack of Opportunity"
		ReactionCandidate.KIND_OVERWATCH, ReactionReservationState.KIND_OVERWATCH:
			return "Overwatch"
		ReactionCandidate.KIND_BRACE, ReactionReservationState.KIND_BRACE:
			return "Brace"
	return "Reaction"


func _record_decision_event(request: ReactionDecisionRequest, decision: String) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var reactor: TacticalUnitState = _state_store.state.get_unit(request.reacting_unit_id)
	var target: TacticalUnitState = _state_store.state.get_unit(request.triggering_unit_id)
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"reaction_decision",
		phase.round_number,
		phase.current_phase,
		"%s — %s: %s."
		% [
			reactor.display_name if reactor != null else "Unit",
			request.reaction_display_name,
			decision,
		],
		{
			"category": &"combat",
			"source_actor_id": request.reacting_unit_id,
			"target_actor_ids": [request.triggering_unit_id],
			"details": [
				"Target: %s" % (target.display_name if target != null else "Unknown"),
				"Predicted hit chance: %d%%" % request.predicted_hit_chance,
				"Decision: %s" % decision,
			],
		}
	)


func _record_simple_event(
		event_type: StringName,
		summary: String,
		unit: TacticalUnitState,
		details: Array[String]
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		event_type,
		phase.round_number,
		phase.current_phase,
		summary,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id if unit != null else &"",
			"details": details,
		}
	)
