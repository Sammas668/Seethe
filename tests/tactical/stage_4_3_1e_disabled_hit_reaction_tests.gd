class_name Stage431eDisabledHitReactionTests
extends RefCounted

const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_disabled_movement_does_not_worsen(failures)
	_test_disabled_action_cost_contract(failures)
	_test_disabled_attack_and_post_commit_damage_event(failures)
	_test_miss_emits_no_damage_event(failures)
	return failures


static func _test_disabled_movement_does_not_worsen(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if unit == null:
		failures.append("The Disabled movement fixture needs the Marauder.")
		return
	_move_enemy_units_far_away(session)
	state.set_unit_position(
		unit.unit_id,
		Vector2i(10, 10),
		session.map_definition,
		false
	)
	unit.restore_damage_state(0, 0)
	unit.refresh_for_new_round()
	var result: OperationResult = session.screen_facade.execute_movement(
		unit.unit_id,
		Vector2i(13, 12),
		&"normal"
	)
	_expect(result.success, "A Disabled character must be allowed to move within its reduced capacity.", failures)
	_expect(
		unit.current_hp == 0 and unit.is_disabled(),
		"Ordinary movement at exactly 0 HP must not cause Disabled strain.",
		failures
	)
	_expect(
		unit.action_budget.remaining_turn_capacity_feet >= 0,
		"Disabled movement must consume capacity without producing a negative budget.",
		failures
	)


static func _test_disabled_action_cost_contract(
	failures: Array[String]
) -> void:
	var quick_unit := _disabled_unit(&"disabled.quick", "Disabled Quick")
	var quick_spent: int = ActionEconomyRules.spend_with_disabled_strain(
		quick_unit,
		ActionCost.quick_action()
	)
	_expect(quick_spent == 0, "A Disabled character retains one Quick Action.", failures)
	_expect(
		quick_unit.current_hp == 0 and quick_unit.is_disabled(),
		"A normal Quick Action must not automatically worsen Disabled.",
		failures
	)

	var minor_unit := _disabled_unit(&"disabled.minor", "Disabled Minor")
	var minor_spent: int = ActionEconomyRules.spend_with_disabled_strain(
		minor_unit,
		ActionCost.minor_interaction()
	)
	_expect(minor_spent == 5, "A Disabled Minor Interaction must still cost 5 feet.", failures)
	_expect(
		minor_unit.current_hp == 0 and minor_unit.is_disabled(),
		"A normal Minor Interaction must not automatically worsen Disabled.",
		failures
	)

	var half_unit := _disabled_unit(&"disabled.half", "Disabled Half")
	var half_spent: int = ActionEconomyRules.spend_with_disabled_strain(
		half_unit,
		ActionCost.half_action()
	)
	_expect(half_spent == 20, "A Disabled 40-foot character must spend 20 feet on a Half Action.", failures)
	_expect(
		half_unit.current_hp == -1 and half_unit.is_dying(),
		"A strenuous Half Action must resolve and then reduce a Disabled character to -1 HP.",
		failures
	)

	var full_unit := _disabled_unit(&"disabled.full", "Disabled Full")
	_expect(
		not ActionEconomyRules.can_spend(full_unit, ActionCost.full_action()),
		"Disabled characters must not be allowed to take Full Actions.",
		failures
	)
	_expect(
		not full_unit.action_budget.reaction_available,
		"Disabled characters must have no Reaction.",
		failures
	)


static func _test_disabled_attack_and_post_commit_damage_event(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.PRACTICE_DUMMY_ID)
	if attacker == null or target == null:
		failures.append("The Disabled attack fixture needs the Marauder and Practice Dummy.")
		return
	attacker.restore_damage_state(0, 0)
	attacker.refresh_for_new_round()
	var target_hp_before: int = target.current_hp
	var observations: Dictionary = {}
	session.screen_facade.damage_committed.connect(
		func(event: Dictionary) -> void:
			observations["event"] = event.duplicate(true)
			observations["target_hp"] = target.current_hp
			var latest_value: Variant = session.event_journal.call(
				"latest_event",
				&"combat"
			)
			observations["log_event"] = (
				latest_value.duplicate(true)
				if latest_value is Dictionary
				else {}
			)
	)
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 1])
	var preview: Variant = session.screen_facade.preview_attack(
		attacker.unit_id,
		target.unit_id,
		AXE_ACTION_ID,
		0
	)
	_expect(
		preview != null and bool(preview.get("success")),
		"A Disabled character with one Half Action remaining must be able to preview an attack.",
		failures
	)
	if preview == null or not bool(preview.get("success")):
		return
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	_expect(result.success, "The Disabled attack must commit successfully.", failures)
	_expect(
		target.current_hp < target_hp_before,
		"The target must take committed damage before the Disabled attacker falls Dying.",
		failures
	)
	_expect(
		attacker.current_hp == -1 and attacker.is_dying(),
		"After the attack resolves, Disabled strain must reduce the attacker to -1 HP.",
		failures
	)
	var event: Dictionary = observations.get("event", {})
	_expect(not event.is_empty(), "Committed positive damage must emit one damage event.", failures)
	_expect(
		StringName(event.get("target_id", &"")) == target.unit_id,
		"The damage event must identify the damaged token.",
		failures
	)
	_expect(
		int(observations.get("target_hp", target_hp_before)) == target.current_hp,
		"The damage event must observe the final committed HP value.",
		failures
	)
	var log_event: Dictionary = observations.get("log_event", {})
	_expect(
		StringName(log_event.get("event_type", &"")) == &"attack_resolved",
		"The combat log must already contain the attack when the damage presentation event fires.",
		failures
	)


static func _test_miss_emits_no_damage_event(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var event_count: Dictionary = {"value": 0}
	session.screen_facade.damage_committed.connect(
		func(_event: Dictionary) -> void:
			event_count["value"] = int(event_count.get("value", 0)) + 1
	)
	session.screen_facade.set_combat_scripted_rolls_for_tests([1])
	var preview: Variant = session.screen_facade.preview_attack(
		TacticalSandboxFactory.MARAUDER_ID,
		TacticalSandboxFactory.PRACTICE_DUMMY_ID,
		AXE_ACTION_ID,
		0
	)
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	_expect(result.success, "A miss must still resolve its action transaction.", failures)
	_expect(
		int(event_count.get("value", 0)) == 0,
		"A miss or zero applied damage must not trigger a token hit reaction.",
		failures
	)


static func _disabled_unit(unit_id: StringName, display_name: String) -> TacticalUnitState:
	var unit := TacticalUnitState.new(
		unit_id,
		display_name,
		Vector2i(1, 1),
		40,
		&"player",
		12,
		10
	)
	unit.restore_damage_state(0, 0)
	unit.refresh_for_new_round()
	return unit


static func _move_enemy_units_far_away(session: TacticalSession) -> void:
	var offset: int = 0
	for unit: TacticalUnitState in session.state_store.state.get_enemy_units():
		session.state_store.state.set_unit_position(
			unit.unit_id,
			Vector2i(50 + offset, 50),
			session.map_definition,
			false
		)
		offset += 2
	session.visibility_service.call("recalculate_all_teams")


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
