class_name Stage413CombatIntegrityTests
extends RefCounted

const HAKON_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const NEUTRAL_ID: StringName = TacticalSandboxFactory.NEUTRAL_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_failed_commit_restores_dice_stream(failures)
	_test_definition_capabilities_replace_weapon_whitelist(failures)
	_test_enemy_failure_finalizes_and_continues(failures)
	return failures


static func _test_failed_commit_restores_dice_stream(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(HAKON_ID)
	var target: TacticalUnitState = state.get_unit(DUMMY_ID)
	var neutral: TacticalUnitState = state.get_unit(NEUTRAL_ID)
	var preview: Variant = session.screen_facade.preview_attack(
		HAKON_ID,
		DUMMY_ID,
		AXE_ACTION_ID,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)
	_expect(
		preview != null and bool(preview.get("success")),
		"The deterministic rollback test requires a legal Axe preview.",
		failures
	)
	if preview == null or not bool(preview.get("success")):
		return

	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 6])
	neutral.nonlethal_damage = -1
	var failed: OperationResult = session.screen_facade.execute_attack_preview(
		preview
	)
	_expect(not failed.success, "The deliberately invalid state must reject commit.", failures)
	_expect(target.current_hp == 60, "Failed commit must restore target HP.", failures)
	_expect(
		attacker.action_budget.remaining_turn_capacity_feet == 80,
		"Failed commit must restore attack capacity.",
		failures
	)
	_expect(
		attacker.action_budget.ordinary_attack_available,
		"Failed commit must restore the normal attack allowance.",
		failures
	)

	neutral.nonlethal_damage = 0
	var retried: OperationResult = session.screen_facade.execute_attack_preview(
		preview
	)
	_expect(retried.success, "The corrected retry must commit.", failures)
	if retried.success:
		var resolution: Variant = retried.data
		_expect(
			int(resolution.get("attack_roll")) == 12,
			"A failed post-roll commit must restore the scripted d20 result.",
			failures
		)
		_expect(
			int(resolution.get("final_damage")) == 8,
			"A failed post-roll commit must restore the scripted damage die.",
			failures
		)


static func _test_definition_capabilities_replace_weapon_whitelist(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = ContentCatalogue.new()
	var attack: AttackDefinition = AttackDefinition.new()
	attack.id = &"action.test_new_sword_attack"
	attack.display_name = "Test New Sword"
	attack.attack_kind = AttackDefinition.ATTACK_MELEE
	attack.attack_sequence_kind = AttackDefinition.SEQUENCE_NORMAL
	attack.targeting_rule_id = &"target.single_creature"
	attack.damage_profile = DamageProfile.new()
	attack.range_profile = RangeProfile.new()
	attack.range_profile.reach_feet = 5
	attack.player_usable = true
	attack.ai_usable = true
	var registered: bool = catalogue.register_action_definition(attack)
	_expect(registered, "The test attack must register in a clean catalogue.", failures)

	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	query.configure(null, null, catalogue)
	_expect(
		query.is_supported_action(attack.id),
		"A newly authored compatible melee attack must not require code changes.",
		failures
	)
	_expect(
		query.is_supported_ai_action(attack.id),
		"AI support must come from AttackDefinition capabilities.",
		failures
	)

	attack.attack_kind = AttackDefinition.ATTACK_RANGED
	_expect(
		not query.is_supported_action(attack.id),
		"The current slice must reject unimplemented ranged profiles by capability.",
		failures
	)


static func _test_enemy_failure_finalizes_and_continues(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var begin_result: OperationResult = session.screen_facade.begin_world_phase()
	_expect(begin_result.success, "The Enemy Turn must begin for recovery testing.", failures)
	if not begin_result.success:
		return

	var handler: EnemyTurnHandler = EnemyTurnHandler.new()
	handler.configure(
		session.state_store,
		session.map_definition,
		session.content_catalogue,
		session.event_journal,
		session.attack_preview_query,
		null
	)
	var result: OperationResult = handler.resolve_enemy_turn()
	_expect(
		result.success,
		"An enemy attack execution failure must be recovered without stopping the phase.",
		failures
	)
	var guard: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	var dummy: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.PRACTICE_DUMMY_ID
	)
	_expect(
		guard.action_budget.ended_activation,
		"A failed Guard activation must be safely finalized.",
		failures
	)
	_expect(
		dummy.action_budget.ended_activation,
		"The Enemy Turn must continue to the Training Dummy after Guard recovery.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
