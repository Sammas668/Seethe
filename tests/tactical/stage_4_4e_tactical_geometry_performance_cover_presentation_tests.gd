class_name Stage44eTacticalGeometryPerformanceCoverPresentationTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_combat_geometry_cache_reuses_exact_result(failures)
	_test_observation_origins_are_cached_without_spending_capacity(failures)
	_test_directional_cover_field_is_cached_and_knowledge_bound(failures)
	_test_destination_preview_revision_contract(failures)
	_test_performance_snapshot_exposes_optimisation_counters(failures)
	return failures


static func _test_combat_geometry_cache_reuses_exact_result(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_expect(attacker != null and target != null,
		"The Stage 4.4e geometry-cache fixture requires an archer and enemy.", failures)
	if attacker == null or target == null:
		return
	var cache: TacticalGeometryCacheService = session.geometry_cache_service
	cache.clear()
	var before: Dictionary = cache.performance_snapshot()
	var first: TacticalCombatGeometryResult = cache.evaluate(attacker, target)
	var second: TacticalCombatGeometryResult = cache.evaluate(attacker, target)
	var after: Dictionary = cache.performance_snapshot()
	_expect(first != null and second != null,
		"The shared geometry cache must return a combat geometry result.", failures)
	_expect(first == second,
		"Repeated unchanged geometry requests should reuse the cached result object.", failures)
	_expect(int(after.get("cache_misses", 0)) == int(before.get("cache_misses", 0)) + 1,
		"The first unchanged attacker-target request should create one cache miss.", failures)
	_expect(int(after.get("cache_hits", 0)) == int(before.get("cache_hits", 0)) + 1,
		"The second unchanged attacker-target request should create one cache hit.", failures)


static func _test_observation_origins_are_cached_without_spending_capacity(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var observer: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_expect(observer != null,
		"The Stage 4.4e observation-origin fixture requires the Marauder.", failures)
	if observer == null:
		return
	TacticalObservationOriginQuery.clear_cache()
	var capacity_before: int = observer.action_budget.remaining_turn_capacity_feet
	var before: Dictionary = TacticalObservationOriginQuery.performance_snapshot()
	var first: Array[TacticalObservationOrigin] = TacticalObservationOriginQuery.legal_origins(
		state, session.map_definition, observer
	)
	var second: Array[TacticalObservationOrigin] = TacticalObservationOriginQuery.legal_origins(
		state, session.map_definition, observer
	)
	var after: Dictionary = TacticalObservationOriginQuery.performance_snapshot()
	_expect(not first.is_empty() and first.size() == second.size(),
		"Cached automatic Peek origins must reproduce the same legal origin set.", failures)
	_expect(int(after.get("cache_misses", 0)) == int(before.get("cache_misses", 0)) + 1,
		"The first observation-origin request should create one cache miss.", failures)
	_expect(int(after.get("cache_hits", 0)) == int(before.get("cache_hits", 0)) + 1,
		"The second observation-origin request should create one cache hit.", failures)
	_expect(observer.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Cached automatic Peek must remain free of movement and action expenditure.", failures)


static func _test_directional_cover_field_is_cached_and_knowledge_bound(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var defended_tile := Vector2i(5, 4)
	TacticalDirectionalCoverFieldQuery.clear_cache()
	var before: Dictionary = TacticalDirectionalCoverFieldQuery.performance_snapshot()
	var first: TacticalDirectionalCoverField = TacticalDirectionalCoverFieldQuery.build(
		state, session.map_definition, defended_tile, &"player"
	)
	var second: TacticalDirectionalCoverField = TacticalDirectionalCoverFieldQuery.build(
		state, session.map_definition, defended_tile, &"player"
	)
	var after: Dictionary = TacticalDirectionalCoverFieldQuery.performance_snapshot()
	_expect(first != null and second != null,
		"Movement hover must produce a directional cyan cover-field result.", failures)
	_expect(first == second,
		"Repeated unchanged destination cover fields should reuse the cached result.", failures)
	_expect(first.geometry_revision == state.geometry_revision(),
		"The cyan field must be bound to the authoritative geometry revision.", failures)
	_expect(first.knowledge_revision == state.knowledge_state.revision,
		"The cyan field must be bound to player knowledge and reveal no unknown geometry.", failures)
	_expect(int(after.get("cache_hits", 0)) == int(before.get("cache_hits", 0)) + 1,
		"The second unchanged cyan-field request should be a cache hit.", failures)


static func _test_destination_preview_revision_contract(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var preview := TacticalDestinationPreview.new()
	preview.tactical_revision = state.revision
	preview.geometry_revision = state.geometry_revision()
	preview.knowledge_revision = state.knowledge_state.revision
	preview.visibility_revision = session.screen_facade.visibility_revision()
	_expect(preview.is_valid_for(state, session.screen_facade.visibility_revision()),
		"A destination preview should remain valid while all authoritative revisions match.", failures)
	_expect(not preview.is_valid_for(state, preview.visibility_revision + 1),
		"A visibility revision change must invalidate a cached destination preview.", failures)


static func _test_performance_snapshot_exposes_optimisation_counters(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var snapshot: Dictionary = session.screen_facade.performance_snapshot()
	_expect(snapshot.has("attack_preview"),
		"The performance snapshot must expose attack-preview geometry counters.", failures)
	_expect(snapshot.has("visibility"),
		"The performance snapshot must expose automatic-Peek visibility counters.", failures)
	_expect(snapshot.has("enemy_ai"),
		"The performance snapshot must expose AI shortlist counters.", failures)
	_expect(snapshot.has("directional_cover_field"),
		"The performance snapshot must expose cyan cover-field cache counters.", failures)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
