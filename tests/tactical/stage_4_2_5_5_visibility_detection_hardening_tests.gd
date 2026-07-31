class_name Stage4255VisibilityDetectionHardeningTests
extends RefCounted

const TacticalLineOfSightRules: Script = preload(
	"res://domain/tactical/visibility/tactical_line_of_sight_rules.gd"
)
const VISIBILITY_SERVICE_SCRIPT: Script = preload(
	"res://application/tactical/visibility/tactical_visibility_service.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_explored_knowledge_survives_service_recreation(failures)
	_test_shared_line_of_sight_authority(failures)
	_test_visibility_invalidation_filters_non_spatial_changes(failures)
	_test_perception_overlay_cache(failures)
	_test_squad_perception_commits_once(failures)
	return failures


static func _test_explored_knowledge_survives_service_recreation(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var player: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	if player == null:
		failures.append("Knowledge persistence needs the Marauder fixture.")
		return
	var known_tile: Vector2i = player.grid_position
	_expect(
		state.is_tile_explored(&"player", known_tile),
		"Initial visibility must commit explored terrain into TacticalState.",
		failures
	)
	var count_before: int = state.explored_tile_count(&"player")
	var replacement: RefCounted = VISIBILITY_SERVICE_SCRIPT.new() as RefCounted
	replacement.call("configure", session.state_store, session.map_definition)
	_expect(
		state.is_tile_explored(&"player", known_tile),
		"Recreating TacticalVisibilityService must not erase explored history.",
		failures
	)
	_expect(
		state.explored_tile_count(&"player") >= count_before,
		"Explored terrain must remain authoritative after service recreation.",
		failures
	)


static func _test_shared_line_of_sight_authority(
		failures: Array[String]
) -> void:
	var map := TacticalMapDefinition.new()
	map.grid_size = Vector2i(12, 12)
	map.stone_wall_tiles = [Vector2i(5, 5)]
	var blocked: bool = TacticalLineOfSightRules.has_line_of_sight(
		Vector2i(2, 5),
		Vector2i(8, 5),
		map
	)
	_expect(
		not blocked,
		"The shared line-of-sight authority must block sight beyond a wall.",
		failures
	)
	var wall_visible: bool = TacticalLineOfSightRules.has_line_of_sight(
		Vector2i(2, 5),
		Vector2i(5, 5),
		map
	)
	_expect(
		wall_visible,
		"The target wall tile itself must remain visible.",
		failures
	)
	_expect(
		TacticalLineOfSightRules.first_blocking_tile(
			Vector2i(2, 5),
			Vector2i(8, 5),
			map
		) == Vector2i(5, 5),
		"Line tracing must report the first intervening blocker.",
		failures
	)


static func _test_visibility_invalidation_filters_non_spatial_changes(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var before: Dictionary = session.visibility_service.call(
		"performance_snapshot"
	)
	var changes := TacticalChangeSet.new(
		&"action_spent",
		session.state_store.state.revision
	)
	changes.stage(
		func() -> bool:
			return true,
		func() -> void:
			pass,
		"The no-op action test failed."
	)
	var committed: OperationResult = session.state_store.commit(
		changes,
		session.map_definition
	)
	_expect(committed.success, "The non-spatial test change must commit.", failures)
	var after: Dictionary = session.visibility_service.call(
		"performance_snapshot"
	)
	_expect(
		int(after.get("recalculation_count", -1))
		== int(before.get("recalculation_count", -2)),
		"Action-only changes must not rebuild team visibility.",
		failures
	)
	_expect(
		int(after.get("skipped_change_count", 0))
		> int(before.get("skipped_change_count", 0)),
		"The visibility service must record filtered non-spatial changes.",
		failures
	)


static func _test_perception_overlay_cache(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var observer_id: StringName = TacticalSandboxFactory.ENEMY_ID
	session.detection_service.perception_tiles_for_observer(observer_id)
	var before: Dictionary = (
		session.detection_service.perception_performance_snapshot()
	)
	session.detection_service.perception_tiles_for_observer(observer_id)
	var after: Dictionary = (
		session.detection_service.perception_performance_snapshot()
	)
	_expect(
		int(after.get("cache_hits", 0)) > int(before.get("cache_hits", 0)),
		"Repeated perception overlays must reuse the observer cache.",
		failures
	)


static func _test_squad_perception_commits_once(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var observer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var enemy_a: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var enemy_b: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	if observer == null or enemy_a == null or enemy_b == null:
		failures.append("Atomic perception needs the Marauder and two guards.")
		return
	state.set_unit_position(observer.unit_id, Vector2i(20, 20), session.map_definition, false)
	observer.set_facing(Vector2i(1, 0))
	state.set_unit_position(enemy_a.unit_id, Vector2i(23, 20), session.map_definition, false)
	state.set_unit_position(enemy_b.unit_id, Vector2i(24, 20), session.map_definition, false)
	var hidden_enemies: Array[TacticalUnitState] = [enemy_a, enemy_b]
	for enemy: TacticalUnitState in hidden_enemies:
		enemy.enter_stealth()
		enemy.clear_revelation()
		enemy.set_current_stealth_roll(1, 1 + enemy.stealth_bonus())
	var offset: int = 0
	for unit: TacticalUnitState in state.get_units():
		if unit.unit_id in [observer.unit_id, enemy_a.unit_id, enemy_b.unit_id]:
			continue
		state.set_unit_position(
			unit.unit_id,
			Vector2i(50 + offset, 50),
			session.map_definition,
			false
		)
		offset += 2
	session.visibility_service.call("recalculate_all_teams", true)
	var revision_before: int = state.revision
	var result: OperationResult = (
		session.detection_service.resolve_current_perception_for_squad(
			TacticalSquadState.PLAYER_TEAM_SQUAD_ID
		)
	)
	_expect(result.success, "Squad perception must commit successfully.", failures)
	_expect(
		state.revision == revision_before + 1,
		"One squad perception refresh must produce exactly one tactical commit.",
		failures
	)
	_expect(
		enemy_a.is_revealed_to_squad(
			TacticalSquadState.PLAYER_TEAM_SQUAD_ID
		)
		and enemy_b.is_revealed_to_squad(
			TacticalSquadState.PLAYER_TEAM_SQUAD_ID
		),
		"The atomic refresh must reveal every failed hidden target together.",
		failures
	)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
