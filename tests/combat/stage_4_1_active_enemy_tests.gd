class_name Stage41ActiveEnemyTests
extends RefCounted

const GUARD_ID: StringName = TacticalSandboxFactory.ENEMY_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const HAKON_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_guard_is_active_ai(failures)
	_test_guard_moves_and_attacks(failures)
	_test_downed_units_skip(failures)
	return failures


static func _test_guard_is_active_ai(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var guard: TacticalUnitState = session.state_store.state.get_unit(GUARD_ID)
	_expect(guard != null, "The Settlement Guard must be deployed.", failures)
	if guard == null:
		return
	_expect(guard.team_id == &"enemy", "The Guard must belong to the enemy team.", failures)
	_expect(guard.controller_type == TacticalUnitState.CONTROLLER_AI, "The Guard must be AI controlled.", failures)
	_expect(guard.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_STANDARD, "The Guard must use Standard Combat behaviour.", failures)
	_expect(guard.participates_in_enemy_turn, "The Guard must receive Enemy Turn activations.", failures)
	_expect(guard.counts_for_victory, "The Guard must count as a real hostile combatant.", failures)
	_expect(session.state_store.state.granted_action_ids_for_unit(GUARD_ID).has(&"action.training_spear_attack"), "The equipped Training Spear must grant the Guard's attack.", failures)


static func _test_guard_moves_and_attacks(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var guard: TacticalUnitState = state.get_unit(GUARD_ID)
	var origin: Vector2i = guard.grid_position
	var total_hp_before: int = 0
	for unit: TacticalUnitState in state.get_player_units():
		total_hp_before += unit.current_hp

	session.screen_facade.set_combat_scripted_rolls_for_tests([15, 4])
	var begin_result: OperationResult = session.screen_facade.begin_world_phase()
	_expect(begin_result.success, "The Player Phase must advance to the Enemy Turn.", failures)
	var enemy_result: OperationResult = session.screen_facade.resolve_enemy_turn()
	_expect(enemy_result.success, "The active enemy turn must resolve successfully.", failures)

	var total_hp_after: int = 0
	for unit: TacticalUnitState in state.get_player_units():
		total_hp_after += unit.current_hp
	_expect(guard.grid_position != origin, "The Guard must move toward a reachable player.", failures)
	_expect(total_hp_after < total_hp_before, "The Guard must resolve a real Training Spear attack against a player.", failures)
	_expect(not guard.action_budget.ordinary_attack_available, "The Guard must spend its one normal attack allowance.", failures)
	_expect(guard.action_budget.ended_activation, "The Guard must end its activation after acting.", failures)

	var combat_events_value: Variant = session.event_journal.call("events", &"combat", true)
	var combat_events: Array = combat_events_value if combat_events_value is Array else []
	var saw_guard_attack: bool = false
	for event_value: Variant in combat_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value as Dictionary
		if (
			StringName(event.get("source_actor_id", &"")) == GUARD_ID
			and StringName(event.get("action_id", &"")) == &"action.training_spear_attack"
		):
			saw_guard_attack = true
	_expect(saw_guard_attack, "The tactical log must contain the Guard's resolved attack.", failures)


static func _test_downed_units_skip(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var guard: TacticalUnitState = state.get_unit(GUARD_ID)
	var hakon: TacticalUnitState = state.get_unit(HAKON_ID)
	state.set_unit_position(GUARD_ID, Vector2i(3, 3), session.map_definition, false)
	guard.current_hp = 1
	guard.combat_state = TacticalUnitState.COMBAT_STATE_ACTIVE
	session.screen_facade.set_combat_scripted_rolls_for_tests([15, 8])
	var preview: Variant = session.screen_facade.preview_attack(
		HAKON_ID,
		GUARD_ID,
		AXE_ACTION_ID,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)
	_expect(preview != null and bool(preview.get("success")), "Hakon must be able to attack the adjacent Guard.", failures)
	if preview == null or not bool(preview.get("success")):
		return
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	_expect(result.success, "The defeating attack must commit.", failures)
	_expect(guard.current_hp < 0, "The Guard must be reduced below 0 HP.", failures)
	_expect(guard.is_dying(), "A living unit below 0 HP must become Dying.", failures)

	var guard_position: Vector2i = guard.grid_position
	var begin_result: OperationResult = session.screen_facade.begin_world_phase()
	_expect(begin_result.success, "The Enemy Turn must begin after the Guard is downed.", failures)
	var enemy_result: OperationResult = session.screen_facade.resolve_enemy_turn()
	_expect(enemy_result.success, "Downed enemy activations must skip safely.", failures)
	_expect(guard.grid_position == guard_position, "A downed Guard must not move.", failures)
	_expect(guard.action_budget.ended_activation, "A downed Guard must finish its skipped activation.", failures)
	_expect(hakon.current_hp == hakon.maximum_hp, "A downed Guard must not attack Hakon.", failures)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
