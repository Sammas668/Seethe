class_name TacticalDetectionService
extends RefCounted

const ROLL_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_roll_record.gd"
)
const MODIFIER_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_modifier_record.gd"
)
const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)
const DetectionObserverQuery: Script = preload(
	"res://application/tactical/awareness/detection_observer_query.gd"
)
const DetectionPreviewQuery: Script = preload(
	"res://application/tactical/awareness/detection_preview_query.gd"
)
const ContactInitiativeResolver: Script = preload(
	"res://application/tactical/awareness/contact_initiative_resolver.gd"
)
const DetectionBatchTransactionSupport: Script = preload(
	"res://application/tactical/awareness/detection_batch_transaction_support.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _event_journal: RefCounted
var _dice_roller: TacticalDiceRoller
var _visibility_service: RefCounted
var _observer_query: DetectionObserverQuery
var _preview_query: DetectionPreviewQuery
var _contact_resolver: ContactInitiativeResolver
var _batch_transaction_support: DetectionBatchTransactionSupport
var _perception_recalculation_deferral_depth: int = 0
var _deferred_perception_squad_ids: Dictionary = {}

func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		event_journal_value: RefCounted,
		dice_roller: TacticalDiceRoller,
		visibility_service: RefCounted
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_event_journal = event_journal_value
	_dice_roller = dice_roller
	_visibility_service = visibility_service
	_observer_query = DetectionObserverQuery.new() as DetectionObserverQuery
	_observer_query.configure(
		_state_store,
		_map_definition,
		_visibility_service
	)
	_preview_query = DetectionPreviewQuery.new() as DetectionPreviewQuery
	_preview_query.configure(_state_store, _observer_query)
	_contact_resolver = (
		ContactInitiativeResolver.new() as ContactInitiativeResolver
	)
	_contact_resolver.configure(_state_store, _dice_roller)
	_batch_transaction_support = (
		DetectionBatchTransactionSupport.new()
		as DetectionBatchTransactionSupport
	)
	_batch_transaction_support.configure(_state_store)

func preview_for_path(
		unit_id: StringName,
		path: Array[Vector2i]
) -> MovementDetectionPreview:
	return _preview_query.preview_for_path(unit_id, path)

func prepare_path_resolution(
		unit_id: StringName,
		path: Array[Vector2i]
) -> TacticalDetectionResolution:
	var resolution := TacticalDetectionResolution.new()
	resolution.unit_id = unit_id
	var unit: TacticalUnitState = _unit(unit_id)
	if (
		unit == null
		or unit.team_id not in [&"player", &"enemy"]
		or path.size() <= 1
	):
		return resolution

	resolution.alert_on_detection = unit.team_id == &"player"
	resolution.stealth_bonus = unit.stealth_bonus()
	var actual_stop_index: int = path.size() - 1
	var non_interrupting_reacquired_squad_ids: Array[StringName] = []
	for index: int in range(1, path.size()):
		var tile: Vector2i = path[index]
		var exposures: Array[Dictionary] = _collect_tile_exposures(
			unit,
			tile,
			index
		)
		if not non_interrupting_reacquired_squad_ids.is_empty():
			var unresolved_exposures: Array[Dictionary] = []
			for exposure: Dictionary in exposures:
				var observer: TacticalUnitState = (
					exposure.get("observer") as TacticalUnitState
				)
				if (
					observer != null
					and non_interrupting_reacquired_squad_ids.has(
						observer.squad_id
					)
				):
					continue
				unresolved_exposures.append(exposure)
			exposures = unresolved_exposures
		if exposures.is_empty():
			continue
		var check: TacticalDetectionTileCheck = _resolve_tile_check(
			unit,
			tile,
			index,
			exposures
		)
		resolution.tile_checks.append(check)
		_sync_legacy_check_fields(resolution, check)
		if check.roll_required:
			resolution.persistent_stealth_roll_valid = true
			resolution.persistent_stealth_roll_value = check.roll_value
			resolution.persistent_stealth_total = check.roll_total
		if not check.detected():
			continue
		var detection_interrupts_movement: bool = unit.stealth_enabled
		for observer_id: StringName in check.detected_observer_ids:
			_append_unique(resolution.detected_observer_ids, observer_id)
		for squad_id: StringName in check.detected_squad_ids:
			_append_unique(resolution.detected_squad_ids, squad_id)
			resolution.last_seen_tile_by_squad_id[squad_id] = tile
			var squad: TacticalSquadState = _state_store.state.get_squad(
				squad_id
			)
			var newly_alerting_squad: bool = (
				squad == null or not squad.is_aware()
			)
			detection_interrupts_movement = (
				detection_interrupts_movement or newly_alerting_squad
			)
			if not newly_alerting_squad and not unit.stealth_enabled:
				_append_unique(
					non_interrupting_reacquired_squad_ids,
					squad_id
				)
		if detection_interrupts_movement:
			actual_stop_index = index
			resolution.movement_stop_index = index
			for squad_id: StringName in check.detected_squad_ids:
				_append_unique(
					resolution.revealed_at_destination_squad_ids,
					squad_id
				)
			break

	var actual_path: Array[Vector2i] = _path_through_index(
		path,
		actual_stop_index
	)
	for squad_id: StringName in non_interrupting_reacquired_squad_ids:
		var trace: Dictionary = _trace_squad_perception(
			unit,
			actual_path,
			squad_id,
			true
		)
		if bool(trace.get("seen_any", false)):
			resolution.last_seen_tile_by_squad_id[squad_id] = trace.get(
				"last_seen_tile",
				unit.grid_position
			)
		if bool(trace.get("destination_seen", false)):
			_append_unique(
				resolution.revealed_at_destination_squad_ids,
				squad_id
			)
		else:
			_append_unique(resolution.lost_sight_squad_ids, squad_id)
	_prepare_existing_revelation_changes(unit, actual_path, resolution)
	resolution.stealth_broken = resolution.detected()
	_finalize_alert_resolution(unit, resolution)
	return resolution

func prepare_hostile_action_resolution(
		attacker_id: StringName,
		target_id: StringName
) -> TacticalDetectionResolution:
	var resolution := TacticalDetectionResolution.new()
	resolution.unit_id = attacker_id
	resolution.hostile_action = true
	var attacker: TacticalUnitState = _unit(attacker_id)
	var target: TacticalUnitState = _unit(target_id)
	if attacker == null or target == null:
		return resolution
	if not TEAM_RELATIONS_SCRIPT.are_hostile(attacker.team_id, target.team_id):
		return resolution
	if target.squad_id.is_empty():
		return resolution
	resolution.alert_on_detection = (
		attacker.team_id == &"player" and target.team_id == &"enemy"
	)
	resolution.automatic_detection = true
	resolution.stealth_broken = true
	resolution.detected_observer_ids.append(target.unit_id)
	resolution.detected_squad_ids.append(target.squad_id)
	resolution.revealed_at_destination_squad_ids.append(target.squad_id)
	resolution.last_seen_tile_by_squad_id[target.squad_id] = attacker.grid_position
	_finalize_alert_resolution(attacker, resolution)
	return resolution

func can_enter_stealth(unit_id: StringName) -> bool:
	var unit: TacticalUnitState = _unit(unit_id)
	if unit == null or unit.team_id != &"player" or unit.is_defeated():
		return false
	return perceiving_enemy_squad_ids(unit_id).is_empty()

func perceiving_enemy_squad_ids(unit_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var unit: TacticalUnitState = _unit(unit_id)
	if unit == null:
		return result
	for squad: TacticalSquadState in _state_store.state.get_squads():
		if squad.team_id != &"enemy":
			continue
		if is_unit_currently_perceived_by_squad(unit_id, squad.squad_id):
			result.append(squad.squad_id)
	result.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	return result

func is_unit_currently_perceived_by_squad(
		unit_id: StringName,
		squad_id: StringName
) -> bool:
	var unit: TacticalUnitState = _unit(unit_id)
	if unit == null:
		return false
	return not _perceiving_observers_for_squad(
		unit,
		squad_id,
		unit.grid_position
	).is_empty()

func perception_tiles_for_observer(
		observer_id: StringName,
		facing_override: Vector2i = Vector2i.ZERO
) -> Dictionary:
	return _observer_query.perception_tiles_for_observer(
		observer_id,
		facing_override
	)

func perception_performance_snapshot() -> Dictionary:
	return _observer_query.performance_snapshot()

func snapshot_for_resolution(resolution: TacticalDetectionResolution) -> Dictionary:
	var snapshot: Dictionary = {
		"phase": _state_store.state.phase_state.snapshot(),
		"unit_id": resolution.unit_id,
		"stealth_enabled": false,
		"stealth_roll_valid": false,
		"stealth_roll_value": 0,
		"stealth_total": 0,
		"revealed": [],
		"squads": {},
		"budgets": [],
	}
	var unit: TacticalUnitState = _unit(resolution.unit_id)
	if unit != null:
		snapshot["stealth_enabled"] = unit.stealth_enabled
		snapshot["stealth_roll_valid"] = unit.current_stealth_roll_valid
		snapshot["stealth_roll_value"] = unit.current_stealth_roll_value
		snapshot["stealth_total"] = unit.current_stealth_total
		snapshot["revealed"] = unit.revealed_to_squad_ids.duplicate()
	var squad_snapshots: Dictionary = {}
	for squad: TacticalSquadState in _state_store.state.get_squads():
		squad_snapshots[squad.squad_id] = {
			"awareness": squad.awareness,
			"last_seen": squad.last_seen_positions_by_unit_id.duplicate(true),
			"search_rounds": squad.search_rounds_remaining,
		}
	snapshot["squads"] = squad_snapshots
	var budget_snapshots: Array[Dictionary] = []
	for participant_id: Variant in resolution.initiative_totals_by_unit_id.keys():
		var participant: TacticalUnitState = _unit(StringName(participant_id))
		if participant != null:
			budget_snapshots.append(_budget_snapshot(participant))
	snapshot["budgets"] = budget_snapshots
	return snapshot


func apply_resolution(resolution: TacticalDetectionResolution) -> bool:
	if resolution == null or not resolution.has_state_changes():
		return true
	var unit: TacticalUnitState = _unit(resolution.unit_id)
	if unit == null:
		return false
	if resolution.stealth_broken:
		unit.leave_stealth()
	elif resolution.persistent_stealth_roll_valid:
		unit.set_current_stealth_roll(
			resolution.persistent_stealth_roll_value,
			resolution.persistent_stealth_total
		)

	if resolution.alert_on_detection:
		for squad_id: StringName in resolution.detected_squad_ids:
			var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
			if squad != null and squad.team_id == &"enemy":
				squad.make_aware()

	for squad_value: Variant in resolution.last_seen_tile_by_squad_id.keys():
		var squad_id := StringName(squad_value)
		var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
		var tile_value: Variant = resolution.last_seen_tile_by_squad_id[squad_value]
		if squad != null and tile_value is Vector2i:
			squad.remember_last_seen(unit.unit_id, Vector2i(tile_value))

	for squad_id: StringName in resolution.lost_sight_squad_ids:
		unit.conceal_from_squad(squad_id)
		var searching_squad: TacticalSquadState = (
			_state_store.state.get_squad(squad_id)
		)
		if searching_squad != null and searching_squad.team_id == &"enemy":
			searching_squad.begin_search()
	for squad_id: StringName in resolution.revealed_at_destination_squad_ids:
		unit.reveal_to_squad(squad_id)
		var reacquiring_squad: TacticalSquadState = (
			_state_store.state.get_squad(squad_id)
		)
		if reacquiring_squad != null:
			reacquiring_squad.cancel_search()

	if not resolution.detected() or not resolution.alert_on_detection:
		return true
	var participant_ids: Array[StringName] = []
	for participant_value: Variant in resolution.initiative_totals_by_unit_id.keys():
		participant_ids.append(StringName(participant_value))
	if participant_ids.is_empty():
		return true
	if _state_store.state.phase_state.is_side_based():
		return _state_store.state.begin_initiative_combat(
			participant_ids,
			resolution.initiative_totals_by_unit_id
		)
	_state_store.state.append_initiative_participants(
		participant_ids,
		resolution.initiative_totals_by_unit_id
	)
	return true


func restore_resolution_snapshot(snapshot: Dictionary) -> void:
	var phase_snapshot: Dictionary = snapshot.get("phase", {})
	_state_store.state.phase_state.restore(phase_snapshot)
	var unit: TacticalUnitState = _unit(StringName(snapshot.get("unit_id", &"")))
	if unit != null:
		unit.stealth_enabled = bool(snapshot.get("stealth_enabled", false))
		unit.current_stealth_roll_valid = bool(
			snapshot.get("stealth_roll_valid", false)
		)
		unit.current_stealth_roll_value = int(
			snapshot.get("stealth_roll_value", 0)
		)
		unit.current_stealth_total = int(snapshot.get("stealth_total", 0))
		unit.revealed_to_squad_ids.clear()
		for squad_value: Variant in snapshot.get("revealed", []):
			unit.revealed_to_squad_ids.append(StringName(squad_value))
	var squad_snapshots: Dictionary = snapshot.get("squads", {})
	for squad_value: Variant in squad_snapshots.keys():
		var squad: TacticalSquadState = _state_store.state.get_squad(
			StringName(squad_value)
		)
		var squad_snapshot_value: Variant = squad_snapshots[squad_value]
		if squad == null or not (squad_snapshot_value is Dictionary):
			continue
		var squad_snapshot: Dictionary = squad_snapshot_value
		squad.awareness = StringName(
			squad_snapshot.get(
				"awareness",
				TacticalSquadState.AWARENESS_UNAWARE
			)
		)
		var last_seen_value: Variant = squad_snapshot.get("last_seen", {})
		squad.last_seen_positions_by_unit_id = (
			last_seen_value.duplicate(true)
			if last_seen_value is Dictionary
			else {}
		)
		squad.search_rounds_remaining = maxi(0, int(
			squad_snapshot.get("search_rounds", 0)
		))
	for budget_value: Variant in snapshot.get("budgets", []):
		if budget_value is Dictionary:
			_restore_budget_snapshot(budget_value)


func record_resolution(resolution: TacticalDetectionResolution) -> void:
	if resolution == null:
		return
	var unit: TacticalUnitState = _unit(resolution.unit_id)
	if unit == null:
		return

	for check: TacticalDetectionTileCheck in resolution.tile_checks:
		# Do not leak an unseen enemy merely because it passed a passive
		# Perception comparison. The player sees the detailed roll only when that
		# hidden enemy is actually detected.
		if unit.team_id == &"enemy" and not check.detected():
			continue
		_record_tile_check_event(unit, check, resolution)

	if resolution.hostile_action and resolution.tile_checks.is_empty():
		_record_event(
			&"detection",
			"%s was revealed by a hostile action." % unit.display_name,
			{
				"category": &"events",
				"source_actor_id": unit.unit_id,
				"details": _awareness_change_details(resolution),
			}
		)

	if not resolution.lost_sight_squad_ids.is_empty():
		var labels: Array[String] = []
		for squad_id: StringName in resolution.lost_sight_squad_ids:
			labels.append(String(squad_id))
		_record_event(
			&"sight_lost",
			"%s left the observing squad's perception." % unit.display_name,
			{
				"category": &"events",
				"source_actor_id": unit.unit_id,
				"details": [
					"Searching squads: %s" % ", ".join(PackedStringArray(labels)),
				],
			}
		)


func begin_perception_recalculation_deferral() -> void:
	_perception_recalculation_deferral_depth += 1


func request_current_perception_for_squad(
		squad_id: StringName
) -> OperationResult:
	if squad_id.is_empty():
		return OperationResult.ok(false, "No squad perception refresh was required.")
	_deferred_perception_squad_ids[squad_id] = true
	return OperationResult.ok(
		true,
		"Perception refresh queued after the committed action."
	)


func flush_requested_perception_refreshes() -> OperationResult:
	if _perception_recalculation_deferral_depth > 0:
		return OperationResult.ok(false, "Perception refresh remains deferred.")
	var squad_ids: Array[StringName] = []
	for squad_id_value: Variant in _deferred_perception_squad_ids.keys():
		squad_ids.append(StringName(squad_id_value))
	_deferred_perception_squad_ids.clear()
	squad_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	var warnings: Array[StringName] = []
	var warning_messages: Array[String] = []
	var changed: bool = false
	for squad_id: StringName in squad_ids:
		var result: OperationResult = resolve_current_perception_for_squad(squad_id)
		if not result.success:
			warnings.append(result.code)
			warning_messages.append(result.message)
			continue
		changed = changed or bool(result.data)
	if not warnings.is_empty():
		return OperationResult.committed_with_warning(
			changed,
			"Committed action remains valid; perception repair is required: "
			+ " | ".join(PackedStringArray(warning_messages)),
			_state_store.state.revision,
			warnings
		)
	return OperationResult.committed(
		changed,
		"Queued perception refreshes completed.",
		_state_store.state.revision
	)


func end_perception_recalculation_deferral() -> void:
	_perception_recalculation_deferral_depth = maxi(
		0,
		_perception_recalculation_deferral_depth - 1
	)
	if _perception_recalculation_deferral_depth > 0:
		return
	var result: OperationResult = flush_requested_perception_refreshes()
	if result.commit_status == OperationResult.STATUS_COMMITTED_WITH_WARNING:
		push_warning(result.message)


func resolve_current_perception_for_squad(
		squad_id: StringName
) -> OperationResult:
	if _perception_recalculation_deferral_depth > 0:
		_deferred_perception_squad_ids[squad_id] = true
		return OperationResult.ok(
			false,
			"Perception refresh deferred until movement presentation completes."
		)
	var squad: TacticalSquadState = _state_store.state.get_squad(squad_id)
	if squad == null:
		return OperationResult.fail(
			&"unknown_squad",
			"The observing squad does not exist."
		)
	var dice_snapshot: Dictionary = _dice_roller.snapshot_state()
	var resolutions: Array[TacticalDetectionResolution] = []
	for unit: TacticalUnitState in _hostile_units_for_squad(squad):
		if unit.is_defeated():
			continue
		var resolution: TacticalDetectionResolution = (
			_prepare_current_position_resolution(unit, squad_id, false)
		)
		if not resolution.has_state_changes() and not resolution.has_check():
			continue
		resolutions.append(resolution)
	if resolutions.is_empty():
		return OperationResult.ok(false, "No perception state changed.")

	_contact_resolver.finalize_batch(resolutions)
	var snapshot: Dictionary = (
		_batch_transaction_support.snapshot_for_resolutions(resolutions)
	)
	var changes := TacticalChangeSet.new(
		&"current_perception_resolved",
		_state_store.state.revision
	)
	changes.stage(
		Callable(self, "apply_resolution_batch").bind(resolutions),
		Callable(_batch_transaction_support, "restore_snapshot").bind(snapshot),
		"Current squad perception could not be committed atomically.",
		&"current_perception_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(
		changes,
		_map_definition
	)
	if not committed.success:
		_dice_roller.restore_state(dice_snapshot)
		return committed
	var changed: bool = false
	for resolution: TacticalDetectionResolution in resolutions:
		record_resolution(resolution)
		changed = changed or resolution.has_state_changes()
	return OperationResult.ok(
		changed,
		"Perception refreshed." if changed else "No perception state changed."
	)


func apply_resolution_batch(
		resolutions: Array[TacticalDetectionResolution]
) -> bool:
	for resolution: TacticalDetectionResolution in resolutions:
		if not apply_resolution(resolution):
			return false
	return true


func _prepare_existing_revelation_changes(
		unit: TacticalUnitState,
		path: Array[Vector2i],
		resolution: TacticalDetectionResolution
) -> void:
	for squad_id: StringName in unit.revealed_to_squad_ids.duplicate():
		var trace: Dictionary = _trace_squad_perception(unit, path, squad_id)
		if bool(trace.get("seen_any", false)):
			resolution.last_seen_tile_by_squad_id[squad_id] = trace.get(
				"last_seen_tile",
				unit.grid_position
			)
		if bool(trace.get("destination_seen", false)):
			_append_unique(
				resolution.revealed_at_destination_squad_ids,
				squad_id
			)
		else:
			_append_unique(resolution.lost_sight_squad_ids, squad_id)


func _prepare_current_position_resolution(
		unit: TacticalUnitState,
		squad_id: StringName,
		finalize_contact: bool = true
) -> TacticalDetectionResolution:
	var resolution := TacticalDetectionResolution.new()
	resolution.unit_id = unit.unit_id
	resolution.alert_on_detection = (
		unit.team_id == &"player" and squad_id != TacticalSquadState.PLAYER_TEAM_SQUAD_ID
	)
	resolution.stealth_bonus = unit.stealth_bonus()
	var observers: Array[TacticalUnitState] = _perceiving_observers_for_squad(
		unit,
		squad_id,
		unit.grid_position
	)
	if observers.is_empty():
		if unit.is_revealed_to_squad(squad_id):
			resolution.lost_sight_squad_ids.append(squad_id)
		return resolution

	if unit.is_revealed_to_squad(squad_id):
		resolution.last_seen_tile_by_squad_id[squad_id] = unit.grid_position
		resolution.revealed_at_destination_squad_ids.append(squad_id)
		return resolution

	var exposures: Array[Dictionary] = []
	for observer: TacticalUnitState in observers:
		exposures.append({
			"observer": observer,
			"dc": TacticalPerceptionRules.detection_dc(
				observer,
				unit.grid_position
			),
			"automatic": not unit.stealth_enabled,
			"path_index": 0,
			"tile": unit.grid_position,
		})
	var check: TacticalDetectionTileCheck
	if unit.stealth_enabled and unit.current_stealth_roll_valid:
		check = _resolve_tile_check_with_existing_roll(
			unit,
			unit.grid_position,
			0,
			exposures,
			unit.current_stealth_roll_value,
			unit.current_stealth_total
		)
	else:
		check = _resolve_tile_check(
			unit,
			unit.grid_position,
			0,
			exposures
		)
	resolution.tile_checks.append(check)
	_sync_legacy_check_fields(resolution, check)
	if check.roll_required:
		resolution.persistent_stealth_roll_valid = true
		resolution.persistent_stealth_roll_value = check.roll_value
		resolution.persistent_stealth_total = check.roll_total
	if not check.detected():
		return resolution
	for observer_id: StringName in check.detected_observer_ids:
		_append_unique(resolution.detected_observer_ids, observer_id)
	for detected_squad_id: StringName in check.detected_squad_ids:
		_append_unique(resolution.detected_squad_ids, detected_squad_id)
		resolution.last_seen_tile_by_squad_id[detected_squad_id] = (
			unit.grid_position
		)
		_append_unique(
			resolution.revealed_at_destination_squad_ids,
			detected_squad_id
		)
	resolution.stealth_broken = true
	if finalize_contact:
		_finalize_alert_resolution(unit, resolution)
	return resolution


func _collect_tile_exposures(
		unit: TacticalUnitState,
		tile: Vector2i,
		path_index: int
) -> Array[Dictionary]:
	return _observer_query.collect_tile_exposures(unit, tile, path_index)


func _resolve_tile_check(
		unit: TacticalUnitState,
		tile: Vector2i,
		path_index: int,
		exposures: Array[Dictionary]
) -> TacticalDetectionTileCheck:
	var check := TacticalDetectionTileCheck.new()
	check.tile = tile
	check.path_index = path_index
	check.stealth_bonus = unit.stealth_bonus()
	for exposure: Dictionary in exposures:
		var observer: TacticalUnitState = exposure.get("observer") as TacticalUnitState
		if observer == null or observer.squad_id.is_empty():
			continue
		check.observer_dc_by_id[observer.unit_id] = int(exposure.get("dc", 1))
		check.observer_squad_by_id[observer.unit_id] = observer.squad_id
		check.automatic_detection = (
			check.automatic_detection
			or bool(exposure.get("automatic", false))
		)
	check.roll_required = not check.automatic_detection
	if check.roll_required:
		check.roll_value = _dice_roller.roll_die(20)
		check.roll_total = check.roll_value + check.stealth_bonus
	for observer_value: Variant in check.observer_dc_by_id.keys():
		var observer_id := StringName(observer_value)
		var detected: bool = check.automatic_detection
		if not detected:
			detected = (
				check.roll_total
				< int(check.observer_dc_by_id[observer_id])
			)
		if not detected:
			continue
		_append_unique(check.detected_observer_ids, observer_id)
		var squad_id := StringName(
			check.observer_squad_by_id.get(observer_id, &"")
		)
		_append_unique(check.detected_squad_ids, squad_id)
	return check


func _resolve_tile_check_with_existing_roll(
		unit: TacticalUnitState,
		tile: Vector2i,
		path_index: int,
		exposures: Array[Dictionary],
		raw_roll: int,
		roll_total: int
) -> TacticalDetectionTileCheck:
	var check := TacticalDetectionTileCheck.new()
	check.tile = tile
	check.path_index = path_index
	check.stealth_bonus = unit.stealth_bonus()
	for exposure: Dictionary in exposures:
		var observer: TacticalUnitState = exposure.get("observer") as TacticalUnitState
		if observer == null or observer.squad_id.is_empty():
			continue
		check.observer_dc_by_id[observer.unit_id] = int(exposure.get("dc", 1))
		check.observer_squad_by_id[observer.unit_id] = observer.squad_id
		check.automatic_detection = (
			check.automatic_detection
			or bool(exposure.get("automatic", false))
		)
	check.roll_required = not check.automatic_detection
	if check.roll_required:
		check.roll_value = raw_roll
		check.roll_total = roll_total
	for observer_value: Variant in check.observer_dc_by_id.keys():
		var observer_id := StringName(observer_value)
		var detected: bool = check.automatic_detection
		if not detected:
			detected = check.roll_total < int(check.observer_dc_by_id[observer_id])
		if not detected:
			continue
		_append_unique(check.detected_observer_ids, observer_id)
		_append_unique(
			check.detected_squad_ids,
			StringName(check.observer_squad_by_id.get(observer_id, &""))
		)
	return check


func _sync_legacy_check_fields(
		resolution: TacticalDetectionResolution,
		check: TacticalDetectionTileCheck
) -> void:
	resolution.automatic_detection = check.automatic_detection
	resolution.roll_required = check.roll_required
	resolution.roll_value = check.roll_value
	resolution.roll_total = check.roll_total
	resolution.observer_dc_by_id = check.observer_dc_by_id.duplicate(true)
	resolution.observer_squad_by_id = (
		check.observer_squad_by_id.duplicate(true)
	)
	if resolution.first_exposure_tile == Vector2i(-1, -1):
		resolution.first_exposure_tile = check.tile


func _path_through_index(
		path: Array[Vector2i],
		last_index: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var clamped_index: int = clampi(last_index, 0, path.size() - 1)
	for index: int in range(0, clamped_index + 1):
		result.append(path[index])
	return result


func _record_tile_check_event(
		unit: TacticalUnitState,
		check: TacticalDetectionTileCheck,
		resolution: TacticalDetectionResolution
) -> void:
	var details: Array[String] = [
		"Tile: (%d, %d)" % [check.tile.x, check.tile.y],
	]
	var roll_records: Array = []
	if check.automatic_detection:
		details.append("The unit was not in Stealth: avoidance chance 0%.")
	else:
		details.append("Raw d20: %d" % check.roll_value)
		details.append("Stealth modifier: %+d" % check.stealth_bonus)
		details.append("Final total: %d" % check.roll_total)
		details.append(
			"One shared Stealth roll was compared with every observer on this tile."
		)

	var observer_ids: Array[StringName] = []
	for observer_value: Variant in check.observer_dc_by_id.keys():
		observer_ids.append(StringName(observer_value))
	observer_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	for observer_id: StringName in observer_ids:
		var observer: TacticalUnitState = _unit(observer_id)
		var observer_label: String = (
			observer.display_name if observer != null else String(observer_id)
		)
		var dc: int = int(check.observer_dc_by_id.get(observer_id, 1))
		var failed: bool = check.detected_observer_ids.has(observer_id)
		if check.automatic_detection:
			details.append(
				"%s — DC %d — automatic detection outside Stealth."
				% [observer_label, dc]
			)
			continue
		details.append(
			"%s — DC %d — required natural roll %s — %s"
			% [
				observer_label,
				dc,
				check.required_roll_label(dc),
				"FAIL" if failed else "PASS",
			]
		)
		roll_records.append(
			ROLL_RECORD_SCRIPT.create(
				&"stealth_check",
				"d20",
				[check.roll_value],
				check.roll_total,
				dc,
				&"fail" if failed else &"pass",
				[
					MODIFIER_RECORD_SCRIPT.create(
						"Stealth modifier",
						check.stealth_bonus,
						&"stealth",
						&"character_stat"
					),
				]
			)
		)

	var interrupted_on_this_tile: bool = (
		resolution.movement_interrupted()
		and check.path_index == resolution.movement_stop_index
	)
	if check.detected():
		if interrupted_on_this_tile:
			details.append("Movement interrupted on this tile.")
		elif check.automatic_detection:
			details.append(
				"An already-aware squad reacquired the visible unit without interrupting movement."
			)
		else:
			details.append("Passive perception revealed the hidden unit on this tile.")
		details.append_array(_awareness_change_details(resolution))
	else:
		details.append("The unit remains hidden.")

	var summary: String
	if check.automatic_detection:
		summary = "%s entered (%d, %d) outside Stealth — Detected." % [
			unit.display_name,
			check.tile.x,
			check.tile.y,
		]
	else:
		var result_label: String = "Detected" if check.detected() else "Hidden"
		summary = "%s Stealth at (%d, %d): %d + %+d = %d — %s." % [
			unit.display_name,
			check.tile.x,
			check.tile.y,
			check.roll_value,
			check.stealth_bonus,
			check.roll_total,
			result_label,
		]
		if unit.team_id == &"enemy" and check.detected():
			summary = "PERCEPTION — %s revealed: Stealth %d + %+d = %d." % [
				unit.display_name,
				check.roll_value,
				check.stealth_bonus,
				check.roll_total,
			]
	_record_event(
		&"stealth_check",
		summary,
		{
			"category": &"rolls",
			"source_actor_id": unit.unit_id,
			"action_id": &"action.move",
			"details": details,
			"roll_records": roll_records,
			"metadata": {
				"tile": check.tile,
				"path_index": check.path_index,
				"movement_interrupted": interrupted_on_this_tile,
			},
		}
	)


func _awareness_change_details(
		resolution: TacticalDetectionResolution
) -> Array[String]:
	var details: Array[String] = []
	for squad_id: StringName in resolution.newly_aware_squad_ids:
		details.append("%s becomes Aware." % String(squad_id))
	for squad_value: Variant in resolution.last_seen_tile_by_squad_id.keys():
		var tile_value: Variant = resolution.last_seen_tile_by_squad_id[squad_value]
		if tile_value is Vector2i:
			var tile := Vector2i(tile_value)
			details.append(
				"%s last saw the target at (%d, %d)."
				% [String(squad_value), tile.x, tile.y]
			)
	return details


func _trace_squad_perception(
		unit: TacticalUnitState,
		path: Array[Vector2i],
		squad_id: StringName,
		assume_revealed: bool = false
) -> Dictionary:
	var seen_any: bool = false
	var last_seen_tile: Vector2i = Vector2i(-1, -1)
	var last_seen_index: int = -1
	var destination_seen: bool = false
	for index: int in range(path.size()):
		var tile: Vector2i = path[index]
		var observers: Array[TacticalUnitState] = _perceiving_observers_for_squad(
			unit,
			squad_id,
			tile,
			assume_revealed
		)
		if observers.is_empty():
			continue
		seen_any = true
		last_seen_tile = tile
		last_seen_index = index
		destination_seen = index == path.size() - 1
	return {
		"seen_any": seen_any,
		"last_seen_tile": last_seen_tile,
		"last_seen_index": last_seen_index,
		"destination_seen": destination_seen,
	}


func _perceiving_observers_for_squad(
		unit: TacticalUnitState,
		squad_id: StringName,
		tile: Vector2i,
		assume_revealed: bool = false
) -> Array[TacticalUnitState]:
	return _observer_query.perceiving_observers_for_squad(
		unit,
		squad_id,
		tile,
		assume_revealed
	)


func _finalize_alert_resolution(
		unit: TacticalUnitState,
		resolution: TacticalDetectionResolution
) -> void:
	_contact_resolver.finalize_resolution(unit, resolution)


func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)


func _hostile_units_for_squad(
		squad: TacticalSquadState
) -> Array[TacticalUnitState]:
	var result: Array[TacticalUnitState] = []
	if squad == null:
		return result
	for unit: TacticalUnitState in _state_store.state.get_units():
		if (
			unit != null
			and not unit.is_defeated()
			and TEAM_RELATIONS_SCRIPT.are_hostile(squad.team_id, unit.team_id)
		):
			result.append(unit)
	return result


func _unit(unit_id: StringName) -> TacticalUnitState:
	if _state_store == null or _state_store.state == null:
		return null
	return _state_store.state.get_unit(unit_id)


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"unit_id": unit.unit_id,
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
		"diagonal": unit.diagonal_steps_used,
	}


func _restore_budget_snapshot(snapshot: Dictionary) -> void:
	var unit: TacticalUnitState = _unit(StringName(snapshot.get("unit_id", &"")))
	if unit == null:
		return
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot.get("remaining", 0))
	unit.action_budget.normal_capacity_spent_feet = int(snapshot.get("spent", 0))
	unit.action_budget.quick_action_available = bool(snapshot.get("quick", false))
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
	unit.action_budget.ordinary_attack_available = bool(
		snapshot.get("ordinary_attack", false)
	)
	unit.action_budget.ended_activation = bool(snapshot.get("ended", false))
	unit.diagonal_steps_used = int(snapshot.get("diagonal", 0))


func _record_event(
		event_type: StringName,
		summary: String,
		options: Dictionary
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
		options
	)
