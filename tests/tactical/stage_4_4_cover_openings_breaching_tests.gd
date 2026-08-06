class_name Stage44CoverOpeningsBreachingTests
extends RefCounted

const LOW_FENCE_ID: StringName = &"barrier.farm.low_fence.west"
const BARRICADE_ID: StringName = &"structure.farm.wooden_barricade"
const STONE_WALL_ID: StringName = &"structure.farm.isolated_stone_wall"
const DOOR_ID: StringName = &"opening.farm.ordinary_door"
const LOCKED_DOOR_ID: StringName = &"opening.farm.locked_door"
const WINDOW_ID: StringName = &"opening.farm.clear_window"
const BARS_ID: StringName = &"opening.farm.barred_opening"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_geometry_and_environment_state(failures)
	_test_directional_cover_samples(failures)
	_test_line_of_sight_and_line_of_effect_are_separate(failures)
	_test_creature_cover_and_fallen_exception(failures)
	_test_cover_preview_and_sector_queries(failures)
	_test_attack_preview_and_cover_hit(failures)
	_test_door_operation_pathing_peek_and_lockpick(failures)
	_test_corner_peek_and_lean_origin(failures)
	_test_direct_structure_damage_breach_and_salvage(failures)
	_test_environment_snapshot_restore(failures)
	return failures


static func _test_authored_geometry_and_environment_state(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var map_definition: TacticalMapDefinition = session.map_definition
	var state: TacticalState = session.state_store.state
	_expect(map_definition.barrier_definition(LOW_FENCE_ID) != null,
		"Stage 4.4 must author a low directional-cover barrier.", failures)
	_expect(map_definition.structure_definition(BARRICADE_ID) != null,
		"Stage 4.4 must author a damageable high barricade.", failures)
	_expect(map_definition.structure_definition(STONE_WALL_ID) != null,
		"Stage 4.4 must author a full-height damageable wall segment.", failures)
	_expect(map_definition.opening_definition(DOOR_ID) != null,
		"Stage 4.4 must author an ordinary edge door.", failures)
	_expect(map_definition.opening_definition(LOCKED_DOOR_ID) != null,
		"Stage 4.4 must author a locked edge door.", failures)
	_expect(map_definition.opening_definition(WINDOW_ID) != null,
		"Stage 4.4 must author clear glass.", failures)
	_expect(map_definition.opening_definition(BARS_ID) != null,
		"Stage 4.4 must author a barred opening.", failures)
	_expect(state.environment_state != null,
		"TacticalState must own mutable environment state.", failures)
	_expect(state.environment_state.opening_state(DOOR_ID) != null,
		"Runtime environment state must instantiate authored openings.", failures)
	_expect(state.environment_state.structure_state(BARRICADE_ID) != null,
		"Runtime environment state must instantiate authored structures.", failures)
	_expect(map_definition.validate_definition().is_empty(),
		"The Stage 4.4 sandbox map definition must validate.", failures)
	_expect(state.environment_state.validate_state(map_definition).is_empty(),
		"The Stage 4.4 runtime environment registry must validate.", failures)


static func _test_directional_cover_samples(failures: Array[String]) -> void:
	var light_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var light_state: TacticalState = light_session.state_store.state
	var light_attacker: TacticalUnitState = light_state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var light_target: TacticalUnitState = light_state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(light_session, light_attacker, Vector2i(4, 3), failures)
	_place(light_session, light_target, Vector2i(6, 3), failures)
	var light: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		light_state, light_session.map_definition, light_attacker, light_target
	)
	_expect(light.has_line_of_sight and light.has_line_of_effect,
		"A low fence must preserve sight and line of effect.", failures)
	_expect(light.clear_exposure_samples == 3,
		"A low fence must leave three of five exposure samples clear.", failures)
	_expect(light.cover_category == TacticalCombatGeometryResult.COVER_LIGHT,
		"Three clear samples must produce Light Cover.", failures)
	_expect(light.cover_ac_bonus == 2 and light.cover_reflex_bonus == 1,
		"Light Cover must grant +2 AC and +1 Reflex.", failures)

	var heavy_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var heavy_state: TacticalState = heavy_session.state_store.state
	var heavy_attacker: TacticalUnitState = heavy_state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var heavy_target: TacticalUnitState = heavy_state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(heavy_session, heavy_attacker, Vector2i(4, 4), failures)
	_place(heavy_session, heavy_target, Vector2i(6, 4), failures)
	var heavy: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		heavy_state, heavy_session.map_definition, heavy_attacker, heavy_target
	)
	_expect(heavy.clear_exposure_samples == 1,
		"A high barricade must leave one of five exposure samples clear.", failures)
	_expect(heavy.cover_category == TacticalCombatGeometryResult.COVER_HEAVY,
		"One clear sample must produce Heavy Cover.", failures)
	_expect(heavy.cover_ac_bonus == 4 and heavy.cover_reflex_bonus == 2,
		"Heavy Cover must grant +4 AC and +2 Reflex.", failures)
	_expect(heavy.primary_cover_source_id == BARRICADE_ID,
		"Directional cover must identify the protecting barricade.", failures)

	_place(heavy_session, heavy_target, Vector2i(5, 4), failures)
	var same_side: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		heavy_state, heavy_session.map_definition, heavy_attacker, heavy_target
	)
	_expect(same_side.cover_category == TacticalCombatGeometryResult.COVER_NONE,
		"A barrier must not protect two units standing on the same side of it.", failures)


static func _test_line_of_sight_and_line_of_effect_are_separate(
		failures: Array[String]
) -> void:
	var window_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var window_state: TacticalState = window_session.state_store.state
	var observer: TacticalUnitState = window_state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var target: TacticalUnitState = window_state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(window_session, observer, Vector2i(10, 6), failures)
	_place(window_session, target, Vector2i(11, 6), failures)
	var glass: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		window_state, window_session.map_definition, observer, target
	)
	_expect(glass.has_line_of_sight,
		"Intact clear glass must permit line of sight.", failures)
	_expect(not glass.has_line_of_effect,
		"Intact clear glass must block ordinary direct line of effect.", failures)
	_expect(glass.cover_category == TacticalCombatGeometryResult.COVER_TOTAL,
		"An intact window must prevent ordinary direct targeting.", failures)

	var door_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var door_state: TacticalState = door_session.state_store.state
	var door_observer: TacticalUnitState = door_state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var door_target: TacticalUnitState = door_state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(door_session, door_observer, Vector2i(10, 4), failures)
	_place(door_session, door_target, Vector2i(11, 4), failures)
	var closed_door: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		door_state, door_session.map_definition, door_observer, door_target
	)
	_expect(not closed_door.has_line_of_sight and not closed_door.has_line_of_effect,
		"A closed solid door must block sight and effect.", failures)

	var bars_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var bars_state: TacticalState = bars_session.state_store.state
	var bars_observer: TacticalUnitState = bars_state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var bars_target: TacticalUnitState = bars_state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(bars_session, bars_observer, Vector2i(10, 7), failures)
	_place(bars_session, bars_target, Vector2i(11, 7), failures)
	var bars: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		bars_state, bars_session.map_definition, bars_observer, bars_target
	)
	_expect(bars.has_line_of_sight and bars.has_line_of_effect,
		"Bars must permit sight and partial direct effect.", failures)
	_expect(bars.cover_category == TacticalCombatGeometryResult.COVER_HEAVY,
		"The authored barred opening must provide Heavy Cover.", failures)


static func _test_creature_cover_and_fallen_exception(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	var intervening: TacticalUnitState = state.get_unit(TacticalSandboxFactory.PRACTICE_DUMMY_ID)
	var standing_cover: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		state, session.map_definition, attacker, target
	)
	_expect(standing_cover.cover_category == TacticalCombatGeometryResult.COVER_LIGHT,
		"A similarly sized standing creature between two units must provide Light Cover.", failures)
	_expect(standing_cover.primary_cover_source_id == intervening.unit_id,
		"Creature cover must identify the intervening creature.", failures)
	intervening.restore_damage_state(-1, 0)
	state.synchronise_body_items(session.map_definition)
	state.rebuild_unit_occupancy()
	var fallen_cover: TacticalCombatGeometryResult = TacticalCombatGeometryQuery.evaluate(
		state, session.map_definition, attacker, target
	)
	_expect(fallen_cover.cover_category == TacticalCombatGeometryResult.COVER_NONE,
		"A Dying, Unconscious or Dead creature must not provide ordinary creature cover.", failures)


static func _test_cover_preview_and_sector_queries(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var mover: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(session, enemy, Vector2i(6, 4), failures)
	session.visibility_service.call("recalculate_all_teams", true)
	var preview: TacticalCoverPreview = session.screen_facade.preview_destination_cover(
		mover.unit_id, Vector2i(4, 4)
	)
	var against_enemy: TacticalCombatGeometryResult = preview.result_for_enemy(enemy.unit_id)
	_expect(against_enemy != null and against_enemy.cover_category == TacticalCombatGeometryResult.COVER_HEAVY,
		"Movement destination preview must report Heavy Cover against the visible guard.", failures)
	_expect(preview.summary_text().contains("Heavy"),
		"The destination preview must expose a compact cover summary.", failures)

	_place(session, mover, Vector2i(4, 4), failures)
	session.visibility_service.call("recalculate_all_teams", true)
	var sectors: Dictionary = session.screen_facade.selected_unit_cover_sectors(mover.unit_id)
	var east: Dictionary = sectors.get(&"1,0", {})
	_expect(not east.is_empty(),
		"The selected-character cover ring must create an east threat sector.", failures)
	_expect(StringName(east.get("cover_category", &"")) == TacticalCombatGeometryResult.COVER_HEAVY,
		"The selected-character sector must show the current worst directional cover.", failures)


static func _test_attack_preview_and_cover_hit(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(session, attacker, Vector2i(4, 4), failures)
	_place(session, target, Vector2i(6, 4), failures)
	attacker.refresh_for_new_round()
	session.visibility_service.call("recalculate_all_teams", true)
	var action_id: StringName = _first_attack_id(session, attacker, AttackDefinition.ATTACK_RANGED)
	if action_id.is_empty():
		failures.append("The cover-hit fixture needs a ranged weapon attack.")
		return
	var preview: TacticalAttackPreview = session.attack_preview_query.call(
		"execute", attacker.unit_id, target.unit_id, action_id
	) as TacticalAttackPreview
	_expect(preview != null and preview.success,
		"A ranged attack through the high barricade must produce a legal preview.", failures)
	if preview == null or not preview.success:
		return
	_expect(preview.cover_category == TacticalCombatGeometryResult.COVER_HEAVY,
		"Attack preview must expose Heavy Cover.", failures)
	_expect(preview.effective_target_armour_class == preview.base_target_armour_class + 4,
		"Attack preview must add Heavy Cover to effective AC.", failures)
	var required_roll: int = preview.base_target_armour_class - preview.attack_bonus
	required_roll = clampi(required_roll, 2, 19)
	if required_roll + preview.attack_bonus >= preview.effective_target_armour_class:
		required_roll = maxi(2, preview.effective_target_armour_class - preview.attack_bonus - 1)
	_expect(required_roll + preview.attack_bonus >= preview.base_target_armour_class,
		"The test fixture must be able to create a cover-only miss.", failures)
	if required_roll + preview.attack_bonus < preview.base_target_armour_class:
		return
	var barricade: TacticalStructureState = state.environment_state.structure_state(BARRICADE_ID)
	var hp_before: int = barricade.current_hp
	var target_hp_before: int = target.current_hp
	session.screen_facade.set_combat_scripted_rolls_for_tests([required_roll, 6])
	var result: OperationResult = session.attack_handler.call("execute_preview", preview) as OperationResult
	_expect(result != null and result.success,
		"A committed cover-only miss must resolve successfully.", failures)
	if result == null or not result.success:
		return
	var resolution: TacticalAttackResolution = result.data as TacticalAttackResolution
	_expect(resolution != null and resolution.missed_due_to_cover and not resolution.hit,
		"The attack must record missed_due_to_cover without hitting the character.", failures)
	_expect(target.current_hp == target_hp_before,
		"A cover-only miss must not damage the protected character.", failures)
	_expect(barricade.current_hp < hp_before,
		"A cover-only miss must apply the rolled damage to the protecting structure after Hardness.", failures)


static func _test_door_operation_pathing_peek_and_lockpick(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_place(session, actor, Vector2i(10, 4), failures)
	actor.refresh_for_new_round()
	state.mark_tile_explored(&"player", Vector2i(11, 4))
	var capacity_before: int = actor.action_budget.remaining_turn_capacity_feet
	var move_result: OperationResult = session.movement_handler.execute_move(
		MoveCommand.new(actor.unit_id, Vector2i(11, 4))
	)
	_expect(move_result.success,
		"A known ordinary unlocked door must open as part of movement.", failures)
	_expect(state.environment_state.opening_state(DOOR_ID).is_open(),
		"Crossing a normal door route must commit its Open state.", failures)
	_expect(actor.grid_position == Vector2i(11, 4),
		"The actor must cross the opened doorway when no new information interrupts movement.", failures)
	_expect(capacity_before - actor.action_budget.remaining_turn_capacity_feet == 10,
		"One tile through a normal door must cost 5 ft movement plus 5 ft to open.", failures)

	actor.refresh_for_new_round()
	var closed: OperationResult = session.opening_handler.toggle_opening(actor.unit_id, DOOR_ID)
	_expect(closed.success and not state.environment_state.opening_state(DOOR_ID).is_open(),
		"An adjacent actor must be able to close an unobstructed ordinary door for 5 ft.", failures)
	var blocked_peek: OperationResult = session.opening_handler.peek(actor.unit_id, DOOR_ID)
	_expect(not blocked_peek.success,
		"Peek through a solid closed door must be rejected.", failures)
	actor.refresh_for_new_round()
	var reopened: OperationResult = session.opening_handler.toggle_opening(actor.unit_id, DOOR_ID)
	actor.refresh_for_new_round()
	var peek_capacity_before: int = actor.action_budget.remaining_turn_capacity_feet
	var peeked: OperationResult = session.opening_handler.peek(actor.unit_id, DOOR_ID)
	_expect(reopened.success and peeked.success,
		"Opening a doorway must permit automatic free Peek visibility without moving the unit.", failures)
	_expect(actor.action_budget.remaining_turn_capacity_feet == peek_capacity_before,
		"Automatic Peek must not consume movement or action capacity.", failures)
	_expect(actor.grid_position == Vector2i(11, 4),
		"Peek must not move the observing character.", failures)
	_expect(session.opening_handler.lean_origin(actor.unit_id, DOOR_ID) != null,
		"An open doorway must expose an alternate Lean Attack origin.", failures)

	var lock_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var lock_state: TacticalState = lock_session.state_store.state
	var scout: TacticalUnitState = lock_state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	_place(lock_session, scout, Vector2i(10, 5), failures)
	scout.refresh_for_new_round()
	lock_session.screen_facade.set_combat_scripted_rolls_for_tests([20])
	var picked: OperationResult = lock_session.opening_handler.pick_lock(
		scout.unit_id, LOCKED_DOOR_ID
	)
	_expect(picked.success and bool(picked.data.get("success", false)),
		"Thievery plus lockpick tools must be able to unlock the authored locked door.", failures)
	_expect(not lock_state.environment_state.opening_state(LOCKED_DOOR_ID).locked,
		"A successful lockpick check must clear the authoritative locked state.", failures)


static func _test_corner_peek_and_lean_origin(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_place(session, actor, Vector2i(7, 2), failures)
	actor.refresh_for_new_round()
	var origin: Variant = session.opening_handler.corner_lean_origin(
		actor.unit_id, Vector2i(8, 2)
	)
	_expect(origin is Vector2,
		"A valid full-tile wall corner must expose a Lean Attack edge origin.", failures)
	var position_before: Vector2i = actor.grid_position
	var capacity_before: int = actor.action_budget.remaining_turn_capacity_feet
	var peeked: OperationResult = session.opening_handler.peek_around_corner(
		actor.unit_id, Vector2i(8, 2)
	)
	_expect(peeked.success,
		"A character beside a clear side of a wall must receive automatic Peek visibility.", failures)
	_expect(actor.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Automatic corner Peek must not consume movement or action capacity.", failures)
	_expect(actor.grid_position == position_before,
		"Corner Peek must not alter the actor's footprint.", failures)


static func _test_direct_structure_damage_breach_and_salvage(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_place(session, attacker, Vector2i(5, 4), failures)
	attacker.refresh_for_new_round()
	var action_id: StringName = _first_attack_id(session, attacker, AttackDefinition.ATTACK_MELEE)
	if action_id.is_empty():
		failures.append("The structure-damage fixture needs a melee weapon attack.")
		return
	var runtime: TacticalStructureState = state.environment_state.structure_state(BARRICADE_ID)
	runtime.current_hp = 1
	runtime.integrity_state_id = TacticalStructureDefinition.STATE_INTACT
	var preview: Dictionary = session.structure_attack_handler.preview(
		attacker.unit_id, BARRICADE_ID, action_id
	)
	_expect(bool(preview.get("success", false)),
		"An adjacent damageable barricade must be a legal environment target.", failures)
	if not bool(preview.get("success", false)):
		return
	session.screen_facade.set_combat_scripted_rolls_for_tests([20, 8])
	var result: OperationResult = session.structure_attack_handler.execute(preview)
	_expect(result.success,
		"A direct attack against the barricade must resolve through AC, Hardness and HP.", failures)
	_expect(runtime.integrity_state_id == TacticalStructureDefinition.STATE_DESTROYED,
		"Reducing the barricade to 0 HP must change its integrity to Destroyed.", failures)
	_expect(not state.environment_state.edge_blocks_movement(
		session.map_definition, Vector2i(5, 4), Vector2i(6, 4)
	), "Destroying the barricade must create a passable route.", failures)
	_expect(state.environment_state.is_dynamic_difficult(session.map_definition, Vector2i(5, 4)),
		"Destroyed cover must leave difficult rubble terrain.", failures)
	_expect(state.get_item(&"instance.salvage.structure.farm.wooden_barricade") != null,
		"Destroying the barricade must create one persistent structural-salvage item.", failures)
	var repeat_preview: Dictionary = session.structure_attack_handler.preview(
		attacker.unit_id, BARRICADE_ID, action_id
	)
	_expect(not bool(repeat_preview.get("success", false)),
		"A destroyed structure must not be attacked or generate salvage again.", failures)


static func _test_environment_snapshot_restore(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var environment: TacticalEnvironmentState = session.state_store.state.environment_state
	var snapshot: Dictionary = environment.snapshot()
	var revision_before: int = environment.geometry_revision
	environment.open_door(DOOR_ID)
	environment.apply_damage_to_source(session.map_definition, BARRICADE_ID, 20)
	_expect(environment.geometry_revision > revision_before,
		"Geometry-changing opening and integrity changes must increment geometry revision.", failures)
	environment.restore(snapshot)
	_expect(environment.geometry_revision == revision_before,
		"Environment restore must recover the saved geometry revision exactly.", failures)
	_expect(not environment.opening_state(DOOR_ID).is_open(),
		"Environment restore must recover the saved closed-door state.", failures)
	_expect(environment.structure_state(BARRICADE_ID).integrity_state_id == TacticalStructureDefinition.STATE_INTACT,
		"Environment restore must recover structure HP and integrity without regenerating salvage.", failures)


static func _first_attack_id(
		session: TacticalSession,
		unit: TacticalUnitState,
		attack_kind: StringName
) -> StringName:
	for action_id: StringName in session.state_store.state.granted_action_ids_for_unit(unit.unit_id):
		var attack: AttackDefinition = session.content_catalogue.attack_definition(action_id)
		if attack != null and attack.attack_kind == attack_kind and attack.damage_profile != null:
			return action_id
	return &""


static func _place(
		session: TacticalSession,
		unit: TacticalUnitState,
		tile: Vector2i,
		failures: Array[String]
) -> void:
	if unit == null:
		failures.append("A Stage 4.4 fixture unit is missing.")
		return
	var moved: bool = session.state_store.state.set_unit_position(
		unit.unit_id, tile, session.map_definition, false
	)
	_expect(moved, "%s could not be placed at %s for the Stage 4.4 fixture." % [unit.display_name, tile], failures)
	session.state_store.state.rebuild_unit_occupancy()


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
