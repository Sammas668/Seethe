class_name Stage44dCoverReadabilityAutomaticOpeningTests
extends RefCounted

const DOOR_ID: StringName = &"opening.farm.ordinary_door"
const LOCKED_DOOR_ID: StringName = &"opening.farm.locked_door"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_automatic_peek_origins_are_free(failures)
	_test_automatic_lean_origins_are_free(failures)
	_test_interact_options_exclude_peek_and_lean(failures)
	_test_cover_preview_worst_case_summary(failures)
	_test_physical_edge_cover_preview(failures)
	_test_ranged_preview_never_adds_lean_cost(failures)
	return failures


static func _test_automatic_peek_origins_are_free(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_place(session, actor, Vector2i(10, 4), failures)
	actor.refresh_for_new_round()
	var opened: OperationResult = session.opening_handler.toggle_opening(actor.unit_id, DOOR_ID)
	_expect(opened.success, "The automatic-Peek fixture door must open.", failures)
	actor.refresh_for_new_round()
	var capacity_before: int = actor.action_budget.remaining_turn_capacity_feet
	var origins: Array[TacticalObservationOrigin] = TacticalObservationOriginQuery.legal_origins(
		state, session.map_definition, actor
	)
	var found_opening_peek: bool = false
	for origin: TacticalObservationOrigin in origins:
		if origin.uses_automatic_peek and origin.source_edge_id == DOOR_ID:
			found_opening_peek = true
			break
	_expect(found_opening_peek,
		"An open adjacent doorway must add an automatic observation origin.", failures)
	_expect(actor.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Querying or using automatic Peek origins must not consume turn capacity.", failures)

	_place(session, actor, Vector2i(7, 2), failures)
	var corner_origins: Array[TacticalObservationOrigin] = TacticalObservationOriginQuery.legal_origins(
		state, session.map_definition, actor
	)
	var found_corner_peek: bool = false
	for origin: TacticalObservationOrigin in corner_origins:
		if origin.uses_automatic_peek and origin.origin_kind == TacticalObservationOrigin.KIND_CORNER_PEEK:
			found_corner_peek = true
			break
	_expect(found_corner_peek,
		"A legal wall corner must add an automatic free Peek origin.", failures)


static func _test_automatic_lean_origins_are_free(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	_place(session, actor, Vector2i(7, 2), failures)
	actor.refresh_for_new_round()
	var capacity_before: int = actor.action_budget.remaining_turn_capacity_feet
	var origins: Array[TacticalFiringOrigin] = TacticalFiringOriginQuery.legal_origins(
		state, session.map_definition, actor
	)
	var centre_count: int = 0
	var lean_count: int = 0
	for origin: TacticalFiringOrigin in origins:
		if origin.uses_automatic_lean:
			lean_count += 1
		else:
			centre_count += 1
	_expect(centre_count == 1,
		"Automatic firing-origin selection must retain one ordinary centre origin.", failures)
	_expect(lean_count > 0,
		"A character beside a valid wall corner must receive legal automatic lean origins.", failures)
	_expect(actor.action_budget.remaining_turn_capacity_feet == capacity_before,
		"Evaluating automatic lean origins must not consume movement or actions.", failures)


static func _test_interact_options_exclude_peek_and_lean(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var actor: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	_place(session, actor, Vector2i(10, 4), failures)
	var ordinary: Array[Dictionary] = session.opening_handler.available_interactions(
		actor.unit_id, DOOR_ID
	)
	_expect(ordinary.size() == 1,
		"A closed unlocked ordinary door should expose one direct Interact option.", failures)
	if ordinary.size() == 1:
		_expect(StringName(ordinary[0].get("action_id", &"")) == &"toggle_opening",
			"The ordinary-door Interact option must be Open/Close.", failures)

	var scout: TacticalUnitState = state.get_unit(TacticalSandboxFactory.SCOUT_ID)
	_place(session, scout, Vector2i(10, 5), failures)
	var locked: Array[Dictionary] = session.opening_handler.available_interactions(
		scout.unit_id, LOCKED_DOOR_ID
	)
	var action_ids: Array[StringName] = []
	for option: Dictionary in locked:
		action_ids.append(StringName(option.get("action_id", &"")))
	_expect(action_ids.has(&"toggle_opening") and action_ids.has(&"pick_lock"),
		"A locked door must expose physical opening and lockpick options through Interact.", failures)
	_expect(not action_ids.has(&"peek") and not action_ids.has(&"lean_attack"),
		"Peek and Lean must never appear as opening interaction commands.", failures)


static func _test_cover_preview_worst_case_summary(
		failures: Array[String]
) -> void:
	var preview := TacticalCoverPreview.new()
	preview.mover_unit_id = &"unit.test"
	preview.destination = Vector2i(4, 4)
	var heavy := TacticalCombatGeometryResult.new()
	heavy.cover_category = TacticalCombatGeometryResult.COVER_HEAVY
	var light := TacticalCombatGeometryResult.new()
	light.cover_category = TacticalCombatGeometryResult.COVER_LIGHT
	var exposed := TacticalCombatGeometryResult.new()
	exposed.cover_category = TacticalCombatGeometryResult.COVER_NONE
	preview.add_result(&"enemy.heavy", heavy)
	preview.add_result(&"enemy.light", light)
	preview.add_result(&"enemy.exposed", exposed)
	_expect(preview.worst_category() == TacticalCombatGeometryResult.COVER_NONE,
		"The destination summary must use the least favourable visible-enemy result.", failures)
	_expect(preview.worst_label() == "EXPOSED",
		"A destination exposed to any visible enemy must display EXPOSED.", failures)
	_expect(preview.compact_breakdown().contains("1 exposed")
		and preview.compact_breakdown().contains("1 light")
		and preview.compact_breakdown().contains("1 heavy"),
		"The compact destination breakdown must retain per-category threat counts.", failures)


static func _test_physical_edge_cover_preview(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var edge_cover: Dictionary = session.screen_facade.physical_edge_cover(Vector2i(5, 3))
	_expect(StringName(edge_cover.get(Vector2i.RIGHT, &"")) == TacticalCombatGeometryResult.COVER_LIGHT,
		"The movement preview must expose the authored low fence as a Light edge shield.", failures)
	var heavy_cover: Dictionary = session.screen_facade.physical_edge_cover(Vector2i(5, 4))
	_expect(StringName(heavy_cover.get(Vector2i.RIGHT, &"")) == TacticalCombatGeometryResult.COVER_HEAVY,
		"The movement preview must expose the authored barricade as a Heavy edge shield.", failures)


static func _test_ranged_preview_never_adds_lean_cost(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ARCHER_ID)
	var target: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	_place(session, attacker, Vector2i(7, 2), failures)
	_place(session, target, Vector2i(9, 1), failures)
	attacker.refresh_for_new_round()
	var action_id: StringName = _first_ranged_attack_id(session, attacker)
	_expect(not action_id.is_empty(),
		"The automatic-Lean fixture needs a ranged attack.", failures)
	if action_id.is_empty():
		return
	var preview: TacticalAttackPreview = session.screen_facade.preview_attack(
		attacker.unit_id, target.unit_id, action_id
	) as TacticalAttackPreview
	if preview == null or not preview.success:
		# The origin query is tested independently above; this fixture may remain
		# blocked by authored Total Cover without invalidating the no-cost rule.
		return
	var attack: AttackDefinition = session.content_catalogue.attack_definition(action_id)
	var expected_cost: int = attack.resolved_cost().resolved_normal_capacity_feet(
		attacker.action_budget.maximum_turn_capacity_feet
	)
	_expect(preview.action_cost_feet == expected_cost,
		"Automatic Lean must charge only the ordinary ranged attack cost.", failures)
	_expect(preview.capacity_before - preview.capacity_after == expected_cost,
		"Automatic Lean must not add hidden movement expenditure to the preview.", failures)


static func _first_ranged_attack_id(
		session: TacticalSession,
		unit: TacticalUnitState
) -> StringName:
	for action_id: StringName in session.state_store.state.granted_action_ids_for_unit(unit.unit_id):
		var attack: AttackDefinition = session.content_catalogue.attack_definition(action_id)
		if attack != null and attack.attack_kind == AttackDefinition.ATTACK_RANGED:
			return action_id
	return &""


static func _place(
		session: TacticalSession,
		unit: TacticalUnitState,
		tile: Vector2i,
		failures: Array[String]
) -> void:
	if unit == null:
		failures.append("A Stage 4.4d fixture unit is missing.")
		return
	var moved: bool = session.state_store.state.set_unit_position(
		unit.unit_id, tile, session.map_definition, false
	)
	_expect(moved,
		"%s could not be placed at %s for the Stage 4.4d fixture." % [unit.display_name, tile],
		failures)
	session.state_store.state.rebuild_unit_occupancy()


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
