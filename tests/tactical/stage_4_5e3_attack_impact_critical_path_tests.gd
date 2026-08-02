class_name Stage45E3AttackImpactCriticalPathTests
extends RefCounted

const MARAUDER_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const DUMMY_SQUAD_ID: StringName = TacticalSandboxFactory.GUARD_SQUAD_B_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"
const JOURNAL_SCRIPT: Script = preload(
	"res://application/tactical/events/tactical_event_journal.gd"
)


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_impact_precedes_attack_journal_publication(failures)
	_test_known_combat_attack_uses_lightweight_commit(failures)
	_test_recent_events_returns_only_the_tail(failures)
	return failures


static func _test_impact_precedes_attack_journal_publication(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var observed_event_type_at_impact: Dictionary = {"value": &""}
	session.screen_facade.damage_committed.connect(
		func(_event: Dictionary) -> void:
			var latest_value: Variant = session.event_journal.call(
				"latest_event",
				&"combat"
			)
			if latest_value is Dictionary:
				observed_event_type_at_impact["value"] = StringName(
					(latest_value as Dictionary).get("event_type", &"")
				)
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
	_expect(result.success, "The impact-order attack must commit.", failures)
	_expect(
		StringName(observed_event_type_at_impact.get("value", &""))
		!= &"attack_resolved",
		"The damage impact must publish before the attack journal entry.",
		failures
	)
	var committed_value: Variant = session.event_journal.call(
		"latest_event",
		&"combat"
	)
	var committed_event: Dictionary = (
		committed_value as Dictionary
		if committed_value is Dictionary
		else {}
	)
	_expect(
		StringName(committed_event.get("event_type", &"")) == &"attack_resolved",
		"The attack journal entry must exist after commit finishes.",
		failures
	)


static func _test_known_combat_attack_uses_lightweight_commit(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(MARAUDER_ID)
	var target: TacticalUnitState = state.get_unit(DUMMY_ID)
	var squad: TacticalSquadState = state.get_squad(DUMMY_SQUAD_ID)
	if attacker == null or target == null or squad == null:
		failures.append("The lightweight attack fixture is incomplete.")
		return

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
		"The lightweight attack fixture must enter initiative combat.",
		failures
	)
	if not initiative_started:
		return

	var before: Dictionary = session.screen_facade.performance_snapshot()
	var before_commit: Dictionary = before.get("attack_commit", {})
	var before_lightweight: int = int(
		before_commit.get("lightweight_attack_commits", 0)
	)
	var before_full: int = int(
		before_commit.get("full_validation_attack_commits", 0)
	)
	var before_skipped: int = int(
		before_commit.get("redundant_hostile_action_resolutions_skipped", 0)
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
	var after_commit: Dictionary = after.get("attack_commit", {})
	_expect(result.success, "The known-combat attack must commit.", failures)
	_expect(
		int(after_commit.get("lightweight_attack_commits", 0))
		== before_lightweight + 1,
		"An ordinary known-combat hit must use targeted commit validation.",
		failures
	)
	_expect(
		int(after_commit.get("full_validation_attack_commits", 0)) == before_full,
		"An ordinary hit must not run whole-state validation.",
		failures
	)
	_expect(
		int(after_commit.get("redundant_hostile_action_resolutions_skipped", 0))
		== before_skipped + 1,
		"An already-known combat attack must skip redundant hostile-action resolution.",
		failures
	)


static func _test_recent_events_returns_only_the_tail(
	failures: Array[String]
) -> void:
	var journal: RefCounted = JOURNAL_SCRIPT.new()
	for index: int in range(1, 7):
		journal.call(
			"record_event",
			&"test_event",
			1,
			&"player",
			"Event %d" % index,
			{"category": &"events"}
		)
	var recent_value: Variant = journal.call(
		"recent_events",
		3,
		&"all",
		false
	)
	var recent: Array = recent_value if recent_value is Array else []
	_expect(recent.size() == 3, "Recent events must return exactly three records.", failures)
	if recent.size() == 3:
		_expect(
			str((recent[0] as Dictionary).get("summary", "")) == "Event 4"
			and str((recent[2] as Dictionary).get("summary", "")) == "Event 6",
			"Recent events must preserve chronological order for the journal tail.",
			failures
		)


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
