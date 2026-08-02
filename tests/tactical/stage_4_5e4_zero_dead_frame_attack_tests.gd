class_name Stage45E4ZeroDeadFrameAttackTests
extends RefCounted

const MARAUDER_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_committed_hit_publishes_impact_before_return(failures)
	_test_commit_reuses_accepted_preview(failures)
	return failures


static func _test_committed_hit_publishes_impact_before_return(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var impact_seen: Dictionary = {"value": false}
	session.screen_facade.damage_committed.connect(
		func(_event: Dictionary) -> void:
			impact_seen["value"] = true
	)
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 1])
	var preview = session.screen_facade.preview_attack(
		MARAUDER_ID,
		DUMMY_ID,
		AXE_ACTION_ID
	)
	var result: OperationResult = session.screen_facade.execute_attack_preview(
		preview
	)
	_expect(result.success, "The zero-dead-frame attack must commit.", failures)
	_expect(
		bool(impact_seen.get("value", false)),
		"A committed hit must publish impact synchronously before execute returns.",
		failures
	)


static func _test_commit_reuses_accepted_preview(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var before: Dictionary = session.screen_facade.performance_snapshot()
	var before_commit: Dictionary = before.get("attack_commit", {})
	var before_reuses: int = int(before_commit.get("commit_preview_reuses", 0))
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 1])
	var preview = session.screen_facade.preview_attack(
		MARAUDER_ID,
		DUMMY_ID,
		AXE_ACTION_ID
	)
	var result: OperationResult = session.screen_facade.execute_attack_preview(
		preview
	)
	var after: Dictionary = session.screen_facade.performance_snapshot()
	var after_commit: Dictionary = after.get("attack_commit", {})
	_expect(result.success, "The preview-reuse attack must commit.", failures)
	_expect(
		int(after_commit.get("commit_preview_reuses", 0)) == before_reuses + 1,
		"The attack commit must reuse the accepted preview.",
		failures
	)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
