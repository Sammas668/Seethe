class_name Stage45E2CombatFeedbackTests
extends RefCounted

const MARAUDER_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_commit_reuses_exact_preview(failures)
	_test_combat_impact_precedes_state_reconciliation(failures)
	return failures


static func _test_commit_reuses_exact_preview(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 6])
	var preview = session.screen_facade.preview_attack(
		MARAUDER_ID,
		DUMMY_ID,
		AXE_ACTION_ID
	)
	var before: Dictionary = session.screen_facade.performance_snapshot()
	var before_preview: Dictionary = before.get("attack_preview", {})
	var full_before: int = int(
		before_preview.get("full_target_previews_built", 0)
	)

	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	var after: Dictionary = session.screen_facade.performance_snapshot()
	var after_preview: Dictionary = after.get("attack_preview", {})
	var after_commit: Dictionary = after.get("attack_commit", {})
	_expect(result.success, "The unchanged accepted attack preview must commit.", failures)
	_expect(
		int(after_preview.get("full_target_previews_built", 0)) == full_before,
		"Commit must not rebuild five-sample geometry when revisions still match.",
		failures
	)
	_expect(
		int(after_preview.get("commit_previews_reused", 0)) >= 1,
		"The lightweight commit validator must report accepted preview reuse.",
		failures
	)
	_expect(
		int(after_commit.get("commit_preview_reuses", 0)) >= 1,
		"The attack handler must report commit-preview reuse.",
		failures
	)


static func _test_combat_impact_precedes_state_reconciliation(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var signal_order: Array[StringName] = []
	session.screen_facade.damage_committed.connect(
		func(_event: Dictionary) -> void:
			signal_order.append(&"impact")
	)
	session.screen_facade.state_changed.connect(
		func(reason: StringName) -> void:
			if reason == &"attack_resolved":
				signal_order.append(&"state_changed")
	)
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 6])
	var preview = session.screen_facade.preview_attack(
		MARAUDER_ID,
		DUMMY_ID,
		AXE_ACTION_ID
	)
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	_expect(result.success, "The scripted impact-order attack must commit.", failures)
	_expect(
		signal_order.size() >= 2,
		"Damage and state-change signals must both publish for a damaging hit.",
		failures
	)
	if signal_order.size() >= 2:
		_expect(
			signal_order[0] == &"impact" and signal_order[1] == &"state_changed",
			"Committed combat impact must publish before broad state reconciliation.",
			failures
		)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
