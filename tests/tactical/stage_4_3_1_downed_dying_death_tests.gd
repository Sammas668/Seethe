class_name Stage431DownedDyingDeathTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_hp_state_ladder_and_disabled_strain(failures)
	_test_dying_success_failure_and_natural_results(failures)
	_test_first_aid_and_healing_transitions(failures)
	_test_nonlethal_unconsciousness_and_reopened_dying(failures)
	_test_initiative_dying_turn_and_body_persistence(failures)
	_test_squad_awareness_survives_downed_member(failures)
	return failures


static func _test_hp_state_ladder_and_disabled_strain(
	failures: Array[String]
) -> void:
	var unit := TacticalUnitState.new(
		&"life.state.fixture",
		"Life State Fixture",
		Vector2i(1, 1),
		40,
		&"player",
		12,
		10
	)
	_expect(
		unit.life_state_id() == TacticalUnitState.LIFE_STATE_NORMAL,
		"A character above 0 HP must be in the Normal life state.",
		failures
	)
	unit.apply_damage(12)
	_expect(unit.current_hp == 0, "Lethal damage must be allowed to reach exactly 0 HP.", failures)
	_expect(unit.is_disabled(), "A character at exactly 0 HP must be Disabled, not unconscious.", failures)
	unit.refresh_for_new_round()
	_expect(
		unit.action_budget.remaining_turn_capacity_feet == 20,
		"A Disabled 40-foot character must refresh to 20 feet of capacity.",
		failures
	)
	_expect(
		not unit.action_budget.reaction_available,
		"Disabled characters must have no Reaction.",
		failures
	)
	unit.apply_disabled_strain()
	_expect(unit.current_hp == -1, "Disabled strain must reduce HP to -1 after the action.", failures)
	_expect(unit.is_dying(), "A living character below 0 HP must become Dying.", failures)

	var threshold: int = unit.death_threshold_hp()
	unit.restore_damage_state(threshold, 0)
	_expect(unit.is_dead(), "A character at negative Constitution must die immediately.", failures)


static func _test_dying_success_failure_and_natural_results(
	failures: Array[String]
) -> void:
	var success_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var success_unit: TacticalUnitState = success_session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_prepare_dying_unit(success_session, success_unit, -3, 2, 0)
	success_session.combat_dice_roller.call("set_scripted_results", [20])
	var success_result: OperationResult = (
		success_session.life_state_handler.resolve_dying_check(success_unit.unit_id)
	)
	_expect(success_result.success, "A scripted natural 20 Dying check must resolve.", failures)
	_expect(
		success_unit.current_hp == -2,
		"A natural 20 Dying check must restore exactly 1 HP.",
		failures
	)
	_expect(
		success_unit.is_stable_unconscious(),
		"A natural 20 that remains below 0 HP must leave the character Stable.",
		failures
	)
	_expect(
		success_unit.dying_successes == 0 and success_unit.dying_failures == 0,
		"Becoming Stable must clear the completed Dying track.",
		failures
	)

	var failure_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var failure_unit: TacticalUnitState = failure_session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_prepare_dying_unit(failure_session, failure_unit, -2, 0, 1)
	failure_session.combat_dice_roller.call("set_scripted_results", [1])
	var failure_result: OperationResult = (
		failure_session.life_state_handler.resolve_dying_check(failure_unit.unit_id)
	)
	_expect(failure_result.success, "A scripted natural 1 Dying check must resolve.", failures)
	_expect(failure_unit.is_dead(), "A natural 1 must add two failures and kill at three.", failures)
	_expect(failure_unit.dying_failures == 3, "The fatal Dying track must retain three failures.", failures)

	var ordinary_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var ordinary_unit: TacticalUnitState = ordinary_session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_prepare_dying_unit(ordinary_session, ordinary_unit, -1, 0, 0)
	var needed: int = ordinary_unit.dying_check_dc() - ordinary_unit.fortitude_bonus()
	ordinary_session.combat_dice_roller.call(
		"set_scripted_results",
		[clampi(needed, 2, 19)]
	)
	var ordinary_result: OperationResult = (
		ordinary_session.life_state_handler.resolve_dying_check(ordinary_unit.unit_id)
	)
	_expect(ordinary_result.success, "An ordinary successful Dying check must resolve.", failures)
	_expect(
		ordinary_unit.dying_successes == 1 and ordinary_unit.is_dying(),
		"An ordinary success must add one success without stabilising before three.",
		failures
	)


static func _test_first_aid_and_healing_transitions(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	if actor == null or target == null:
		failures.append("The First Aid fixture requires two player characters.")
		return
	state.set_unit_position(actor.unit_id, Vector2i(2, 2), session.map_definition, false)
	state.set_unit_position(target.unit_id, Vector2i(2, 3), session.map_definition, false)
	target.restore_damage_state(-4, 0)
	var medicine_needed: int = clampi(10 - actor.medicine_bonus(), 2, 20)
	session.combat_dice_roller.call("set_scripted_results", [medicine_needed])
	var first_aid: OperationResult = session.life_state_handler.first_aid(
		actor.unit_id,
		target.unit_id
	)
	_expect(first_aid.success, "Adjacent First Aid must resolve through Medicine DC 10.", failures)
	_expect(target.is_stable_unconscious(), "Successful First Aid must make the target Stable.", failures)
	_expect(
		actor.action_budget.remaining_turn_capacity_feet
		== actor.action_budget.maximum_turn_capacity_feet / 2,
		"First Aid must spend one Half Action.",
		failures
	)

	var healing_to_negative: OperationResult = session.life_state_handler.apply_healing(
		target.unit_id,
		1,
		actor.unit_id
	)
	_expect(healing_to_negative.success, "Healing a living downed target must resolve.", failures)
	_expect(
		target.current_hp == -3 and target.is_stable_unconscious(),
		"Healing that remains below 0 HP must leave the target Stable.",
		failures
	)
	var healing_to_zero: OperationResult = session.life_state_handler.apply_healing(
		target.unit_id,
		3,
		actor.unit_id
	)
	_expect(healing_to_zero.success, "Healing to exactly 0 HP must resolve.", failures)
	_expect(target.current_hp == 0 and target.is_disabled(), "Healing to 0 HP must produce Disabled.", failures)
	var healing_to_positive: OperationResult = session.life_state_handler.apply_healing(
		target.unit_id,
		2,
		actor.unit_id
	)
	_expect(healing_to_positive.success, "Healing above 0 HP must resolve.", failures)
	_expect(
		target.current_hp == 2
		and target.life_state_id() == TacticalUnitState.LIFE_STATE_NORMAL,
		"Healing above 0 HP must wake the character into the Normal state.",
		failures
	)


static func _test_nonlethal_unconsciousness_and_reopened_dying(
	failures: Array[String]
) -> void:
	var unit := TacticalUnitState.new(
		&"nonlethal.fixture",
		"Nonlethal Fixture",
		Vector2i(1, 1),
		30,
		&"enemy",
		10,
		10
	)
	unit.apply_damage(11, TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL)
	_expect(
		unit.is_nonlethal_unconscious(),
		"Nonlethal damage greater than current HP must cause unconsciousness without Dying.",
		failures
	)
	_expect(
		unit.dying_successes == 0 and unit.dying_failures == 0,
		"Nonlethal unconsciousness must not start a Dying track.",
		failures
	)

	var stable := TacticalUnitState.new(
		&"stable.fixture",
		"Stable Fixture",
		Vector2i(2, 1),
		30,
		&"player",
		10,
		10
	)
	stable.restore_damage_state(-2, 0)
	stable.become_stable()
	stable.apply_damage(1)
	_expect(
		stable.current_hp == -3 and stable.is_dying(),
		"Further lethal damage must return a Stable negative-HP character to Dying.",
		failures
	)


static func _test_initiative_dying_turn_and_body_persistence(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var facade = session.screen_facade
	var downed: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var ally: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	if downed == null or ally == null or guard == null:
		failures.append("The initiative Dying fixture is incomplete.")
		return
	downed.restore_damage_state(-2, 0)
	var participants: Array[StringName] = [downed.unit_id, ally.unit_id, guard.unit_id]
	var totals: Dictionary = {
		downed.unit_id: 30,
		ally.unit_id: 20,
		guard.unit_id: 10,
	}
	_expect(
		state.begin_initiative_combat(participants, totals),
		"A Dying participant must be retained in initiative.",
		failures
	)
	var needed: int = clampi(
		downed.dying_check_dc() - downed.fortitude_bonus(),
		2,
		19
	)
	session.combat_dice_roller.call("set_scripted_results", [needed])
	var normalized: OperationResult = facade.normalize_initiative()
	_expect(normalized.success, "The active Dying turn must resolve and advance safely.", failures)
	_expect(
		downed.dying_successes == 1,
		"Start-of-turn initiative normalization must record the Dying success.",
		failures
	)
	_expect(
		state.get_unit(downed.unit_id) == downed
		and state.get_unit_at_tile(downed.grid_position) == downed,
		"A downed body must remain registered on its battlefield tile.",
		failures
	)
	_expect(
		state.phase_state.active_unit_id() != downed.unit_id,
		"A Dying character must not receive ordinary actions after the check.",
		failures
	)


static func _test_squad_awareness_survives_downed_member(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var guard: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	if guard == null or squad == null:
		failures.append("The squad-awareness body-state fixture is incomplete.")
		return
	squad.make_aware()
	guard.restore_damage_state(-2, 0)
	_expect(
		squad.is_aware(),
		"Downing one guard must not clear the authored squad's shared awareness.",
		failures
	)
	_expect(
		guard.is_dying() and guard.is_defeated(),
		"The downed guard must be Dying and unable to take ordinary actions.",
		failures
	)


static func _prepare_dying_unit(
	session: TacticalSession,
	unit: TacticalUnitState,
	hp: int,
	successes: int,
	failures_count: int
) -> void:
	unit.restore_damage_state(hp, 0)
	unit.dying_successes = clampi(successes, 0, 2)
	unit.dying_failures = clampi(failures_count, 0, 2)
	unit.stable = false
	unit.dead = false
	unit.last_dying_check_round = 0
	unit.restore_life_state(unit.life_state_snapshot())
	var state: TacticalState = session.state_store.state
	state.begin_initiative_combat(
		[unit.unit_id],
		{unit.unit_id: 20}
	)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
