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
signal state_changed_with_flags(reason: StringName, flags: TacticalInvalidationFlags)
signal damage_committed(event: Dictionary)
signal movement_committed(event: Dictionary)
signal reaction_decision_requested(request: ReactionDecisionRequest)
signal reaction_decision_cleared(request_id: StringName)

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
var _visibility_service: RefCounted
var _detection_service: TacticalDetectionService
var _stealth_handler: StealthHandler
var _initiative_handler: InitiativeTurnHandler
var _facing_handler: FacingHandler
var _life_state_handler
var _body_action_handler: TacticalBodyActionHandler
var _mission_setup: MissionSetupSnapshot
var _mission_resolution_handler: ResolveTacticalMissionHandler
var _opening_handler: TacticalOpeningHandler
var _structure_attack_handler: TacticalStructureAttackHandler
var _geometry_cache: TacticalGeometryCacheService
var _reaction_service: TacticalReactionService


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
		enemy_turn_handler: RefCounted = null,
		visibility_service: RefCounted = null,
		detection_service: TacticalDetectionService = null,
		stealth_handler: StealthHandler = null,
		initiative_handler: InitiativeTurnHandler = null,
		facing_handler: FacingHandler = null,
		life_state_handler = null,
		body_action_handler: TacticalBodyActionHandler = null,
		mission_setup: MissionSetupSnapshot = null,
		mission_resolution_handler: ResolveTacticalMissionHandler = null,
		opening_handler: TacticalOpeningHandler = null,
		structure_attack_handler: TacticalStructureAttackHandler = null,
		geometry_cache: TacticalGeometryCacheService = null,
		reaction_service: TacticalReactionService = null
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
	_visibility_service = visibility_service
	_detection_service = detection_service
	_stealth_handler = stealth_handler
	_initiative_handler = initiative_handler
	_facing_handler = facing_handler
	_life_state_handler = life_state_handler
	_body_action_handler = body_action_handler
	_mission_setup = mission_setup
	_mission_resolution_handler = mission_resolution_handler
	_opening_handler = opening_handler
	_structure_attack_handler = structure_attack_handler
	_geometry_cache = geometry_cache
	_reaction_service = reaction_service
	_movement_query = MOVEMENT_PREVIEW_QUERY_SCRIPT.new()
	_movement_query.configure(
		_state_store,
		_map_definition,
		_sprint_handler
	)
	_action_query = ACTION_AVAILABILITY_QUERY_SCRIPT.new()
	_action_query.configure(_state_store, _catalogue)
	_state_store.state_changed.connect(_on_state_changed)
	_state_store.state_changed_with_flags.connect(_on_state_changed_with_flags)
	if _attack_handler != null and _attack_handler.has_signal("damage_committed"):
		var damage_callback := Callable(self, "_on_damage_committed")
		if not _attack_handler.is_connected("damage_committed", damage_callback):
			_attack_handler.connect("damage_committed", damage_callback)
	if _enemy_turn_handler != null and _enemy_turn_handler.has_signal("movement_committed"):
		var movement_callback := Callable(self, "_on_movement_committed")
		if not _enemy_turn_handler.is_connected("movement_committed", movement_callback):
			_enemy_turn_handler.connect("movement_committed", movement_callback)
	if _reaction_service != null:
		var request_callback := Callable(self, "_on_reaction_decision_requested")
		if not _reaction_service.reaction_decision_requested.is_connected(request_callback):
			_reaction_service.reaction_decision_requested.connect(request_callback)
		var cleared_callback := Callable(self, "_on_reaction_decision_cleared")
		if not _reaction_service.reaction_decision_cleared.is_connected(cleared_callback):
			_reaction_service.reaction_decision_cleared.connect(cleared_callback)


func _on_state_changed(reason: StringName) -> void:
	state_changed.emit(reason)


func _on_state_changed_with_flags(
		reason: StringName,
		flags: TacticalInvalidationFlags
) -> void:
	state_changed_with_flags.emit(reason, flags)


func _on_damage_committed(event: Dictionary) -> void:
	damage_committed.emit(event)


func _on_movement_committed(event: Dictionary) -> void:
	movement_committed.emit(event)


func _on_reaction_decision_requested(request: ReactionDecisionRequest) -> void:
	reaction_decision_requested.emit(request)


func _on_reaction_decision_cleared(request_id: StringName) -> void:
	reaction_decision_cleared.emit(request_id)


func state() -> TacticalState:
	return _state_store.state


func map_definition() -> TacticalMapDefinition:
	return _map_definition


func player_unit_order() -> Array[StringName]:
	return _player_unit_order.duplicate()


func mission_setup() -> MissionSetupSnapshot:
	return _mission_setup


func mission_display_name() -> String:
	return (
		_mission_setup.mission_display_name
		if _mission_setup != null
		else "Tactical Mission"
	)


func primary_objective_text() -> String:
	return (
		_mission_setup.primary_objective_text
		if _mission_setup != null
		else "Complete the mission objective."
	)


func required_objective_complete() -> bool:
	return TacticalMissionObjectiveQuery.required_objective_complete(
		state(), _map_definition
	)


func area_secured() -> bool:
	return TacticalMissionObjectiveQuery.area_secured(state())


func player_force_can_continue() -> bool:
	return TacticalMissionObjectiveQuery.player_force_can_continue(state())


func extraction_zone_definitions() -> Array[TacticalExtractionZoneDefinition]:
	var result: Array[TacticalExtractionZoneDefinition] = []
	if _mission_setup == null:
		return result
	return _mission_setup.extraction_zones()


func extraction_zone_state(
		zone_id: StringName
) -> TacticalExtractionZoneState:
	return state().extraction_zone_state(zone_id)


func default_extraction_zone_id() -> StringName:
	var zones: Array[TacticalExtractionZoneDefinition] = extraction_zone_definitions()
	return zones[0].zone_id if not zones.is_empty() else &""


func preview_extraction_manifest(
		zone_id: StringName = &""
) -> TacticalExtractionManifest:
	if _mission_resolution_handler == null:
		var unavailable := TacticalExtractionManifest.new()
		unavailable.rejection_reasons.append("Mission resolution is unavailable.")
		return unavailable
	var resolved_zone_id: StringName = (
		zone_id if not zone_id.is_empty() else default_extraction_zone_id()
	)
	return _mission_resolution_handler.preview_manifest(resolved_zone_id)


func resolve_tactical_mission(
		zone_id: StringName = &"",
		expected_tactical_revision: int = -1
) -> OperationResult:
	if _mission_resolution_handler == null:
		return OperationResult.fail(
			&"mission_resolution_unavailable",
			"Mission resolution is unavailable."
		)
	var resolved_zone_id: StringName = (
		zone_id if not zone_id.is_empty() else default_extraction_zone_id()
	)
	return _mission_resolution_handler.resolve(
		resolved_zone_id, expected_tactical_revision
	)


func current_campaign() -> CampaignState:
	if _mission_resolution_handler == null:
		return null
	return _mission_resolution_handler.current_campaign()


func mission_resolution_locked() -> bool:
	return state().mission_resolution_locked


func event_journal() -> RefCounted:
	return _event_journal


func is_tile_visible_to_player(tile: Vector2i) -> bool:
	return is_tile_visible_to_team(&"player", tile)


func is_tile_explored_by_player(tile: Vector2i) -> bool:
	return is_tile_explored_by_team(&"player", tile)


func is_tile_visible_to_team(team_id: StringName, tile: Vector2i) -> bool:
	return (
		_visibility_service != null
		and bool(
			_visibility_service.call("is_tile_visible", team_id, tile)
		)
	)


func is_tile_explored_by_team(team_id: StringName, tile: Vector2i) -> bool:
	return (
		_visibility_service != null
		and bool(
			_visibility_service.call("is_tile_explored", team_id, tile)
		)
	)


func is_unit_visible_to_player(unit_id: StringName) -> bool:
	var unit: TacticalUnitState = state().get_unit(unit_id)
	if unit == null:
		return false
	if unit.team_id == &"player":
		return true
	return (
		_visibility_service != null
		and bool(
			_visibility_service.call(
				"is_unit_visible_to_team",
				&"player",
				unit
			)
		)
	)


func visible_unit_at_tile(
	tile: Vector2i,
	except_unit_id: StringName = &""
) -> TacticalUnitState:
	var unit: TacticalUnitState = state().get_unit_at_tile(
		tile,
		except_unit_id
	)
	if unit == null:
		return null
	return unit if is_unit_visible_to_player(unit.unit_id) else null


func visible_tile_count_for_player() -> int:
	return (
		int(_visibility_service.call("visible_tile_count", &"player"))
		if _visibility_service != null
		else 0
	)


func explored_tile_count_for_player() -> int:
	return (
		int(_visibility_service.call("explored_tile_count", &"player"))
		if _visibility_service != null
		else 0
	)


func first_aid_unavailable_reason(
		actor_id: StringName,
		target_id: StringName
) -> String:
	if _life_state_handler == null:
		return "First Aid is unavailable."
	return _life_state_handler.first_aid_unavailable_reason(
		actor_id,
		target_id
	)


func first_aid(
		actor_id: StringName,
		target_id: StringName
) -> OperationResult:
	if _life_state_handler == null:
		return OperationResult.fail(
			&"life_state_handler_missing",
			"First Aid is unavailable."
		)
	return _life_state_handler.first_aid(actor_id, target_id)


func apply_healing(
		target_id: StringName,
		amount: int,
		source_id: StringName = &""
) -> OperationResult:
	if _life_state_handler == null:
		return OperationResult.fail(
			&"life_state_handler_missing",
			"Healing is unavailable."
		)
	return _life_state_handler.apply_healing(target_id, amount, source_id)


func body_action_unavailable_reason(
		actor_id: StringName,
		body_item_id: StringName,
		action_id: StringName
) -> String:
	if _body_action_handler == null:
		return "Body actions are unavailable."
	return _body_action_handler.unavailable_reason(
		actor_id, body_item_id, action_id
	)


func body_administer_first_aid(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	return _body_action_handler.administer_first_aid(actor_id, body_item_id)


func apply_item_to_body(
		actor_id: StringName,
		item_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	return _body_action_handler.apply_item_to_body(
		actor_id, item_id, body_item_id
	)


func finish_off_body(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	return _body_action_handler.finish_off(actor_id, body_item_id)


func untie_body(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	return _body_action_handler.untie(actor_id, body_item_id)


func search_body_inventory(
		actor_id: StringName,
		body_item_id: StringName
) -> OperationResult:
	return _body_action_handler.search_body(actor_id, body_item_id)


func equipment_for_body(
		body_item_id: StringName
) -> Array[TacticalItemInstanceState]:
	return _body_action_handler.equipment_for_body(body_item_id)


func preview_movement(
		unit_id: StringName,
		destination: Vector2i,
		mode: StringName = &"normal"
) -> MovementPathResult:
	return _movement_query.execute(unit_id, destination, mode)


func preview_movement_detection(
		unit_id: StringName,
		path_result: MovementPathResult
) -> MovementDetectionPreview:
	if _detection_service == null or path_result == null or not path_result.success:
		return MovementDetectionPreview.new()
	return _detection_service.preview_for_path(unit_id, path_result.path)


func preview_movement_reactions(
		unit_id: StringName,
		path_result: MovementPathResult,
		movement_kind: StringName = &"normal"
) -> MovementReactionPreview:
	if _reaction_service == null:
		return MovementReactionPreview.new()
	return _reaction_service.preview_path_reactions(
		unit_id, path_result, movement_kind
	)


func reaction_unavailable_reason(
		unit_id: StringName,
		reaction_kind: StringName
) -> String:
	return (
		_reaction_service.reaction_unavailable_reason(unit_id, reaction_kind)
		if _reaction_service != null
		else "Reaction services are unavailable."
	)


func preview_reaction_reservation_tiles(
		unit_id: StringName,
		reaction_kind: StringName,
		direction: Vector2i
) -> Array[Vector2i]:
	return (
		_reaction_service.preview_reservation_tiles(unit_id, reaction_kind, direction)
		if _reaction_service != null
		else []
	)


func prepare_overwatch(unit_id: StringName, direction: Vector2i) -> OperationResult:
	return (
		_reaction_service.prepare_overwatch(unit_id, direction)
		if _reaction_service != null
		else OperationResult.fail(&"reaction_service_missing", "Overwatch is unavailable.")
	)


func prepare_brace(unit_id: StringName, direction: Vector2i) -> OperationResult:
	return (
		_reaction_service.prepare_brace(unit_id, direction)
		if _reaction_service != null
		else OperationResult.fail(&"reaction_service_missing", "Brace is unavailable.")
	)


func use_disengage(unit_id: StringName) -> OperationResult:
	return (
		_reaction_service.use_disengage(unit_id)
		if _reaction_service != null
		else OperationResult.fail(&"reaction_service_missing", "Disengage is unavailable.")
	)


func pending_reaction_decision() -> ReactionDecisionRequest:
	return _reaction_service.pending_decision() if _reaction_service != null else null


func resolve_reaction_decision(
		request_id: StringName,
		choice: StringName
) -> OperationResult:
	return (
		_reaction_service.resolve_pending_decision(request_id, choice)
		if _reaction_service != null
		else OperationResult.fail(&"reaction_service_missing", "Reaction decisions are unavailable.")
	)


func reaction_performance_snapshot() -> Dictionary:
	return _reaction_service.performance_snapshot() if _reaction_service != null else {}


func perception_tiles_for_observer(
		observer_id: StringName,
		facing_override: Vector2i = Vector2i.ZERO
) -> Dictionary:
	if _detection_service == null:
		return {"close": [], "focused": [], "aware": []}
	return _detection_service.perception_tiles_for_observer(
		observer_id,
		facing_override
	)


func preview_facing_direction(
		unit_id: StringName,
		target_tile: Vector2i
) -> Vector2i:
	if _facing_handler == null:
		return Vector2i.ZERO
	return _facing_handler.preview_direction(unit_id, target_tile)


func face_direction(
		unit_id: StringName,
		target_tile: Vector2i
) -> OperationResult:
	if _facing_handler == null:
		return OperationResult.fail(
			&"facing_handler_missing",
			"Manual facing is unavailable."
		)
	return _facing_handler.execute(unit_id, target_tile)


func facing_unavailable_reason(
		unit_id: StringName,
		target_tile: Vector2i
) -> String:
	if _facing_handler == null:
		return "Manual facing is unavailable."
	return _facing_handler.unavailable_reason(unit_id, target_tile)


func face_direction_cost_feet() -> int:
	return FacingHandler.FACE_DIRECTION_COST_FEET


func player_last_seen_positions() -> Dictionary:
	var squad: TacticalSquadState = state().get_squad(
		TacticalSquadState.PLAYER_TEAM_SQUAD_ID
	)
	return (
		squad.last_seen_positions_by_unit_id.duplicate(true)
		if squad != null
		else {}
	)


func enter_stealth(unit_id: StringName) -> OperationResult:
	if _stealth_handler == null:
		return OperationResult.fail(&"stealth_handler_missing", "Stealth is unavailable.")
	return _stealth_handler.enter_stealth(unit_id)


func stealth_unavailable_reason(unit_id: StringName) -> String:
	if _stealth_handler == null:
		return "Stealth is unavailable."
	return _stealth_handler.unavailable_reason(unit_id)


func is_initiative_combat() -> bool:
	return state().phase_state.is_initiative_combat()


func active_initiative_unit_id() -> StringName:
	return state().phase_state.active_unit_id()


func active_initiative_unit() -> TacticalUnitState:
	return state().active_initiative_unit()


func initiative_order() -> Array[StringName]:
	return state().phase_state.initiative_order.duplicate()


func initiative_total(unit_id: StringName) -> int:
	return state().phase_state.initiative_total(unit_id)


func pending_initiative_order() -> Array[StringName]:
	return state().phase_state.pending_initiative_unit_ids.duplicate()


func normalize_initiative() -> OperationResult:
	if _initiative_handler == null:
		return OperationResult.fail(
			&"initiative_handler_missing",
			"Initiative control is unavailable."
		)
	return _initiative_handler.normalize_active_turn()


func can_unit_act(unit_id: StringName) -> bool:
	return state().can_unit_act(unit_id)


func end_initiative_turn(unit_id: StringName) -> OperationResult:
	if _initiative_handler == null:
		return OperationResult.fail(&"initiative_handler_missing", "Initiative control is unavailable.")
	return _initiative_handler.end_active_turn(unit_id)


func resolve_active_ai_initiative() -> OperationResult:
	if _enemy_turn_handler == null:
		return OperationResult.fail(&"enemy_turn_handler_missing", "The enemy AI is unavailable.")
	var active_id: StringName = active_initiative_unit_id()
	var value: Variant = _enemy_turn_handler.call("resolve_initiative_activation", active_id)
	var result: OperationResult = value as OperationResult
	return result if result != null else OperationResult.fail(
		&"enemy_turn_result_missing",
		"The enemy AI returned no initiative result."
	)


func open_pending_ai_reaction_decision() -> OperationResult:
	if _enemy_turn_handler == null or not _enemy_turn_handler.has_method("open_pending_reaction_decision"):
		return OperationResult.fail(&"reaction_decision_missing", "No AI Reaction decision is pending.")
	return _enemy_turn_handler.call("open_pending_reaction_decision") as OperationResult


func resume_ai_after_reaction() -> OperationResult:
	if _enemy_turn_handler == null or not _enemy_turn_handler.has_method("resume_after_reaction"):
		return OperationResult.fail(&"reaction_resume_missing", "The AI cannot resume this Reaction event.")
	return _enemy_turn_handler.call("resume_after_reaction") as OperationResult


func has_pending_ai_reaction() -> bool:
	return (
		_enemy_turn_handler != null
		and _enemy_turn_handler.has_method("has_pending_reaction")
		and bool(_enemy_turn_handler.call("has_pending_reaction"))
	)


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


func begin_enemy_phase() -> OperationResult:
	return _end_phase_handler.begin_enemy_phase(EndPhaseCommand.new())


# Compatibility alias for earlier Stage 4 callers and tests.
func begin_world_phase() -> OperationResult:
	return begin_enemy_phase()


func begin_environment_phase() -> OperationResult:
	return _end_phase_handler.begin_environment_phase()


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
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL,
		origin_override: Variant = null,
		target_position_override: Variant = null
):
	if _attack_preview_query == null:
		return null
	var preview = _attack_preview_query.call(
		"execute",
		attacker_id,
		target_id,
		action_id,
		power_attack_value,
		damage_channel,
		origin_override,
		target_position_override
	)
	if (
		preview != null
		and bool(preview.get("success"))
		and _reaction_service != null
		and StringName(preview.get("action_source")) != &"reaction"
	):
		var attacker: TacticalUnitState = _state_store.state.get_unit(attacker_id)
		if attacker != null and attacker.is_player_controlled():
			var summaries: Array[Dictionary] = (
				_reaction_service.preview_provoking_action_reactions(
					attacker_id, action_id
				)
			)
			preview.provoking_reaction_summaries = summaries
			var highest: int = 0
			for summary: Dictionary in summaries:
				highest = maxi(highest, int(summary.get("hit_chance_percent", 0)))
			preview.highest_provoking_reaction_hit_chance = highest
	return preview


func legal_attack_target_ids(
		attacker_id: StringName,
		action_id: StringName,
		power_attack_value: int = 0,
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL,
		origin_override: Variant = null,
		target_position_override: Variant = null
) -> Array[StringName]:
	var result: Array[StringName] = []
	if _attack_preview_query == null:
		return result
	var value: Variant = _attack_preview_query.call(
		"legal_target_ids",
		attacker_id,
		action_id,
		power_attack_value,
		damage_channel,
		origin_override,
		target_position_override
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
	if (
		preview != null
		and bool(preview.get("success"))
		and _reaction_service != null
		and StringName(preview.get("action_source")) != &"reaction"
	):
		var attacker_id := StringName(preview.get("attacker_id"))
		var action_id := StringName(preview.get("action_id"))
		var provoking_result: Dictionary = (
			_reaction_service.resolve_ai_reactions_for_provoking_action(
				attacker_id, action_id
			)
		)
		if bool(provoking_result.get("stopped", false)):
			return OperationResult.fail(
				&"provoking_reaction_stopped_action",
				"A Reaction prevented the provoking action from continuing."
			)
		# Reaction use changes the state revision even on a miss. Rebuild the
		# ordinary attack preview before committing the original action.
		if not (provoking_result.get("reaction_resolutions", []) as Array).is_empty():
			preview = preview_attack(
				attacker_id,
				StringName(preview.get("target_id")),
				action_id,
				int(preview.get("power_attack_value")),
				StringName(preview.get("damage_channel")),
				preview.get("attack_origin_override"),
				preview.get("target_position_override")
			)
			if preview == null or not bool(preview.get("success")):
				return OperationResult.fail(
					&"attack_no_longer_legal_after_reaction",
					"The provoking action is no longer legal after the Reaction."
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

func structure_between_tiles(first: Vector2i, second: Vector2i) -> TacticalStructureDefinition:
	return _map_definition.structure_at_edge(first, second) if _map_definition != null else null


func attack_environment_source(
		attacker_id: StringName,
		source_id: StringName,
		action_id: StringName
) -> OperationResult:
	if _structure_attack_handler == null:
		return OperationResult.fail(&"structure_attack_handler_missing", "Structure attacks are unavailable.")
	var preview_value: Dictionary = _structure_attack_handler.preview(attacker_id, source_id, action_id)
	if not bool(preview_value.get("success", false)):
		return OperationResult.fail(&"structure_attack_unavailable", String(preview_value.get("reason", "The structure cannot be attacked.")))
	return _structure_attack_handler.execute(preview_value)


func opening_between_tiles(first: Vector2i, second: Vector2i) -> TacticalOpeningDefinition:
	return _opening_handler.opening_between(first, second) if _opening_handler != null else null


func opening_runtime(opening_id: StringName) -> TacticalOpeningState:
	return _opening_handler.opening_state(opening_id) if _opening_handler != null else null


func opening_interaction_options(
		unit_id: StringName,
		opening_id: StringName
) -> Array[Dictionary]:
	return (
		_opening_handler.available_interactions(unit_id, opening_id)
		if _opening_handler != null
		else []
	)


func adjacent_interactable_openings(unit_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var unit: TacticalUnitState = state().get_unit(unit_id)
	if unit == null or _map_definition == null:
		return result
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var opening: TacticalOpeningDefinition = _map_definition.opening_at_edge(
			unit.grid_position, unit.grid_position + direction
		)
		if opening == null:
			continue
		if not opening_interaction_options(unit_id, opening.opening_id).is_empty():
			result.append(opening.opening_id)
	return result


func adjacent_interactable_structures(unit_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var unit: TacticalUnitState = state().get_unit(unit_id)
	if unit == null or _map_definition == null:
		return result
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var structure: TacticalStructureDefinition = _map_definition.structure_at_edge(
			unit.grid_position, unit.grid_position + direction
		)
		if structure == null:
			continue
		var runtime: TacticalStructureState = state().environment_state.structure_state(
			structure.structure_id
		) if state().environment_state != null else null
		if runtime == null or runtime.integrity_state_id in [
			TacticalStructureDefinition.STATE_DESTROYED,
			TacticalStructureDefinition.STATE_CLEARED,
		]:
			continue
		result.append(structure.structure_id)
	return result


func observation_origins_for_unit(
		unit_id: StringName,
		position_override: Variant = null
) -> Array[TacticalObservationOrigin]:
	var unit: TacticalUnitState = state().get_unit(unit_id)
	if unit == null:
		return []
	return TacticalObservationOriginQuery.legal_origins(
		state(), _map_definition, unit, position_override
	)


func physical_edge_cover(tile: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	if _map_definition == null or not _map_definition.is_inside(tile):
		return result
	var environment: TacticalEnvironmentState = state().environment_state
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var neighbour: Vector2i = tile + direction
		var category: StringName = TacticalCombatGeometryResult.COVER_NONE
		if _map_definition.is_inside(neighbour) and _map_definition.blocks_vision(neighbour):
			category = TacticalCombatGeometryResult.COVER_TOTAL
		elif environment != null:
			var height: StringName = environment.cover_height_at_edge(_map_definition, tile, neighbour)
			match height:
				TacticalBarrierSegmentDefinition.HEIGHT_LOW:
					category = TacticalCombatGeometryResult.COVER_LIGHT
				TacticalBarrierSegmentDefinition.HEIGHT_HIGH:
					category = TacticalCombatGeometryResult.COVER_HEAVY
				TacticalBarrierSegmentDefinition.HEIGHT_FULL:
					category = TacticalCombatGeometryResult.COVER_TOTAL
		if category != TacticalCombatGeometryResult.COVER_NONE:
			result[direction] = category
	return result


func toggle_opening(unit_id: StringName, opening_id: StringName) -> OperationResult:
	if _opening_handler == null:
		return OperationResult.fail(&"opening_handler_missing", "Opening interactions are unavailable.")
	return _opening_handler.toggle_opening(unit_id, opening_id)


func pick_opening_lock(unit_id: StringName, opening_id: StringName) -> OperationResult:
	if _opening_handler == null:
		return OperationResult.fail(&"opening_handler_missing", "Lockpicking is unavailable.")
	return _opening_handler.pick_lock(unit_id, opening_id)


func peek_through_opening(unit_id: StringName, opening_id: StringName) -> OperationResult:
	if _opening_handler == null:
		return OperationResult.fail(&"opening_handler_missing", "Peek is unavailable.")
	return _opening_handler.peek(unit_id, opening_id)


func lean_origin_for_opening(unit_id: StringName, opening_id: StringName) -> Variant:
	return _opening_handler.lean_origin(unit_id, opening_id) if _opening_handler != null else null


func peek_around_corner(unit_id: StringName, wall_tile: Vector2i) -> OperationResult:
	if _opening_handler == null:
		return OperationResult.fail(&"opening_handler_missing", "Corner Peek is unavailable.")
	return _opening_handler.peek_around_corner(unit_id, wall_tile)


func lean_origin_for_corner(unit_id: StringName, wall_tile: Vector2i) -> Variant:
	return (
		_opening_handler.corner_lean_origin(unit_id, wall_tile)
		if _opening_handler != null
		else null
	)


# Stage 4.4 shared combat-geometry presentation queries. Player previews, AI
# and committed attacks consume the same authority rather than reconstructing
# cover independently in the UI.
func combat_geometry_between(
		attacker_id: StringName,
		target_id: StringName,
		origin_override: Variant = null,
		target_position_override: Variant = null
) -> TacticalCombatGeometryResult:
	if (
		_attack_preview_query != null
		and _attack_preview_query.has_method("combat_geometry_between")
	):
		return _attack_preview_query.call(
			"combat_geometry_between",
			attacker_id,
			target_id,
			origin_override,
			target_position_override
		) as TacticalCombatGeometryResult
	var attacker: TacticalUnitState = state().get_unit(attacker_id)
	var target: TacticalUnitState = state().get_unit(target_id)
	if attacker == null or target == null:
		return TacticalCombatGeometryResult.new()
	if _geometry_cache != null:
		return _geometry_cache.evaluate(
			attacker,
			target,
			origin_override,
			target_position_override
		)
	return TacticalCombatGeometryQuery.evaluate(
		state(),
		_map_definition,
		attacker,
		target,
		origin_override,
		target_position_override
	)


func preview_destination_cover(
		mover_unit_id: StringName,
		destination: Vector2i
) -> TacticalCoverPreview:
	var result := TacticalCoverPreview.new()
	result.mover_unit_id = mover_unit_id
	result.destination = destination
	var mover: TacticalUnitState = state().get_unit(mover_unit_id)
	if mover == null or not _map_definition.is_inside(destination):
		return result
	for enemy: TacticalUnitState in state().get_enemy_units():
		if enemy == null or enemy.is_incapacitated():
			continue
		if not is_unit_visible_to_player(enemy.unit_id):
			continue
		var geometry: TacticalCombatGeometryResult = combat_geometry_between(
			enemy.unit_id,
			mover.unit_id,
			null,
			Vector2(destination) + Vector2(0.5, 0.5)
		)
		result.add_result(enemy.unit_id, geometry)
	return result


func selected_unit_cover_sectors(
		unit_id: StringName
) -> Dictionary:
	var selected: TacticalUnitState = state().get_unit(unit_id)
	var result: Dictionary = {}
	if selected == null:
		return result
	for enemy: TacticalUnitState in state().get_enemy_units():
		if enemy == null or enemy.is_incapacitated():
			continue
		if not is_unit_visible_to_player(enemy.unit_id):
			continue
		var direction: Vector2i = TacticalPerceptionRules.normalized_facing(
			enemy.grid_position - selected.grid_position
		)
		if direction == Vector2i.ZERO:
			continue
		var sector_id: StringName = StringName("%d,%d" % [direction.x, direction.y])
		var geometry: TacticalCombatGeometryResult = combat_geometry_between(
			enemy.unit_id,
			selected.unit_id
		)
		var current: Dictionary = result.get(sector_id, {})
		var enemy_ids: Array[StringName] = []
		if current.has("enemy_ids"):
			for value: Variant in current.get("enemy_ids", []):
				enemy_ids.append(StringName(value))
		enemy_ids.append(enemy.unit_id)
		if current.is_empty() or _cover_danger_rank(geometry.cover_category) < int(
			current.get("danger_rank", 99)
		):
			result[sector_id] = {
				"direction": direction,
				"cover_category": geometry.cover_category,
				"cover_label": geometry.cover_label(),
				"danger_rank": _cover_danger_rank(geometry.cover_category),
				"enemy_ids": enemy_ids,
			}
		else:
			current["enemy_ids"] = enemy_ids
			result[sector_id] = current
	return result


func local_cover_at(
		tile: Vector2i,
		team_id: StringName = &"player"
) -> TacticalLocalCoverResult:
	return TacticalLocalCoverQuery.evaluate_position(
		state(),
		_map_definition,
		tile,
		team_id
	)


func selected_unit_cover_summary(unit_id: StringName) -> Dictionary:
	var selected: TacticalUnitState = state().get_unit(unit_id)
	if selected == null:
		return {
			"cover_category": TacticalCombatGeometryResult.COVER_NONE,
			"source_count": 0,
		}
	var local: TacticalLocalCoverResult = local_cover_at(
		selected.grid_position,
		selected.team_id
	)
	return {
		"cover_category": local.strongest_local_cover,
		"source_count": local.source_feature_ids.size(),
		"directional_cover": local.directional_cover_by_sector.duplicate(),
	}


func directional_cover_field(
		defended_tile: Vector2i
) -> TacticalDirectionalCoverField:
	return TacticalDirectionalCoverFieldQuery.build(
		state(),
		_map_definition,
		defended_tile,
		&"player"
	)


func tactical_revision() -> int:
	return state().revision if state() != null else 0


func geometry_revision() -> int:
	return state().geometry_revision() if state() != null else 0


func knowledge_revision() -> int:
	return (
		state().knowledge_state.revision
		if state() != null and state().knowledge_state != null
		else 0
	)


func begin_visibility_recalculation_deferral() -> void:
	# Stage 4.4e1 batches both fog visibility and the post-move squad
	# perception refresh behind the movement animation boundary.
	if _visibility_service != null and _visibility_service.has_method("begin_recalculation_deferral"):
		_visibility_service.call("begin_recalculation_deferral")
	if _detection_service != null and _detection_service.has_method("begin_perception_recalculation_deferral"):
		_detection_service.call("begin_perception_recalculation_deferral")


func end_visibility_recalculation_deferral() -> void:
	end_visibility_recalculation_deferral_for_units([], true)


func end_visibility_recalculation_deferral_for_units(
		moved_unit_ids: Array[StringName],
		force_full_visibility: bool = false
) -> void:
	if _visibility_service != null:
		if _visibility_service.has_method("end_recalculation_deferral_for_units"):
			_visibility_service.call(
				"end_recalculation_deferral_for_units",
				moved_unit_ids,
				force_full_visibility
			)
		elif _visibility_service.has_method("end_recalculation_deferral"):
			_visibility_service.call("end_recalculation_deferral")
	if _detection_service != null and _detection_service.has_method("end_perception_recalculation_deferral"):
		_detection_service.call("end_perception_recalculation_deferral")


func flush_requested_perception_refreshes() -> OperationResult:
	if _detection_service == null:
		return OperationResult.ok(false, "Perception service is unavailable.")
	return _detection_service.flush_requested_perception_refreshes()


func visibility_revision() -> int:
	return (
		int(_visibility_service.call("revision"))
		if _visibility_service != null
		else 0
	)


func performance_snapshot() -> Dictionary:
	return {
		"attack_preview": (
			_attack_preview_query.call("performance_snapshot")
			if (
				_attack_preview_query != null
				and _attack_preview_query.has_method("performance_snapshot")
			)
			else {}
		),
		"visibility": (
			_visibility_service.call("performance_snapshot")
			if (
				_visibility_service != null
				and _visibility_service.has_method("performance_snapshot")
			)
			else {}
		),
		"detection": (
			_detection_service.performance_snapshot()
			if _detection_service != null
			else {}
		),
		"enemy_ai": (
			_enemy_turn_handler.call("performance_snapshot")
			if (
				_enemy_turn_handler != null
				and _enemy_turn_handler.has_method("performance_snapshot")
			)
			else {}
		),
		"directional_cover_field": (
			TacticalDirectionalCoverFieldQuery.performance_snapshot()
		),
		"local_cover": TacticalLocalCoverQuery.performance_snapshot(),
	}


func _cover_danger_rank(category: StringName) -> int:
	match category:
		TacticalCombatGeometryResult.COVER_NONE:
			return 0
		TacticalCombatGeometryResult.COVER_LIGHT:
			return 1
		TacticalCombatGeometryResult.COVER_HEAVY:
			return 2
		TacticalCombatGeometryResult.COVER_TOTAL:
			return 3
		_:
			return 0
