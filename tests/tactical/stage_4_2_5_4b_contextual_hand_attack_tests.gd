class_name Stage4254bContextualHandAttackTests
extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_screen_defaults_to_a_persistent_hand_without_targeting(failures)
	_test_hand_memory_is_per_character(failures)
	_test_selected_hand_attack_uses_authoritative_attack_pipeline(failures)
	return failures


static func _test_screen_defaults_to_a_persistent_hand_without_targeting(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var screen: Node = SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	screen.set("_selected_unit_id", TacticalSandboxFactory.MARAUDER_ID)
	screen.call("_select_default_weapon_for_unit")
	_expect(
		StringName(screen.get("_selected_weapon_hand_kind"))
			== TacticalInventoryState.KIND_PRIMARY_HAND,
		"A player character should default to Primary Hand when it is occupied.",
		failures
	)
	_expect(
		not bool(screen.get("_attack_targeting")),
		"Selecting the default hand must not enter basic-attack targeting mode.",
		failures
	)
	_expect(
		not StringName(screen.get("_selected_attack_id")).is_empty(),
		"The selected hand should still resolve its contextual basic attack.",
		failures
	)
	screen.free()


static func _test_hand_memory_is_per_character(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var screen: Node = SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	screen.set("_selected_unit_id", TacticalSandboxFactory.MARAUDER_ID)
	screen.call(
		"_apply_hand_selection",
		TacticalInventoryState.KIND_SECONDARY_HAND,
		true
	)
	screen.set("_selected_unit_id", TacticalSandboxFactory.ARCHER_ID)
	screen.call(
		"_apply_hand_selection",
		TacticalInventoryState.KIND_PRIMARY_HAND,
		true
	)
	var remembered: Dictionary = screen.get("_selected_hand_by_unit_id") as Dictionary
	_expect(
		StringName(remembered.get(TacticalSandboxFactory.MARAUDER_ID, &""))
			== TacticalInventoryState.KIND_SECONDARY_HAND,
		"The Marauder's hand choice should be remembered independently.",
		failures
	)
	_expect(
		StringName(remembered.get(TacticalSandboxFactory.ARCHER_ID, &""))
			== TacticalInventoryState.KIND_PRIMARY_HAND,
		"The Archer's hand choice should not overwrite the Marauder's choice.",
		failures
	)
	screen.set("_selected_unit_id", TacticalSandboxFactory.MARAUDER_ID)
	screen.call("_select_default_weapon_for_unit")
	_expect(
		StringName(screen.get("_selected_weapon_hand_kind"))
			== TacticalInventoryState.KIND_SECONDARY_HAND,
		"Reselecting a character should restore that character's remembered hand.",
		failures
	)
	screen.free()


static func _test_selected_hand_attack_uses_authoritative_attack_pipeline(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var attacker: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var enemies: Array[TacticalUnitState] = state.get_enemy_units()
	if attacker == null or enemies.is_empty():
		failures.append("The contextual-attack fixture needs a Marauder and enemy.")
		return
	var target: TacticalUnitState = enemies[0]
	var offset: int = 0
	for enemy: TacticalUnitState in enemies:
		state.set_unit_position(
			enemy.unit_id,
			Vector2i(50 + offset, 50),
			session.map_definition,
			false
		)
		offset += 2
	state.set_unit_position(
		attacker.unit_id,
		Vector2i(20, 20),
		session.map_definition,
		false
	)
	state.set_unit_position(
		target.unit_id,
		Vector2i(21, 20),
		session.map_definition,
		false
	)
	session.visibility_service.call("recalculate_all_teams")

	var item: TacticalItemInstanceState = state.get_hand_item(
		attacker.unit_id,
		TacticalInventoryState.KIND_PRIMARY_HAND
	)
	var attack_id: StringName = _first_supported_attack(session, item)
	_expect(not attack_id.is_empty(), "Primary Hand needs a supported attack.", failures)
	if attack_id.is_empty():
		return
	var capacity_before: int = attacker.action_budget.remaining_turn_capacity_feet
	var preview = session.screen_facade.preview_attack(
		attacker.unit_id,
		target.unit_id,
		attack_id,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)
	_expect(
		preview != null and bool(preview.get("success")),
		"The contextual hand attack should produce a legal authoritative preview.",
		failures
	)
	if preview == null or not bool(preview.get("success")):
		return
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	_expect(result.success, "A legal contextual attack preview should execute.", failures)
	_expect(
		attacker.action_budget.remaining_turn_capacity_feet < capacity_before,
		"The contextual attack must spend capacity through the normal handler.",
		failures
	)


static func _first_supported_attack(
		session: TacticalSession,
		item: TacticalItemInstanceState
) -> StringName:
	if item == null or item.definition == null:
		return &""
	for action_id: StringName in item.definition.granted_action_ids:
		if session.screen_facade.is_stage_4_attack(action_id):
			return action_id
	return &""


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
