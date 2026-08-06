class_name Stage426InitiativeLifecycleAITests
extends RefCounted

const RESOLVED_STAT_SCRIPT: Script = preload(
	"res://domain/characters/resolution/resolved_stat.gd"
)
const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_contact_round_preservation_and_round_refresh(failures)
	_test_new_squad_joins_at_next_round_boundary(failures)
	_test_unrelated_aware_squad_stays_out_of_contact(failures)
	_test_ineligible_and_removed_participants_advance_safely(failures)
	_test_melee_and_ranged_enemy_planners(failures)
	_test_five_round_two_squad_combat_and_clean_end(failures)
	return failures


static func _test_contact_round_preservation_and_round_refresh(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var facade = session.screen_facade
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var archer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var scout: TacticalUnitState = state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	if marauder == null or archer == null or scout == null or guard == null or squad == null:
		failures.append("The contact-round fixture is incomplete.")
		return

	_set_initiative_profile(archer, 2, 16)
	_set_initiative_profile(marauder, 2, 14)
	_set_initiative_profile(scout, 1, 20)
	_set_initiative_profile(guard, 0, 12)
	marauder.action_budget.spend_normal_capacity(20)
	marauder.action_budget.spend_quick_action()
	marauder.action_budget.reaction_available = false
	squad.make_aware()
	marauder.reveal_to_squad(squad.squad_id)

	var participants: Array[StringName] = [
		marauder.unit_id,
		archer.unit_id,
		scout.unit_id,
		guard.unit_id,
	]
	var totals: Dictionary = {
		marauder.unit_id: 20,
		archer.unit_id: 20,
		scout.unit_id: 20,
		guard.unit_id: 10,
	}
	_expect(
		state.begin_initiative_combat(participants, totals),
		"The contact-round fixture must enter initiative.",
		failures
	)
	_expect(
		state.phase_state.initiative_order.size() >= 3
		and state.phase_state.initiative_order[0] == archer.unit_id
		and state.phase_state.initiative_order[1] == marauder.unit_id
		and state.phase_state.initiative_order[2] == scout.unit_id,
		"Initiative ties must resolve by modifier, then Dexterity, then stable unit ID.",
		failures
	)
	_expect(
		marauder.action_budget.remaining_turn_capacity_feet
		== marauder.action_budget.maximum_turn_capacity_feet - 20,
		"Contact initiative must preserve normal capacity already spent.",
		failures
	)
	_expect(
		not marauder.action_budget.quick_action_available
		and not marauder.action_budget.reaction_available,
		"Contact initiative must preserve spent Quick Actions and Reactions.",
		failures
	)

	var contact_round: int = state.phase_state.round_number
	var safety: int = 0
	while (
		state.phase_state.is_initiative_combat()
		and state.phase_state.round_number == contact_round
		and safety < 12
	):
		var active_id: StringName = state.phase_state.active_unit_id()
		var ended: OperationResult = facade.end_initiative_turn(active_id)
		_expect(ended.success, "Every contact-round participant must end safely.", failures)
		safety += 1
	_expect(safety < 12, "The contact round must reach its next round boundary.", failures)
	_expect(
		state.phase_state.is_initiative_combat()
		and not state.phase_state.contact_round_active,
		"The following full combat round must remain in initiative and clear contact-round status.",
		failures
	)
	_expect(
		marauder.action_budget.remaining_turn_capacity_feet
		== marauder.action_budget.maximum_turn_capacity_feet,
		"Normal capacity must refresh at the next full combat round.",
		failures
	)
	_expect(
		marauder.action_budget.quick_action_available
		and marauder.action_budget.reaction_available,
		"Quick Actions and Reactions must refresh at the next full combat round.",
		failures
	)


static func _test_new_squad_joins_at_next_round_boundary(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	_split_archer_into_secondary_squad(state)
	var facade = session.screen_facade
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var hidden_archer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var guard_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var guard_b: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	var squad_a: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	var squad_b: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_B_ID
	)
	if (
		marauder == null or hidden_archer == null
		or guard_a == null or guard_b == null
		or squad_a == null or squad_b == null
	):
		failures.append("The joining-squad fixture is incomplete.")
		return

	squad_a.make_aware()
	marauder.reveal_to_squad(squad_a.squad_id)
	hidden_archer.enter_stealth()
	hidden_archer.clear_revelation()
	hidden_archer.set_current_stealth_roll(20, 20 + hidden_archer.stealth_bonus())
	var opening_ids: Array[StringName] = [
		marauder.unit_id,
		hidden_archer.unit_id,
		guard_a.unit_id,
	]
	var opening_totals: Dictionary = {
		marauder.unit_id: 18,
		hidden_archer.unit_id: 16,
		guard_a.unit_id: 12,
	}
	_expect(
		state.begin_initiative_combat(opening_ids, opening_totals),
		"The initial squad must begin initiative combat.",
		failures
	)

	squad_b.make_aware()
	marauder.reveal_to_squad(squad_b.squad_id)
	guard_b.action_budget.spend_normal_capacity(10)
	var joining_ids: Array[StringName] = [guard_b.unit_id]
	state.append_initiative_participants(
		joining_ids,
		{guard_b.unit_id: 22}
	)
	_expect(
		state.phase_state.pending_initiative_unit_ids.has(guard_b.unit_id)
		and not state.phase_state.initiative_order.has(guard_b.unit_id),
		"A newly aware squad must be queued immediately without acting in the partial round.",
		failures
	)
	_expect(
		not hidden_archer.is_revealed_to_squad(squad_b.squad_id),
		"Joining initiative must not reveal a hidden player character to the new squad.",
		failures
	)

	var opening_round: int = state.phase_state.round_number
	var safety: int = 0
	while state.phase_state.round_number == opening_round and safety < 10:
		var active_id: StringName = state.phase_state.active_unit_id()
		var ended: OperationResult = facade.end_initiative_turn(active_id)
		_expect(ended.success, "The partial round must advance safely.", failures)
		safety += 1
	_expect(
		state.phase_state.initiative_order.has(guard_b.unit_id)
		and not state.phase_state.pending_initiative_unit_ids.has(guard_b.unit_id),
		"The newly aware guard must enter the active order at the next round boundary.",
		failures
	)
	_expect(
		guard_b.action_budget.remaining_turn_capacity_feet
		== guard_b.action_budget.maximum_turn_capacity_feet,
		"A newly joined unit must receive its first refreshed activation at the new round.",
		failures
	)


static func _test_unrelated_aware_squad_stays_out_of_contact(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	_split_archer_into_secondary_squad(state)
	var marauder: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var guard_a: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	var guard_b: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_TWO_ID
	)
	var squad_a: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	var squad_b: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_B_ID
	)
	if (
		marauder == null or guard_a == null or guard_b == null
		or squad_a == null or squad_b == null
	):
		failures.append("The squad-limited contact fixture is incomplete.")
		return

	# Squad B remembers an earlier encounter and is still Aware, but it is not
	# currently observing this contact and must not be pulled into combat merely
	# because awareness persists between encounters.
	squad_b.make_aware()
	var resolution := TacticalDetectionResolution.new()
	resolution.unit_id = marauder.unit_id
	resolution.alert_on_detection = true
	resolution.detected_squad_ids.append(squad_a.squad_id)
	var resolver := ContactInitiativeResolver.new()
	resolver.configure(
		session.state_store,
		session.combat_dice_roller as TacticalDiceRoller
	)
	session.combat_dice_roller.call(
		"set_scripted_results",
		[12, 11, 10, 9]
	)
	resolver.finalize_resolution(marauder, resolution)

	_expect(
		resolution.initiative_totals_by_unit_id.has(guard_a.unit_id),
		"The detecting squad must roll initiative for contact.",
		failures
	)
	_expect(
		not resolution.initiative_totals_by_unit_id.has(guard_b.unit_id),
		"A distant Aware squad must remain outside an unrelated new contact.",
		failures
	)

	# Persistent search state on that unrelated squad must not keep another
	# encounter alive. Only participating enemy squads determine combat ending.
	squad_a.make_aware()
	squad_b.begin_search()
	var contact_ids: Array[StringName] = []
	for participant_value: Variant in resolution.initiative_totals_by_unit_id.keys():
		contact_ids.append(StringName(participant_value))
	_expect(
		state.begin_initiative_combat(
			contact_ids,
			resolution.initiative_totals_by_unit_id
		),
		"The squad-limited contact fixture must enter initiative.",
		failures
	)
	_expect(
		state.should_end_initiative_combat(),
		"A non-participating Aware squad must not keep an unrelated combat active.",
		failures
	)



static func _test_ineligible_and_removed_participants_advance_safely(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var facade = session.screen_facade
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var archer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var scout: TacticalUnitState = state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	if marauder == null or archer == null or scout == null or guard == null or squad == null:
		failures.append("The initiative-removal fixture is incomplete.")
		return
	squad.make_aware()
	var revealed_players: Array[TacticalUnitState] = [marauder, archer, scout]
	for player: TacticalUnitState in revealed_players:
		player.reveal_to_squad(squad.squad_id)
	var ids: Array[StringName] = [
		marauder.unit_id,
		archer.unit_id,
		scout.unit_id,
		guard.unit_id,
	]
	var totals: Dictionary = {
		marauder.unit_id: 40,
		archer.unit_id: 30,
		scout.unit_id: 20,
		guard.unit_id: 10,
	}
	_expect(state.begin_initiative_combat(ids, totals), "The removal fixture must enter initiative.", failures)
	marauder.set_action_incapacitated(true)
	var normalized: OperationResult = facade.normalize_initiative()
	_expect(normalized.success, "An incapacitated active unit must be skipped safely.", failures)
	_expect(
		state.phase_state.active_unit_id() == archer.unit_id,
		"The next eligible unit must become active after an incapacitated participant is skipped.",
		failures
	)
	_expect(
		state.remove_unit(archer.unit_id),
		"Removing the active initiative unit must succeed.",
		failures
	)
	_expect(
		state.phase_state.is_initiative_combat()
		and state.phase_state.active_unit_id() == scout.unit_id,
		"Removing the active unit must advance safely to the next participant.",
		failures
	)
	_expect(
		state.validate_phase_invariants().is_empty(),
		"Skipping and removing participants must preserve initiative invariants.",
		failures
	)


static func _test_melee_and_ranged_enemy_planners(
	failures: Array[String]
) -> void:
	_test_melee_guard_planner(failures)
	_test_archer_planner(failures)


static func _test_melee_guard_planner(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	if guard == null or target == null or squad == null:
		failures.append("The melee planner fixture is incomplete.")
		return
	_move_unrelated_units_far_away(session, [guard.unit_id, target.unit_id], failures)
	_move_or_fail(state, guard, Vector2i(30, 20), session.map_definition, failures)
	_move_or_fail(state, target, Vector2i(33, 20), session.map_definition, failures)
	squad.make_aware()
	target.reveal_to_squad(squad.squad_id)
	session.visibility_service.call("recalculate_all_teams", true)
	var guard_ids: Array[StringName] = [guard.unit_id]
	_expect(
		state.begin_initiative_combat(guard_ids, {guard.unit_id: 20}),
		"The melee guard fixture must enter initiative.",
		failures
	)
	session.combat_dice_roller.call("set_scripted_results", [1])
	var before_distance: int = TacticalGridDistance.steps_between(
		guard.grid_position,
		target.grid_position
	)
	var result: OperationResult = session.screen_facade.resolve_active_ai_initiative()
	_expect(result.success, "The melee guard must resolve its combat plan.", failures)
	_expect(
		TacticalGridDistance.steps_between(guard.grid_position, target.grid_position)
		< before_distance,
		"The melee guard must approach the closest revealed hostile.",
		failures
	)
	_expect(
		not guard.action_budget.ordinary_attack_available,
		"The melee guard must attack after moving when sufficient capacity remains.",
		failures
	)


static func _test_archer_planner(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	_split_archer_into_secondary_squad(state)
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_B_ID
	)
	if guard == null or target == null or squad == null:
		failures.append("The archer planner fixture is incomplete.")
		return
	_move_unrelated_units_far_away(session, [guard.unit_id, target.unit_id], failures)
	_move_or_fail(state, guard, Vector2i(30, 30), session.map_definition, failures)
	_move_or_fail(state, target, Vector2i(35, 30), session.map_definition, failures)
	squad.make_aware()
	target.reveal_to_squad(squad.squad_id)
	session.visibility_service.call("recalculate_all_teams", true)
	var guard_ids: Array[StringName] = [guard.unit_id]
	_expect(
		state.begin_initiative_combat(guard_ids, {guard.unit_id: 20}),
		"The archer fixture must enter initiative.",
		failures
	)
	session.combat_dice_roller.call("set_scripted_results", [1])
	var origin: Vector2i = guard.grid_position
	var result: OperationResult = session.screen_facade.resolve_active_ai_initiative()
	_expect(result.success, "The archer must resolve its ranged combat plan.", failures)
	_expect(
		guard.grid_position == origin,
		"An archer with a legal shot must attack from its current position.",
		failures
	)
	_expect(
		not guard.action_budget.ordinary_attack_available,
		"The archer must use its supported ranged weapon attack.",
		failures
	)


static func _test_five_round_two_squad_combat_and_clean_end(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	_split_archer_into_secondary_squad(state)
	var facade = session.screen_facade
	var marauder: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var hidden_archer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var guard_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var guard_b: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	var squad_a: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	var squad_b: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_B_ID
	)
	if (
		marauder == null or hidden_archer == null
		or guard_a == null or guard_b == null
		or squad_a == null or squad_b == null
	):
		failures.append("The five-round combat fixture is incomplete.")
		return
	_move_unrelated_units_far_away(
		session,
		[marauder.unit_id, hidden_archer.unit_id, guard_a.unit_id, guard_b.unit_id],
		failures
	)
	_move_or_fail(state, marauder, Vector2i(30, 20), session.map_definition, failures)
	_move_or_fail(state, hidden_archer, Vector2i(35, 24), session.map_definition, failures)
	_move_or_fail(state, guard_a, Vector2i(36, 20), session.map_definition, failures)
	_move_or_fail(state, guard_b, Vector2i(36, 24), session.map_definition, failures)
	squad_a.make_aware()
	squad_b.make_aware()
	marauder.leave_stealth()
	marauder.reveal_to_squad(squad_a.squad_id)
	marauder.reveal_to_squad(squad_b.squad_id)
	hidden_archer.enter_stealth()
	hidden_archer.clear_revelation()
	hidden_archer.set_current_stealth_roll(
		20,
		20 + hidden_archer.stealth_bonus()
	)
	session.visibility_service.call("recalculate_all_teams", true)
	var ids: Array[StringName] = [
		marauder.unit_id,
		hidden_archer.unit_id,
		guard_a.unit_id,
		guard_b.unit_id,
	]
	var totals: Dictionary = {
		marauder.unit_id: 24,
		hidden_archer.unit_id: 20,
		guard_a.unit_id: 16,
		guard_b.unit_id: 12,
	}
	_expect(state.begin_initiative_combat(ids, totals), "The stress fixture must enter initiative.", failures)
	var scripted_misses: Array[int] = []
	for _index: int in range(256):
		scripted_misses.append(1)
	session.combat_dice_roller.call("set_scripted_results", scripted_misses)
	var hidden_hp_before: int = hidden_archer.current_hp
	var target_round: int = state.phase_state.round_number + 5
	var safety: int = 0
	while (
		state.phase_state.is_initiative_combat()
		and state.phase_state.round_number < target_round
		and safety < 80
	):
		var active: TacticalUnitState = state.active_initiative_unit()
		if active == null:
			var normalized: OperationResult = facade.normalize_initiative()
			_expect(normalized.success, "A missing active participant must normalize safely.", failures)
		else:
			if active.is_ai_controlled():
				var ai_result: OperationResult = facade.resolve_active_ai_initiative()
				_expect(ai_result.success, "Every AI activation in the stress test must resolve.", failures)
			var ended: OperationResult = facade.end_initiative_turn(active.unit_id)
			_expect(ended.success, "Every stress-test activation must advance.", failures)
		_expect(
			state.validate_phase_invariants().is_empty()
			and state.rebuild_unit_occupancy().is_empty(),
			"Five-round combat must preserve turn order and non-overlapping destinations.",
			failures
		)
		safety += 1
	_expect(
		state.phase_state.is_initiative_combat()
		and state.phase_state.round_number >= target_round,
		"Two player characters and two enemy squads must complete at least five combat rounds.",
		failures
	)
	_expect(
		hidden_archer.current_hp == hidden_hp_before
		and not hidden_archer.is_revealed_to_squad(squad_a.squad_id)
		and not hidden_archer.is_revealed_to_squad(squad_b.squad_id),
		"Enemy AI must not target or reveal a closer hidden character without perception.",
		failures
	)

	var last_seen: Vector2i = marauder.grid_position
	marauder.conceal_from_squad(squad_a.squad_id)
	marauder.conceal_from_squad(squad_b.squad_id)
	marauder.enter_stealth()
	marauder.set_current_stealth_roll(20, 20 + marauder.stealth_bonus())
	squad_a.remember_last_seen(marauder.unit_id, last_seen)
	squad_b.remember_last_seen(marauder.unit_id, last_seen)
	squad_a.begin_search()
	squad_b.begin_search()
	_move_or_fail(state, marauder, Vector2i(2, 50), session.map_definition, failures)
	_move_or_fail(state, hidden_archer, Vector2i(5, 50), session.map_definition, failures)
	session.visibility_service.call("recalculate_all_teams", true)
	var end_safety: int = 0
	while state.phase_state.is_initiative_combat() and end_safety < 40:
		var active: TacticalUnitState = state.active_initiative_unit()
		if active != null and active.is_ai_controlled():
			var ai_result: OperationResult = facade.resolve_active_ai_initiative()
			_expect(ai_result.success, "Search activations must resolve while combat winds down.", failures)
		if active != null:
			var ended: OperationResult = facade.end_initiative_turn(active.unit_id)
			_expect(ended.success, "Search turns must advance toward combat termination.", failures)
		else:
			var normalized: OperationResult = facade.normalize_initiative()
			_expect(normalized.success, "Combat termination must normalize missing actors.", failures)
		end_safety += 1
	_expect(
		state.phase_state.is_side_based()
		and state.phase_state.is_player_phase(),
		"Combat must end cleanly after all revealed targets are lost and bounded searches expire.",
		failures
	)
	_expect(
		squad_a.is_aware() and squad_b.is_aware(),
		"Squads must remain Aware after returning to side-based turns.",
		failures
	)


static func _set_initiative_profile(
	unit: TacticalUnitState,
	modifier: int,
	dexterity: int
) -> void:
	if unit == null or unit.resolved_character == null:
		return
	unit.resolved_character.ability_scores["DEX"] = dexterity
	var stat: RefCounted = RESOLVED_STAT_SCRIPT.new() as RefCounted
	stat.call("configure", &"initiative", "Initiative")
	stat.set("final_value", modifier)
	unit.resolved_character.stats_by_id[&"initiative"] = stat


static func _split_archer_into_secondary_squad(
	state: TacticalState
) -> void:
	# The live sandbox correctly keeps the generated guard and archer together.
	# These legacy Stage 4.2.6 fixtures deliberately split the archer into a
	# second squad only when exercising join-later and two-squad behaviour.
	if state == null:
		return
	var squad_a: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	var squad_b: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_B_ID
	)
	var archer: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_TWO_ID
	)
	var dummy: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.PRACTICE_DUMMY_ID
	)
	if squad_a == null or squad_b == null or archer == null:
		return
	squad_a.member_unit_ids.erase(archer.unit_id)
	squad_b.member_unit_ids.clear()
	squad_b.add_member(archer.unit_id)
	archer.squad_id = squad_b.squad_id
	if dummy != null:
		dummy.squad_id = &""


static func _move_unrelated_units_far_away(
	session: TacticalSession,
	kept_ids: Array[StringName],
	failures: Array[String]
) -> void:
	var state: TacticalState = session.state_store.state
	var next_x: int = 45
	var next_y: int = 55
	for unit: TacticalUnitState in state.get_units():
		if kept_ids.has(unit.unit_id):
			continue
		_move_or_fail(
			state,
			unit,
			Vector2i(next_x, next_y),
			session.map_definition,
			failures
		)
		next_x += 2
		if next_x > 59:
			next_x = 45
			next_y -= 2


static func _move_or_fail(
	state: TacticalState,
	unit: TacticalUnitState,
	tile: Vector2i,
	map_definition: TacticalMapDefinition,
	failures: Array[String]
) -> void:
	if unit == null:
		failures.append("A test attempted to move a missing unit.")
		return
	_expect(
		state.set_unit_position(unit.unit_id, tile, map_definition, false),
		"%s could not be placed at %s for the initiative fixture."
		% [unit.display_name, tile],
		failures
	)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
