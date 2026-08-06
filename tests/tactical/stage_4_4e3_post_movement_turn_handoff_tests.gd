class_name Stage44e3PostMovementTurnHandoffTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_visibility_reference_counts_preserve_other_observers(failures)
	_test_incremental_visibility_refresh_does_not_rebuild_all_teams(failures)
	_test_deferred_movement_release_uses_targeted_visibility(failures)
	_test_perception_commit_does_not_rebuild_tile_visibility(failures)
	return failures


static func _test_visibility_reference_counts_preserve_other_observers(
		failures: Array[String]
) -> void:
	var visibility := TacticalVisibilityState.new()
	visibility.configure(Vector2i(4, 4))
	visibility.begin_recalculation([&"player"])
	visibility.replace_unit_visibility(
		&"unit.a",
		&"player",
		[Vector2i(1, 1), Vector2i(2, 2)]
	)
	visibility.replace_unit_visibility(
		&"unit.b",
		&"player",
		[Vector2i(1, 1)]
	)
	visibility.complete_recalculation()
	visibility.remove_unit_visibility(&"unit.a")
	visibility.complete_recalculation()
	_expect(
		visibility.is_visible(&"player", Vector2i(1, 1)),
		"Removing one observer must preserve tiles still seen by another observer.",
		failures
	)
	_expect(
		not visibility.is_visible(&"player", Vector2i(2, 2)),
		"Tiles seen only by the removed observer must become hidden.",
		failures
	)


static func _test_incremental_visibility_refresh_does_not_rebuild_all_teams(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var visibility: TacticalVisibilityService = session.visibility_service
	var full_before: int = int(
		visibility.performance_snapshot().get("full_recalculation_count", 0)
	)
	var incremental_before: int = int(
		visibility.performance_snapshot().get("incremental_recalculation_count", 0)
	)
	var enemy_visible_before: int = visibility.visible_tile_count(&"enemy")
	visibility.recalculate_units([TacticalSandboxFactory.MARAUDER_ID], true)
	var snapshot: Dictionary = visibility.performance_snapshot()
	_expect(
		int(snapshot.get("full_recalculation_count", 0)) == full_before,
		"Refreshing one moved observer must not rebuild all teams.",
		failures
	)
	_expect(
		int(snapshot.get("incremental_recalculation_count", 0))
		== incremental_before + 1,
		"Refreshing one moved observer must use the incremental path.",
		failures
	)
	_expect(
		visibility.visible_tile_count(&"enemy") == enemy_visible_before,
		"Updating a player observer must preserve the enemy team's visibility contribution.",
		failures
	)


static func _test_deferred_movement_release_uses_targeted_visibility(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var visibility: TacticalVisibilityService = session.visibility_service
	var full_before: int = int(
		visibility.performance_snapshot().get("full_recalculation_count", 0)
	)
	var incremental_before: int = int(
		visibility.performance_snapshot().get("incremental_recalculation_count", 0)
	)
	visibility.begin_recalculation_deferral()
	visibility.recalculate_units([TacticalSandboxFactory.MARAUDER_ID], true)
	visibility.end_recalculation_deferral_for_units(
		[TacticalSandboxFactory.MARAUDER_ID],
		false
	)
	var snapshot: Dictionary = visibility.performance_snapshot()
	_expect(
		int(snapshot.get("full_recalculation_count", 0)) == full_before,
		"Ordinary deferred movement must not release into recalculate_all_teams().",
		failures
	)
	_expect(
		int(snapshot.get("incremental_recalculation_count", 0))
		== incremental_before + 1,
		"Deferred movement must release one targeted visibility refresh.",
		failures
	)


static func _test_perception_commit_does_not_rebuild_tile_visibility(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var visibility: TacticalVisibilityService = session.visibility_service
	var before: int = int(
		visibility.performance_snapshot().get("full_recalculation_count", 0)
	)
	visibility.call(
		"_on_tactical_state_changed_with_flags",
		&"current_perception_resolved",
		TacticalInvalidationContract.no_visual_change()
	)
	var after: int = int(
		visibility.performance_snapshot().get("full_recalculation_count", 0)
	)
	_expect(
		after == before,
		"Perception/reveal commits must not rebuild geometric tile visibility.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
