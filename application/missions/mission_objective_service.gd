class_name MissionObjectiveService
extends RefCounted

const RECONCILE_REASON: StringName = &"mission_objectives_reconciled"

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _mission_definition: MissionDefinition
var _setup: MissionSetupSnapshot
var _event_journal: RefCounted


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		mission_definition: MissionDefinition,
		setup: MissionSetupSnapshot,
		event_journal: RefCounted
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_mission_definition = mission_definition
	_setup = setup
	_event_journal = event_journal
	if _state_store != null and not _state_store.state_changed.is_connected(_on_state_changed):
		_state_store.state_changed.connect(_on_state_changed)
	reconcile_now()


func reconcile_now() -> OperationResult:
	if _state_store == null or _mission_definition == null or _setup == null:
		return OperationResult.no_change(null, "Mission objectives are not configured.")
	var state: TacticalState = _state_store.state
	if state == null or state.mission_runtime_state == null:
		return OperationResult.no_change(null, "Mission runtime state is unavailable.")
	var candidate: MissionRuntimeState = state.mission_runtime_state.duplicate_state()
	_evaluate(candidate, state)
	if candidate.equivalent_to(state.mission_runtime_state):
		return OperationResult.no_change(candidate, "Mission objectives are already current.")

	var previous: MissionRuntimeState = state.mission_runtime_state.duplicate_state()
	var changes := TacticalChangeSet.new(
		RECONCILE_REASON,
		state.revision,
		TacticalInvalidationContract.mission_state()
	)
	changes.set_deferred_deduplication_key(&"mission_objective_reconciliation")
	changes.stage(
		func() -> bool:
			return state.set_mission_runtime_state(candidate),
		func() -> void:
			state.mission_runtime_state = previous.duplicate_state(),
		"Mission objective state could not be reconciled.",
		&"mission_objective_reconciliation_failed"
	)
	changes.after_commit(func() -> void: _record_objective_changes(previous, candidate))
	return _state_store.commit_after_notifications(changes, _map_definition)


func _on_state_changed(reason: StringName) -> void:
	if reason == RECONCILE_REASON:
		return
	reconcile_now()


func _evaluate(runtime: MissionRuntimeState, state: TacticalState) -> void:
	var extracted_item_ids: Array[StringName] = []
	var captured_unit_ids: Array[StringName] = []
	var friendly_in_extraction: bool = false
	for zone: TacticalExtractionZoneDefinition in _setup.extraction_zones():
		var manifest := TacticalExtractionManifestQuery.build_manifest(
			state, _map_definition, _setup, zone.zone_id
		)
		for item_id: StringName in manifest.extracted_item_ids:
			if not extracted_item_ids.has(item_id):
				extracted_item_ids.append(item_id)
		for unit_id: StringName in manifest.captured_enemy_unit_ids:
			if not captured_unit_ids.has(unit_id):
				captured_unit_ids.append(unit_id)
		friendly_in_extraction = friendly_in_extraction or not manifest.extracted_friendly_unit_ids.is_empty() or not manifest.extracted_friendly_body_item_ids.is_empty()

	for definition: MissionObjectiveDefinition in _mission_definition.all_objectives():
		var objective_state := runtime.objective(definition.objective_id)
		if objective_state == null:
			continue
		var old_status: StringName = objective_state.status
		objective_state.contributing_entity_ids.clear()
		objective_state.failure_reason = ""
		match definition.objective_kind:
			MissionObjectiveDefinition.KIND_EXTRACT_ITEMS:
				_evaluate_extract_items(definition, objective_state, state, extracted_item_ids)
			MissionObjectiveDefinition.KIND_EXTRACT_CAPTIVE:
				_evaluate_extract_captive(definition, objective_state, captured_unit_ids)
			MissionObjectiveDefinition.KIND_AVOID_CIVILIAN_DEATHS:
				_evaluate_avoid_civilian_deaths(objective_state, state)
			MissionObjectiveDefinition.KIND_EXTRACT_BEFORE_ROUND:
				_evaluate_deadline(definition, objective_state, state, runtime.primary_complete(), friendly_in_extraction)
		if objective_state.status != old_status:
			if objective_state.status == MissionObjectiveState.STATUS_COMPLETED:
				objective_state.completion_revision = state.revision + 1
			elif objective_state.is_failed():
				objective_state.failure_revision = state.revision + 1


func _evaluate_extract_items(
		definition: MissionObjectiveDefinition,
		objective_state: MissionObjectiveState,
		state: TacticalState,
		extracted_item_ids: Array[StringName]
) -> void:
	var obtainable: int = 0
	objective_state.current_quantity = 0
	for item: TacticalItemInstanceState in state.get_items():
		if (
			item == null
			or item.is_body()
			or item.location == null
			or item.location.location_type == TacticalItemLocationState.LOCATION_DESTROYED
			or not definition.matches_item(item)
		):
			continue
		obtainable += item.quantity
		if extracted_item_ids.has(item.item_id):
			objective_state.current_quantity += item.quantity
			objective_state.contributing_entity_ids.append(item.item_id)
	if objective_state.current_quantity >= definition.required_quantity:
		objective_state.status = MissionObjectiveState.STATUS_COMPLETED
	elif obtainable < definition.required_quantity:
		objective_state.status = MissionObjectiveState.STATUS_IMPOSSIBLE
		objective_state.failure_reason = "Too few qualifying items remain obtainable."
	else:
		objective_state.status = MissionObjectiveState.STATUS_ACTIVE


func _evaluate_extract_captive(
		definition: MissionObjectiveDefinition,
		objective_state: MissionObjectiveState,
		captured_unit_ids: Array[StringName]
) -> void:
	for unit_id: StringName in captured_unit_ids:
		var placement := _mission_definition.placement_for_character(unit_id)
		if placement == null:
			continue
		var qualifies: bool = true
		for tag: StringName in definition.qualifying_tags:
			if not placement.has_role_tag(tag):
				qualifies = false
				break
		if qualifies:
			objective_state.contributing_entity_ids.append(unit_id)
	objective_state.current_quantity = objective_state.contributing_entity_ids.size()
	objective_state.status = (
		MissionObjectiveState.STATUS_COMPLETED
		if objective_state.current_quantity >= definition.required_quantity
		else MissionObjectiveState.STATUS_ACTIVE
	)


func _evaluate_avoid_civilian_deaths(
		objective_state: MissionObjectiveState,
		state: TacticalState
) -> void:
	var dead_civilians: Array[StringName] = []
	for placement: MissionCharacterPlacementDefinition in _mission_definition.character_placements:
		if placement == null or not placement.has_role_tag(&"civilian"):
			continue
		var unit := state.get_unit(placement.character_id)
		if unit != null and unit.is_dead():
			dead_civilians.append(unit.unit_id)
	objective_state.current_quantity = dead_civilians.size()
	objective_state.contributing_entity_ids = dead_civilians
	if dead_civilians.is_empty():
		objective_state.status = MissionObjectiveState.STATUS_COMPLETED
	else:
		objective_state.status = MissionObjectiveState.STATUS_FAILED
		objective_state.failure_reason = "%d civilian death(s) recorded." % dead_civilians.size()


func _evaluate_deadline(
		definition: MissionObjectiveDefinition,
		objective_state: MissionObjectiveState,
		state: TacticalState,
		primary_complete: bool,
		friendly_in_extraction: bool
) -> void:
	var round_number: int = state.phase_state.round_number
	objective_state.current_quantity = mini(round_number, definition.deadline_round)
	if round_number > definition.deadline_round:
		objective_state.status = MissionObjectiveState.STATUS_FAILED
		objective_state.failure_reason = "The reinforcement deadline passed."
	elif primary_complete and friendly_in_extraction:
		objective_state.status = MissionObjectiveState.STATUS_COMPLETED
	else:
		objective_state.status = MissionObjectiveState.STATUS_ACTIVE


func _record_objective_changes(
		previous: MissionRuntimeState,
		current: MissionRuntimeState
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	for objective_state: MissionObjectiveState in current.objectives():
		var old_state := previous.objective(objective_state.objective_id)
		if old_state != null and old_state.status == objective_state.status and old_state.current_quantity == objective_state.current_quantity:
			continue
		_event_journal.call(
			"record_event",
			&"mission_objective_updated",
			_state_store.state.phase_state.round_number,
			_state_store.state.phase_state.current_phase,
			"%s — %s." % [objective_state.display_name, String(objective_state.status).capitalize()],
			{
				"category": &"events",
				"details": [
					"Progress: %d/%d" % [objective_state.current_quantity, objective_state.required_quantity],
					objective_state.failure_reason,
				],
			}
		)
