class_name Stage431dDiagonalMeleeAlertDedupTests
extends RefCounted

const TacticalMeleeReachRules: Script = preload(
	"res://domain/tactical/combat/tactical_melee_reach_rules.gd"
)
const ENEMY_ACTION_PLANNER_SCRIPT: Script = preload(
	"res://application/tactical/ai/enemy_action_planner.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_open_diagonal_melee_and_sealed_corners(failures)
	_test_contextual_attack_and_ai_use_diagonal_contact(failures)
	_test_aware_squad_reacquisition_does_not_interrupt_visible_movement(failures)
	_test_hidden_revelation_still_interrupts_movement(failures)
	return failures


static func _test_open_diagonal_melee_and_sealed_corners(
		failures: Array[String]
) -> void:
	var map_definition := TacticalMapDefinition.new()
	map_definition.grid_size = Vector2i(12, 12)
	var attacker_cells: Array[Vector2i] = [Vector2i(4, 4)]
	var target_cells: Array[Vector2i] = [Vector2i(5, 5)]
	_expect(
		TacticalMeleeReachRules.can_reach(
			attacker_cells,
			target_cells,
			map_definition,
			5
		),
		"Open diagonal adjacency must count as 5-foot melee contact.",
		failures
	)
	_expect(
		TacticalMeleeReachRules.minimum_reach_distance_feet(
			attacker_cells,
			target_cells,
			map_definition
		) == 5,
		"An open diagonal neighbour must display a 5-foot melee distance.",
		failures
	)

	map_definition.blocked_tiles = [Vector2i(5, 4), Vector2i(4, 5)]
	_expect(
		not TacticalMeleeReachRules.can_reach(
			attacker_cells,
			target_cells,
			map_definition,
			5
		),
		"Two solid orthogonal blockers must seal a diagonal melee corner.",
		failures
	)
	_expect(
		TacticalMeleeReachRules.has_sealed_diagonal_contact(
			attacker_cells,
			target_cells,
			map_definition
		),
		"The shared reach rule must identify the sealed diagonal corner.",
		failures
	)

	map_definition.blocked_tiles = [Vector2i(5, 4)]
	_expect(
		TacticalMeleeReachRules.can_reach(
			attacker_cells,
			target_cells,
			map_definition,
			5
		),
		"One corner blocker alone must not prevent diagonal melee contact.",
		failures
	)


static func _test_contextual_attack_and_ai_use_diagonal_contact(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var guard: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	if marauder == null or guard == null:
		failures.append("The diagonal combat fixture is incomplete.")
		return
	_move_other_units_far_away(session, [marauder.unit_id, guard.unit_id])
	state.set_unit_position(
		marauder.unit_id,
		Vector2i(20, 20),
		session.map_definition,
		false
	)
	state.set_unit_position(
		guard.unit_id,
		Vector2i(21, 21),
		session.map_definition,
		false
	)
	session.visibility_service.call("recalculate_all_teams")

	var item: TacticalItemInstanceState = state.get_hand_item(
		marauder.unit_id,
		TacticalInventoryState.KIND_PRIMARY_HAND
	)
	var attack_id: StringName = _first_supported_attack(session, item)
	_expect(
		not attack_id.is_empty(),
		"The diagonal contextual-attack fixture needs a supported hand attack.",
		failures
	)
	if attack_id.is_empty():
		return
	var preview: Variant = session.screen_facade.preview_attack(
		marauder.unit_id,
		guard.unit_id,
		attack_id,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)
	_expect(
		preview != null and bool(preview.get("success")),
		"A contextual melee attack must be legal across an open diagonal.",
		failures
	)
	if preview != null and bool(preview.get("success")):
		_expect(
			int(preview.get("range_feet")) == 5,
			"The attack preview must report open diagonal contact as 5 feet.",
			failures
		)

	var squad: TacticalSquadState = state.get_squad(guard.squad_id)
	if squad == null:
		failures.append("The diagonal AI fixture needs the guard squad.")
		return
	squad.make_aware()
	marauder.reveal_to_squad(squad.squad_id)
	_expect(
		state.begin_initiative_combat(
			[guard.unit_id, marauder.unit_id],
			{guard.unit_id: 20, marauder.unit_id: 10}
		),
		"The diagonal AI fixture must enter initiative combat.",
		failures
	)
	var planner: RefCounted = ENEMY_ACTION_PLANNER_SCRIPT.new() as RefCounted
	planner.call("configure",
		session.state_store,
		session.map_definition,
		session.content_catalogue,
		session.attack_preview_query
	)
	var plan: RefCounted = planner.call("plan_activation", guard) as RefCounted
	_expect(
		plan != null and bool(plan.get("valid")),
		"The guard must produce a diagonal melee plan.",
		failures
	)
	if plan != null and bool(plan.get("valid")):
		_expect(
			StringName(plan.get("target_id")) == marauder.unit_id,
			"The guard must target the revealed diagonal opponent.",
			failures
		)
		_expect(
			not bool(plan.get("move_required"))
			and bool(plan.get("attack_after_move")),
			"The guard must attack from the diagonal instead of repositioning.",
			failures
		)


static func _test_aware_squad_reacquisition_does_not_interrupt_visible_movement(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var guard: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	var squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	if marauder == null or guard == null or squad == null:
		failures.append("The alert-deduplication fixture is incomplete.")
		return
	_move_other_units_far_away(session, [marauder.unit_id, guard.unit_id])
	state.set_unit_position(
		marauder.unit_id,
		Vector2i(10, 10),
		session.map_definition,
		false
	)
	state.set_unit_position(
		guard.unit_id,
		Vector2i(15, 10),
		session.map_definition,
		false
	)
	squad.make_aware()
	marauder.leave_stealth()
	marauder.clear_revelation()
	var path: Array[Vector2i] = [
		Vector2i(10, 10),
		Vector2i(11, 10),
		Vector2i(12, 10),
		Vector2i(13, 10),
	]
	var resolution: TacticalDetectionResolution = (
		session.detection_service.prepare_path_resolution(
			marauder.unit_id,
			path
		)
	)
	_expect(
		resolution.detected_squad_ids.has(squad.squad_id),
		"An aware squad must automatically reacquire a visible character.",
		failures
	)
	_expect(
		not resolution.movement_interrupted(),
		"Reacquisition by an already-aware squad must not pause visible movement.",
		failures
	)
	_expect(
		resolution.newly_aware_squad_ids.is_empty(),
		"An already-aware squad must not generate a duplicate alert transition.",
		failures
	)
	_expect(
		resolution.revealed_at_destination_squad_ids.has(squad.squad_id),
		"The squad must retain the moving character at the path destination.",
		failures
	)


static func _test_hidden_revelation_still_interrupts_movement(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var guard: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	var squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	if marauder == null or guard == null or squad == null:
		failures.append("The hidden-revelation fixture is incomplete.")
		return
	_move_other_units_far_away(session, [marauder.unit_id, guard.unit_id])
	state.set_unit_position(
		marauder.unit_id,
		Vector2i(10, 10),
		session.map_definition,
		false
	)
	state.set_unit_position(
		guard.unit_id,
		Vector2i(15, 10),
		session.map_definition,
		false
	)
	guard.set_facing(Vector2i(-1, 0))
	squad.make_aware()
	marauder.enter_stealth()
	marauder.clear_revelation()
	var initiative_roll_count: int = (
		state.get_player_units().size()
		+ state.get_units_in_squad(squad.squad_id).size()
	)
	var scripted_rolls: Array[int] = [1]
	for index: int in range(initiative_roll_count):
		scripted_rolls.append(maxi(1, 20 - index))
	session.combat_dice_roller.call("set_scripted_results", scripted_rolls)
	var path: Array[Vector2i] = [
		Vector2i(10, 10),
		Vector2i(11, 10),
		Vector2i(12, 10),
		Vector2i(13, 10),
	]
	var resolution: TacticalDetectionResolution = (
		session.detection_service.prepare_path_resolution(
			marauder.unit_id,
			path
		)
	)
	_expect(
		resolution.movement_interrupted(),
		"A failed Stealth check must still stop movement even when the squad is already aware.",
		failures
	)
	_expect(
		resolution.newly_aware_squad_ids.is_empty(),
		"Revealing another hidden character must not re-alert the aware squad.",
		failures
	)


static func _move_other_units_far_away(
		session: TacticalSession,
		kept_unit_ids: Array[StringName]
) -> void:
	var offset: int = 0
	for unit: TacticalUnitState in session.state_store.state.get_units():
		if kept_unit_ids.has(unit.unit_id):
			continue
		session.state_store.state.set_unit_position(
			unit.unit_id,
			Vector2i(50 + offset, 50),
			session.map_definition,
			false
		)
		offset += 2


static func _first_supported_attack(
		session: TacticalSession,
		item: TacticalItemInstanceState
) -> StringName:
	if item == null or item.definition == null:
		return &""
	for action_id: StringName in item.definition.granted_action_ids:
		if session.screen_facade.is_stage_4_attack(action_id):
			return action_id
	return &""


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
