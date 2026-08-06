class_name Stage45E5PreciseAttackInvalidationTests
extends RefCounted

const MARAUDER_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const DUMMY_SQUAD_ID: StringName = TacticalSandboxFactory.GUARD_SQUAD_B_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_ordinary_attack_skips_visibility_recalculation(failures)
	_test_attack_default_flags_are_precise(failures)
	return failures


static func _test_ordinary_attack_skips_visibility_recalculation(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(MARAUDER_ID)
	var target: TacticalUnitState = state.get_unit(DUMMY_ID)
	var squad: TacticalSquadState = state.get_squad(DUMMY_SQUAD_ID)
	if attacker == null or target == null or squad == null:
		failures.append("The precise-invalidation attack fixture is incomplete.")
		return

	# Put the attack into already-known initiative combat so no alert transition is
	# part of this ordinary hit.
	squad.make_aware()
	attacker.reveal_to_squad(squad.squad_id)
	squad.remember_last_seen(attacker.unit_id, attacker.grid_position)
	var initiative_started: bool = state.begin_initiative_combat(
		[attacker.unit_id, target.unit_id],
		{
			attacker.unit_id: 20,
			target.unit_id: 10,
		}
	)
	_expect(
		initiative_started,
		"The precise-invalidation fixture must enter initiative combat.",
		failures
	)
	if not initiative_started:
		return

	var observed_flags: Dictionary = {}
	session.state_store.state_changed_with_flags.connect(
		func(reason: StringName, flags: TacticalInvalidationFlags) -> void:
			if reason == &"attack_resolved":
				observed_flags["value"] = flags.duplicate_flags()
	)

	var before: Dictionary = session.screen_facade.performance_snapshot()
	var before_visibility: Dictionary = before.get("visibility", {})
	var before_commit: Dictionary = before.get("attack_commit", {})
	var before_no_visibility: int = int(
		before_commit.get(
			"ordinary_attacks_without_visibility_invalidation",
			0
		)
	)

	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 1])
	var preview = session.screen_facade.preview_attack(
		attacker.unit_id,
		target.unit_id,
		AXE_ACTION_ID
	)
	var result: OperationResult = session.screen_facade.execute_attack_preview(
		preview
	)
	var after: Dictionary = session.screen_facade.performance_snapshot()
	var after_visibility: Dictionary = after.get("visibility", {})
	var after_commit: Dictionary = after.get("attack_commit", {})

	_expect(result.success, "The ordinary attack must commit.", failures)
	_expect(
		int(after_visibility.get("recalculation_count", 0))
		== int(before_visibility.get("recalculation_count", 0))
		and int(after_visibility.get("full_recalculation_count", 0))
		== int(before_visibility.get("full_recalculation_count", 0)),
		"An ordinary attack must not recalculate battlefield visibility.",
		failures
	)
	var flags := observed_flags.get("value") as TacticalInvalidationFlags
	_expect(flags != null, "The attack must publish invalidation flags.", failures)
	if flags != null:
		_expect(
			flags.token_status_changed
			and not flags.occupancy_changed
			and not flags.geometry_changed
			and not flags.visibility_changed,
			"Ordinary attack flags must not invalidate occupancy, geometry, or visibility.",
			failures
		)
	_expect(
		int(after_commit.get(
			"ordinary_attacks_without_visibility_invalidation",
			0
		)) == before_no_visibility + 1,
		"The ordinary attack invalidation counter must advance.",
		failures
	)


static func _test_attack_default_flags_are_precise(
		failures: Array[String]
) -> void:
	var flags := TacticalInvalidationContract.attack(&"attacker", &"target")
	_expect(
		flags.token_status_changed
		and not flags.occupancy_changed
		and not flags.visibility_changed
		and not flags.geometry_changed,
		"The default attack_resolved flags must be token-only.",
		failures
	)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
