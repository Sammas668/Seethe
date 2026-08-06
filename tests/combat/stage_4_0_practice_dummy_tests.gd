class_name Stage40PracticeDummyCombatTests
extends RefCounted

const HAKON_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"
const MACE_ACTION_ID: StringName = &"action.mace_attack"
const DAGGER_ACTION_ID: StringName = &"action.reaver_dagger_attack"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_attack_preview(failures)
	_test_normal_hit_transaction_and_log(failures)
	_test_natural_one_automatic_miss(failures)
	_test_natural_twenty_and_critical_confirmation(failures)
	_test_power_attack_and_rage_recalculation(failures)
	_test_mace_and_dagger_are_equipment_granted(failures)
	_test_single_normal_attack_allowance(failures)
	_test_nonlethal_mode_and_marauder_exemption(failures)
	_test_seeded_rolls_are_repeatable(failures)
	return failures


static func _test_attack_preview(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var preview = session.screen_facade.preview_attack(
		HAKON_ID,
		DUMMY_ID,
		AXE_ACTION_ID,
		0
	)
	_expect(preview != null and preview.success, "Raider's Axe must preview against the adjacent dummy.", failures)
	if preview == null:
		return
	_expect(preview.attack_bonus == 5, "Normal Raider's Axe attack bonus must be +5.", failures)
	_expect(preview.target_armour_class == 14, "Practice Dummy AC must be 14.", failures)
	_expect(preview.damage_notation == "1d8+2", "Normal axe damage must be 1d8+2.", failures)
	_expect(preview.action_cost_feet == 40, "A Marauder Half Action must cost 40 ft.", failures)
	_expect(preview.hit_chance_percent == 60, "A +5 attack against AC 14 must show 60% hit chance.", failures)
	var legal_ids: Array[StringName] = session.screen_facade.legal_attack_target_ids(
		HAKON_ID,
		AXE_ACTION_ID,
		0
	)
	_expect(legal_ids.has(DUMMY_ID), "The adjacent Practice Dummy must be highlighted as legal.", failures)
	_expect(not legal_ids.has(TacticalSandboxFactory.ENEMY_ID), "The distant guard must not be a legal melee target.", failures)


static func _test_normal_hit_transaction_and_log(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var attacker: TacticalUnitState = session.state_store.state.get_unit(HAKON_ID)
	var target: TacticalUnitState = session.state_store.state.get_unit(DUMMY_ID)
	var revision_before: int = session.state_store.state.revision
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 6])
	var preview = session.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, AXE_ACTION_ID, 0)
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	_expect(result.success, "A scripted normal hit must commit.", failures)
	_expect(target.current_hp == 52, "A roll of 6 plus Strength 2 must deal 8 damage.", failures)
	_expect(attacker.action_budget.remaining_turn_capacity_feet == 40, "The attack must spend exactly 40 ft.", failures)
	_expect(session.state_store.state.revision == revision_before + 1, "Attack cost and damage must commit in one revision.", failures)
	var resolution = result.data
	_expect(resolution != null and resolution.hit, "The scripted attack must be recorded as a hit.", failures)
	_expect(resolution.final_damage == 8, "The scripted attack must report 8 final damage.", failures)
	var event_value: Variant = session.event_journal.call("latest_event", &"combat")
	var event: Dictionary = event_value if event_value is Dictionary else {}
	_expect(StringName(event.get("event_type", &"")) == &"attack_resolved", "The combat journal must receive a structured attack event.", failures)
	var roll_records: Array = event.get("roll_records", [])
	var effect_records: Array = event.get("effect_records", [])
	_expect(roll_records.size() == 2, "A normal hit must record attack and damage rolls.", failures)
	_expect(effect_records.size() == 1, "A hit must record the target HP effect.", failures)


static func _test_natural_one_automatic_miss(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var target: TacticalUnitState = session.state_store.state.get_unit(DUMMY_ID)
	session.screen_facade.set_combat_scripted_rolls_for_tests([1])
	var preview = session.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, AXE_ACTION_ID, 0)
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	var resolution = result.data
	_expect(result.success, "A miss still commits its action cost.", failures)
	_expect(resolution != null and resolution.natural_one and not resolution.hit, "Natural 1 must automatically miss.", failures)
	_expect(target.current_hp == 60, "A natural 1 must not damage the Practice Dummy.", failures)


static func _test_natural_twenty_and_critical_confirmation(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var target: TacticalUnitState = session.state_store.state.get_unit(DUMMY_ID)
	session.screen_facade.set_combat_scripted_rolls_for_tests([20, 15, 8])
	var preview = session.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, AXE_ACTION_ID, 0)
	var result: OperationResult = session.screen_facade.execute_attack_preview(preview)
	var resolution = result.data
	_expect(result.success, "A confirmed critical must commit.", failures)
	_expect(resolution != null and resolution.natural_twenty, "The attack must retain the natural 20.", failures)
	_expect(resolution.critical_threat and resolution.critical_confirmed, "Natural 20 followed by 15 must confirm against AC 14.", failures)
	_expect(resolution.base_damage == 10, "A damage roll of 8 plus Strength 2 must equal 10.", failures)
	_expect(resolution.final_damage == 30, "Raider's Axe critical damage must apply ×3.", failures)
	_expect(target.current_hp == 30, "The dummy must lose the confirmed 30 damage.", failures)


static func _test_power_attack_and_rage_recalculation(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var normal_preview = session.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, AXE_ACTION_ID, 2)
	_expect(normal_preview.attack_bonus == 3, "Power Attack 2 must reduce +5 to +3.", failures)
	_expect(normal_preview.damage_notation == "1d8+4", "Power Attack 2 must raise axe damage to 1d8+4.", failures)
	var rage_applied: bool = session.set_character_modifier_active(
		HAKON_ID,
		&"effect.rage",
		true
	)
	_expect(rage_applied, "Rage must recalculate the Marauder through TacticalStateStore.", failures)
	var attacker: TacticalUnitState = session.state_store.state.get_unit(HAKON_ID)
	_expect(attacker.maximum_hp == 38, "Rage must raise maximum HP from 32 to 38.", failures)
	_expect(attacker.armour_class == 12, "Rage must reduce AC from 14 to 12.", failures)
	var rage_preview = session.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, AXE_ACTION_ID, 2)
	_expect(rage_preview.attack_bonus == 5, "Raging Power Attack 2 must resolve to +5.", failures)
	_expect(rage_preview.damage_notation == "1d8+6", "Raging Power Attack 2 must resolve to 1d8+6.", failures)


static func _test_mace_and_dagger_are_equipment_granted(failures: Array[String]) -> void:
	var mace_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	_expect(_move_item(mace_session, &"instance.marauder.axe", TacticalInventoryState.KIND_PRIMARY_HAND, TacticalItemLocationState.CONTAINER_GROUND), "The axe must move out of the hand for the mace test.", failures)
	_expect(_move_item(mace_session, &"instance.marauder.mace", TacticalInventoryState.KIND_BACKPACK, TacticalInventoryState.KIND_PRIMARY_HAND), "The mace must equip from the Backpack.", failures)
	var mace_preview = mace_session.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, MACE_ACTION_ID, 0)
	_expect(mace_preview != null and mace_preview.success, "Equipped Mace — Lethal must be executable.", failures)
	_expect(mace_preview.damage_notation == "1d6+2", "Mace lethal damage must be 1d6+2.", failures)
	var dagger_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	_expect(_move_item(dagger_session, &"instance.marauder.axe", TacticalInventoryState.KIND_PRIMARY_HAND, TacticalItemLocationState.CONTAINER_GROUND), "The axe must move out of the hand for the dagger test.", failures)
	_expect(_move_item(dagger_session, &"instance.marauder.dagger", TacticalInventoryState.KIND_BELT, TacticalInventoryState.KIND_PRIMARY_HAND), "The dagger must equip from the Belt.", failures)
	var dagger_preview = dagger_session.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, DAGGER_ACTION_ID, 0)
	_expect(dagger_preview != null and dagger_preview.success, "Equipped Dagger melee must be executable.", failures)
	_expect(dagger_preview.critical_threat_minimum == 19, "Dagger melee must retain its 19–20 critical threat range.", failures)
	_expect(not dagger_session.screen_facade.is_stage_4_attack(&"action.reaver_thrown_dagger_attack"), "Thrown Dagger must remain outside the melee-only Stage 4.0 slice.", failures)



static func _test_single_normal_attack_allowance(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var attacker: TacticalUnitState = session.state_store.state.get_unit(HAKON_ID)
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 4])
	var first_preview = session.screen_facade.preview_attack(
		HAKON_ID,
		DUMMY_ID,
		AXE_ACTION_ID,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)
	var first_result: OperationResult = (
		session.screen_facade.execute_attack_preview(first_preview)
	)
	_expect(first_result.success, "The first normal attack must execute.", failures)
	_expect(
		attacker.action_budget.remaining_turn_capacity_feet == 40,
		"The first attack must leave the Marauder's remaining 40 ft available.",
		failures
	)
	_expect(
		not attacker.action_budget.ordinary_attack_available,
		"The first normal attack must consume the activation's attack allowance.",
		failures
	)
	var second_preview = session.screen_facade.preview_attack(
		HAKON_ID,
		DUMMY_ID,
		AXE_ACTION_ID,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	)
	_expect(
		second_preview != null and not second_preview.success,
		"A second normal attack must be rejected even with 40 ft remaining.",
		failures
	)


static func _test_nonlethal_mode_and_marauder_exemption(
		failures: Array[String]
) -> void:
	var axe_session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var axe_preview = axe_session.screen_facade.preview_attack(
		HAKON_ID,
		DUMMY_ID,
		AXE_ACTION_ID,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
	)
	_expect(
		axe_preview.nonlethal_attack_penalty == -4,
		"Take Them Alive must not remove the penalty from a slashing weapon.",
		failures
	)

	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	_expect(
		_move_item(
			session,
			&"instance.marauder.axe",
			TacticalInventoryState.KIND_PRIMARY_HAND,
			TacticalItemLocationState.CONTAINER_GROUND
		),
		"The axe must move out of the hand for the nonlethal Mace test.",
		failures
	)
	_expect(
		_move_item(
			session,
			&"instance.marauder.mace",
			TacticalInventoryState.KIND_BACKPACK,
			TacticalInventoryState.KIND_PRIMARY_HAND
		),
		"The Mace must equip for the nonlethal mode test.",
		failures
	)
	var target: TacticalUnitState = session.state_store.state.get_unit(DUMMY_ID)
	var preview = session.screen_facade.preview_attack(
		HAKON_ID,
		DUMMY_ID,
		MACE_ACTION_ID,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
	)
	_expect(preview != null and preview.success, "Mace nonlethal mode must preview.", failures)
	_expect(
		preview.nonlethal_attack_penalty == 0,
		"Take Them Alive must remove the nonlethal penalty with a blunt weapon.",
		failures
	)
	_expect(
		preview.nonlethal_penalty_ignored,
		"The preview must report the Marauder exemption.",
		failures
	)
	session.screen_facade.set_combat_scripted_rolls_for_tests([12, 4])
	var result: OperationResult = session.screen_facade.execute_attack_preview(
		preview
	)
	_expect(result.success, "The selected nonlethal Mace attack must execute.", failures)
	_expect(target.current_hp == 60, "Nonlethal mode must not reduce HP.", failures)
	_expect(
		target.nonlethal_damage == 6,
		"A roll of 4 plus Strength 2 must add 6 nonlethal damage.",
		failures
	)

static func _test_seeded_rolls_are_repeatable(failures: Array[String]) -> void:
	var first: TacticalSession = TacticalSandboxFactory.create_session(false)
	var second: TacticalSession = TacticalSandboxFactory.create_session(false)
	first.screen_facade.set_combat_seed_for_tests(4000)
	second.screen_facade.set_combat_seed_for_tests(4000)
	var first_result: OperationResult = first.screen_facade.execute_attack_preview(
		first.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, AXE_ACTION_ID, 0)
	)
	var second_result: OperationResult = second.screen_facade.execute_attack_preview(
		second.screen_facade.preview_attack(HAKON_ID, DUMMY_ID, AXE_ACTION_ID, 0)
	)
	var first_resolution = first_result.data
	var second_resolution = second_result.data
	_expect(first_result.success and second_result.success, "Seeded attacks must both execute.", failures)
	_expect(first_resolution.attack_roll == second_resolution.attack_roll, "Equal seeds must produce equal d20 results.", failures)
	_expect(first_resolution.final_damage == second_resolution.final_damage, "Equal seeds must produce equal damage outcomes.", failures)


static func _move_item(
		session: TacticalSession,
		item_id: StringName,
		source_kind: StringName,
		target_kind: StringName
) -> bool:
	var target_index: int = -1
	if target_kind in [TacticalInventoryState.KIND_BELT, TacticalInventoryState.KIND_BACKPACK]:
		var item: TacticalItemInstanceState = session.state_store.state.get_item(item_id)
		target_index = session.screen_facade.first_fit_for_item(HAKON_ID, item, target_kind)
	var command: TacticalInventoryTransferCommand = TacticalInventoryTransferCommand.new(
		HAKON_ID,
		source_kind,
		item_id,
		target_kind,
		target_index
	)
	var preview: TacticalInventoryTransferPreview = session.screen_facade.preview_inventory_transfer(command)
	if not preview.success:
		return false
	return session.screen_facade.execute_inventory_transfer_plan(preview.plan, preview).success


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
