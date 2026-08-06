class_name Stage47CharacterSheetConformanceTests
extends RefCounted

const MISSION_ID: StringName = &"mission_definition.life.farm_storehouse_raid_01"
const PROTAGONIST_ID: StringName = &"character.protagonist.placeholder.0001"
const MARAUDER_A_ID: StringName = &"character.reaver.marauder.0001"
const MARAUDER_B_ID: StringName = &"character.reaver.marauder.0002"
const GUARD_A_ID: StringName = &"character.life.sanctuary_spear_guard.0001"
const GUARD_B_ID: StringName = &"character.life.sanctuary_spear_guard.0002"
const ARCHER_ID: StringName = &"character.life.sanctuary_archer.0001"
const MERCY_ID: StringName = &"character.life.mercy_bearer.0001"


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	_test_catalogue_and_exact_roster(catalogue, failures)
	_test_default_loadout_legality(catalogue, failures)
	_test_authored_action_definitions(catalogue, failures)
	var session: TacticalSession = _create_session(failures)
	if session == null:
		return failures
	_test_marauders(session, catalogue, failures)
	_test_sanctuary_guards(session, catalogue, failures)
	_test_sanctuary_archer(session, catalogue, failures)
	_test_mercy_bearer(session, catalogue, failures)
	_test_control_ownership(session, failures)
	return failures


static func _create_session(failures: Array[String]) -> TacticalSession:
	var definition: MissionDefinition = MissionDefinitionRegistry.definition(MISSION_ID)
	_expect(definition != null, "The authored farm mission is not registered.", failures)
	if definition == null:
		return null
	var session: TacticalSession = AuthoredMissionFactory.create_session(
		definition,
		[],
		false,
		"user://stage_4_7_hotfix_1_conformance.json"
	)
	_expect(session != null, "The conformance mission session could not be created.", failures)
	return session


static func _test_catalogue_and_exact_roster(
		catalogue: ContentCatalogue,
		failures: Array[String]
) -> void:
	_expect(catalogue != null, "The production content catalogue is missing.", failures)
	if catalogue == null:
		return
	var catalogue_errors: Array[String] = catalogue.validate_catalogue()
	_expect(
		catalogue_errors.is_empty(),
		"The content catalogue is invalid: %s" % (
			catalogue_errors[0] if not catalogue_errors.is_empty() else ""
		),
		failures
	)
	for template_id: StringName in [
		&"character_template.reaver.marauder_tier_1",
		&"character_template.life.sanctuary_spear_guard",
		&"character_template.life.sanctuary_archer",
		&"character_template.life.mercy_bearer",
	]:
		_expect(
			catalogue.character_template(template_id) != null,
			"Missing approved character template %s." % template_id,
			failures
		)
	for deprecated_id: StringName in [
		&"character_template.life.settlement_guard",
		&"character_template.life.settlement_archer",
		&"character_template.life.patrol_leader",
		&"character_template.life.novice_mercy_bearer",
	]:
		_expect(
			catalogue.character_template(deprecated_id) == null,
			"Deprecated substitute remains registered: %s." % deprecated_id,
			failures
		)

	var definition: MissionDefinition = MissionDefinitionRegistry.definition(MISSION_ID)
	if definition == null:
		return
	_expect(
		definition.player_character_ids == [
			PROTAGONIST_ID,
			MARAUDER_A_ID,
			MARAUDER_B_ID,
		],
		"The player roster is not the protagonist plus two persistent Marauders.",
		failures
	)
	var placed_templates: Array[StringName] = []
	for placement: MissionCharacterPlacementDefinition in definition.character_placements:
		if placement != null:
			placed_templates.append(placement.template_id)
	_expect(
		placed_templates.count(&"character_template.life.sanctuary_spear_guard") == 2,
		"The farm mission must place exactly two Sanctuary Spear Guards.",
		failures
	)
	_expect(
		placed_templates.count(&"character_template.life.sanctuary_archer") == 1,
		"The farm mission must place exactly one Sanctuary Archer.",
		failures
	)
	_expect(
		placed_templates.count(&"character_template.life.mercy_bearer") == 1,
		"The farm mission must place exactly one Mercy-Bearer.",
		failures
	)
	for forbidden_template: StringName in [
		&"character_template.life.settlement_guard",
		&"character_template.life.settlement_archer",
		&"character_template.life.patrol_leader",
		&"character_template.life.novice_mercy_bearer",
	]:
		_expect(
			not placed_templates.has(forbidden_template),
			"The farm mission still places deprecated substitute %s." % forbidden_template,
			failures
		)


static func _test_default_loadout_legality(
		catalogue: ContentCatalogue,
		failures: Array[String]
) -> void:
	if catalogue == null:
		return
	var blackjack: ItemDefinition = catalogue.item_definition(
		&"item.sanctuary.blackjack"
	)
	_expect(blackjack != null, "The Sanctuary Blackjack item is missing.", failures)
	if blackjack != null:
		_expect(blackjack.belt_allowed, "The Sanctuary Blackjack is not Belt-legal.", failures)
		_expect(
			blackjack.inventory_footprint == Vector2i(1, 2),
			"The Sanctuary Blackjack no longer uses its approved 1x2 footprint.",
			failures
		)

	for template_id: StringName in [
		&"character_template.life.sanctuary_spear_guard",
		&"character_template.life.sanctuary_archer",
	]:
		var template: CharacterTemplateDefinition = catalogue.character_template(template_id)
		_expect(template != null, "Missing loadout template %s." % template_id, failures)
		if template == null:
			continue
		var found_belt_blackjack: bool = false
		for entry: Dictionary in template.default_loadout_entries:
			if (
				StringName(entry.get("definition_id", &""))
				== &"item.sanctuary.blackjack"
			):
				found_belt_blackjack = (
					StringName(entry.get("container_kind", &""))
					== TacticalInventoryState.KIND_BELT
				)
		_expect(
			found_belt_blackjack,
			"%s does not carry its Sanctuary Blackjack on the Belt." % template_id,
			failures
		)


static func _test_authored_action_definitions(
		catalogue: ContentCatalogue,
		failures: Array[String]
) -> void:
	if catalogue == null:
		return
	var spear: AttackDefinition = catalogue.attack_definition(
		&"action.sanctuary.capture_spear_attack"
	)
	var blackjack: AttackDefinition = catalogue.attack_definition(
		&"action.sanctuary.blackjack_attack"
	)
	var bow: AttackDefinition = catalogue.attack_definition(
		&"action.sanctuary.capture_bow_attack"
	)
	for attack: AttackDefinition in [spear, blackjack, bow]:
		_expect(attack != null, "An approved Sanctuary attack is missing.", failures)
		if attack == null:
			continue
		_expect(
			attack.damage_profile != null,
			"%s has no damage profile." % attack.display_name,
			failures
		)
		_expect(
			attack.default_damage_channel() == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL,
			"%s is not nonlethal-only." % attack.display_name,
			failures
		)
		_expect(
			not attack.allows_damage_channel(TacticalUnitState.DAMAGE_CHANNEL_LETHAL),
			"%s incorrectly offers a lethal damage mode." % attack.display_name,
			failures
		)
	if spear != null:
		_expect(not spear.supports_power_attack, "The Capture Spear incorrectly supports Power Attack.", failures)
	if bow != null and bow.range_profile != null:
		_expect(bow.range_profile.range_increment_feet == 60, "The Capture Bow range increment is not 60 feet.", failures)
		_expect(bow.ammunition_tag == &"padded_arrow", "The Capture Bow does not require padded arrows.", failures)
		_expect(bow.ammunition_per_attack == 1, "The Capture Bow does not spend one padded arrow.", failures)


static func _test_marauders(
		session: TacticalSession,
		catalogue: ContentCatalogue,
		failures: Array[String]
) -> void:
	for unit_id: StringName in [MARAUDER_A_ID, MARAUDER_B_ID]:
		var unit: TacticalUnitState = session.state_store.state.get_unit(unit_id)
		_expect(unit != null, "Marauder %s was not deployed." % unit_id, failures)
		if unit == null:
			continue
		var sheet: ResolvedCharacterSnapshot = unit.resolved_character
		_expect(sheet != null, "%s has no resolved sheet." % unit.display_name, failures)
		if sheet == null:
			continue
		_expect(sheet.template_id == &"character_template.reaver.marauder_tier_1", "Marauder uses the wrong shared template.", failures)
		_expect(sheet.class_name_text == "Barbarian 3", "Marauder is not Barbarian 3.", failures)
		_expect(sheet.ability_score("STR") == 15, "Marauder Strength is not 15.", failures)
		_expect(sheet.ability_score("DEX") == 13, "Marauder Dexterity is not 13.", failures)
		_expect(sheet.ability_score("CON") == 14, "Marauder Constitution is not 14.", failures)
		_expect(unit.maximum_hp == 32, "Marauder HP is not 32.", failures)
		_expect(unit.armour_class == 14, "Marauder AC is not 14.", failures)
		_expect(sheet.stat_value(&"initiative") == 1, "Marauder Initiative is not +1.", failures)
		_expect(sheet.stat_value(&"base_attack_bonus") == 3, "Marauder BAB is not +3.", failures)
		_expect(sheet.stat_value(&"fortitude") == 5, "Marauder Fortitude is not +5.", failures)
		_expect(sheet.stat_value(&"reflex") == 2, "Marauder Reflex is not +2.", failures)
		_expect(sheet.stat_value(&"will") == 2, "Marauder Will is not +2.", failures)
		_expect(sheet.stat_value(&"turn_capacity") == 80, "Marauder movement is not 80 feet.", failures)
		_expect(sheet.stat_value(&"half_action_cost") == 40, "Marauder Half Action is not 40 feet.", failures)
		_expect(sheet.stat_value(&"sprint_distance") == 120, "Marauder Sprint is not 120 feet.", failures)
		_expect(sheet.stat_value(&"effective_carrying_strength") == 19, "Raider's Burden does not give 19 effective carrying Strength.", failures)
		_expect(sheet.has_trait(&"feat.power_attack"), "Marauder lacks Power Attack.", failures)
		_expect(sheet.has_trait(&"trait.take_them_alive"), "Marauder lacks Take Them Alive.", failures)
		_expect(sheet.has_trait(&"trait.raiders_burden"), "Marauder lacks Raider's Burden.", failures)
	var mace: AttackDefinition = catalogue.attack_definition(&"action.mace_attack")
	var marauder: TacticalUnitState = session.state_store.state.get_unit(MARAUDER_A_ID)
	if marauder == null or marauder.resolved_character == null or mace == null:
		return
	var normal_sheet: ResolvedCharacterSnapshot = marauder.resolved_character
	_expect(mace.allows_power_attack(), "The Marauder Mace does not support Power Attack.", failures)
	_expect(normal_sheet.attack_bonus_for(mace) == 5, "Marauder Mace attack is not +5.", failures)
	_expect(normal_sheet.damage_notation_for(mace) == "1d6+2", "Marauder Mace damage is not 1d6+2.", failures)
	var normal_manoeuvre: int = normal_sheet.stat_value(&"manoeuvre")
	var normal_defence: int = normal_sheet.stat_value(&"manoeuvre_defence")
	var normal_maximum_hp: int = marauder.maximum_hp
	_expect(session.set_character_modifier_active(MARAUDER_A_ID, &"effect.rage", true), "Rage could not be activated.", failures)
	var raging_sheet: ResolvedCharacterSnapshot = marauder.resolved_character
	_expect(raging_sheet.ability_score("STR") == 19, "Rage does not add +4 Strength.", failures)
	_expect(raging_sheet.ability_score("CON") == 18, "Rage does not add +4 Constitution.", failures)
	_expect(raging_sheet.stat_value(&"will") == 4, "Rage does not add +2 Will.", failures)
	_expect(marauder.armour_class == 12, "Rage does not apply -2 AC.", failures)
	_expect(raging_sheet.attack_bonus_for(mace) == 7, "Rage does not add exactly +2 to the Mace attack.", failures)
	_expect(raging_sheet.damage_notation_for(mace) == "1d6+4", "Rage does not add exactly +2 Mace damage.", failures)
	_expect(raging_sheet.stat_value(&"manoeuvre") == normal_manoeuvre + 2, "Rage does not add exactly +2 Manoeuvre.", failures)
	_expect(raging_sheet.stat_value(&"manoeuvre_defence") == normal_defence + 2, "Rage does not add exactly +2 Manoeuvre Defence.", failures)
	_expect(marauder.maximum_hp == normal_maximum_hp + 6, "Rage does not add 6 maximum HP from Constitution.", failures)
	_expect(marauder.rage_rounds_remaining == 7, "Rage duration did not start at seven rounds.", failures)
	_expect(marauder.ability_uses(&"resource.rage") == 0, "Rage did not spend its single use.", failures)
	_expect(not session.set_character_modifier_active(MARAUDER_A_ID, &"effect.rage", true), "Rage stacked with itself.", failures)
	_expect(session.set_character_modifier_active(MARAUDER_A_ID, &"effect.rage", false), "Rage could not be ended voluntarily.", failures)
	_expect(marauder.maximum_hp == normal_maximum_hp, "Ending Rage did not restore maximum HP.", failures)
	_expect(marauder.fatigued_after_rage, "Ending Rage did not apply encounter Fatigue.", failures)
	_expect(not marauder.rage_available(), "Fatigued Marauder can incorrectly enter Rage again.", failures)


static func _test_sanctuary_guards(
		session: TacticalSession,
		catalogue: ContentCatalogue,
		failures: Array[String]
) -> void:
	var spear: AttackDefinition = catalogue.attack_definition(&"action.sanctuary.capture_spear_attack")
	var blackjack: AttackDefinition = catalogue.attack_definition(&"action.sanctuary.blackjack_attack")
	for guard_id: StringName in [GUARD_A_ID, GUARD_B_ID]:
		var guard: TacticalUnitState = session.state_store.state.get_unit(guard_id)
		_expect(guard != null, "Sanctuary Spear Guard %s was not deployed." % guard_id, failures)
		if guard == null or guard.resolved_character == null:
			continue
		var sheet: ResolvedCharacterSnapshot = guard.resolved_character
		_expect(sheet.class_name_text == "Warrior 1", "Sanctuary Spear Guard is not Warrior 1.", failures)
		_expect(sheet.ability_score("STR") == 14, "Guard Strength is not 14.", failures)
		_expect(sheet.ability_score("DEX") == 10, "Guard Dexterity is not 10.", failures)
		_expect(sheet.ability_score("CON") == 14, "Guard Constitution is not 14.", failures)
		_expect(guard.maximum_hp == 10, "Guard HP is not 10.", failures)
		_expect(guard.armour_class == 16, "Guard AC is not 16.", failures)
		_expect(sheet.stat_value(&"base_attack_bonus") == 1, "Guard BAB is not +1.", failures)
		_expect(sheet.stat_value(&"fortitude") == 4, "Guard Fortitude is not +4.", failures)
		_expect(sheet.stat_value(&"reflex") == 0, "Guard Reflex is not +0.", failures)
		_expect(sheet.stat_value(&"will") == 0, "Guard Will is not +0.", failures)
		_expect(sheet.has_trait(&"feat.weapon_focus.sanctuary_blackjack"), "Guard lacks Blackjack Weapon Focus.", failures)
		_expect(sheet.has_trait(&"feat.subdual_takedown"), "Guard lacks Subdual Takedown.", failures)
		if spear != null:
			_expect(sheet.attack_bonus_for(spear) == 3, "Capture Spear attack is not +3.", failures)
			_expect(sheet.damage_notation_for(spear) == "1d6+2", "Capture Spear damage is not 1d6+2.", failures)
		if blackjack != null:
			_expect(sheet.attack_bonus_for(blackjack) == 4, "Guard Blackjack attack is not +4.", failures)
			_expect(sheet.damage_notation_for(blackjack) == "1d6+2", "Guard Blackjack damage is not 1d6+2.", failures)
	_expect(
		session.state_store.state.granted_action_ids_for_unit(GUARD_A_ID).has(&"action.brace"),
		"The Guard's Capture Spear does not grant Brace.",
		failures
	)
	for action_id: StringName in [
		&"action.grapple", &"action.trip", &"action.shove",
		&"action.restrain", &"action.first_aid",
	]:
		_expect(
			session.state_store.state.granted_action_ids_for_unit(GUARD_A_ID).has(action_id),
			"The Guard lacks required shared action %s." % action_id,
			failures
		)


static func _test_sanctuary_archer(
		session: TacticalSession,
		catalogue: ContentCatalogue,
		failures: Array[String]
) -> void:
	var archer: TacticalUnitState = session.state_store.state.get_unit(ARCHER_ID)
	_expect(archer != null, "Sanctuary Archer was not deployed.", failures)
	if archer == null or archer.resolved_character == null:
		return
	var sheet: ResolvedCharacterSnapshot = archer.resolved_character
	var bow: AttackDefinition = catalogue.attack_definition(&"action.sanctuary.capture_bow_attack")
	var blackjack: AttackDefinition = catalogue.attack_definition(&"action.sanctuary.blackjack_attack")
	_expect(sheet.class_name_text == "Warrior 1", "Sanctuary Archer is not Warrior 1.", failures)
	_expect(sheet.ability_score("STR") == 10, "Archer Strength is not 10.", failures)
	_expect(sheet.ability_score("DEX") == 14, "Archer Dexterity is not 14.", failures)
	_expect(sheet.ability_score("CON") == 12, "Archer Constitution is not 12.", failures)
	_expect(sheet.ability_score("WIS") == 12, "Archer Wisdom is not 12.", failures)
	_expect(archer.maximum_hp == 9, "Archer HP is not 9.", failures)
	_expect(archer.armour_class == 15, "Archer AC is not 15.", failures)
	_expect(sheet.stat_value(&"initiative") == 2, "Archer Initiative is not +2.", failures)
	_expect(sheet.stat_value(&"base_attack_bonus") == 1, "Archer BAB is not +1.", failures)
	_expect(sheet.stat_value(&"fortitude") == 3, "Archer Fortitude is not +3.", failures)
	_expect(sheet.stat_value(&"reflex") == 2, "Archer Reflex is not +2.", failures)
	_expect(sheet.stat_value(&"will") == 1, "Archer Will is not +1.", failures)
	_expect(sheet.has_trait(&"feat.weapon_focus.sanctuary_capture_bow"), "Archer lacks Capture Bow Weapon Focus.", failures)
	_expect(sheet.has_trait(&"feat.patient_overwatch"), "Archer lacks Patient Overwatch.", failures)
	if bow != null:
		_expect(sheet.attack_bonus_for(bow) == 4, "Capture Bow attack is not +4.", failures)
		_expect(sheet.damage_notation_for(bow) == "1d6", "Capture Bow damage is not 1d6.", failures)
	if blackjack != null:
		_expect(sheet.attack_bonus_for(blackjack) == 1, "Archer Blackjack attack is not +1.", failures)
		_expect(sheet.damage_notation_for(blackjack) == "1d6", "Archer Blackjack damage is not 1d6.", failures)
	_expect(
		int(sheet.feature_parameter(&"feat.patient_overwatch", &"reaction_attack_modifier", 0)) == -1,
		"Patient Overwatch does not carry the approved -1 reaction modifier.",
		failures
	)
	_expect(
		sheet.attack_bonus_for(bow) + int(sheet.feature_parameter(
			&"feat.patient_overwatch", &"reaction_attack_modifier", 0
		)) == 3,
		"Patient Overwatch final attack is not +3.",
		failures
	)
	var padded_arrows_found: bool = false
	for item: TacticalItemInstanceState in session.state_store.state.get_items():
		if (
			item != null
			and item.definition_id == &"item.sanctuary.padded_arrows"
			and item.location != null
			and item.location.owner_id == ARCHER_ID
		):
			padded_arrows_found = item.quantity == 18
			break
	_expect(padded_arrows_found, "The Archer does not own 18 authoritative padded arrows.", failures)


static func _test_mercy_bearer(
		session: TacticalSession,
		catalogue: ContentCatalogue,
		failures: Array[String]
) -> void:
	var mercy: TacticalUnitState = session.state_store.state.get_unit(MERCY_ID)
	_expect(mercy != null, "Mercy-Bearer was not deployed.", failures)
	if mercy == null or mercy.resolved_character == null:
		return
	var sheet: ResolvedCharacterSnapshot = mercy.resolved_character
	var blackjack: AttackDefinition = catalogue.attack_definition(&"action.sanctuary.blackjack_attack")
	_expect(sheet.class_name_text == "Cleric 3", "Mercy-Bearer is not Cleric 3.", failures)
	_expect(sheet.ability_score("STR") == 12, "Mercy-Bearer Strength is not 12.", failures)
	_expect(sheet.ability_score("DEX") == 10, "Mercy-Bearer Dexterity is not 10.", failures)
	_expect(sheet.ability_score("CON") == 14, "Mercy-Bearer Constitution is not 14.", failures)
	_expect(sheet.ability_score("WIS") == 16, "Mercy-Bearer Wisdom is not 16.", failures)
	_expect(sheet.ability_score("CHA") == 14, "Mercy-Bearer Charisma is not 14.", failures)
	_expect(mercy.maximum_hp == 24, "Mercy-Bearer HP is not 24.", failures)
	_expect(mercy.armour_class == 17, "Mercy-Bearer AC is not 17.", failures)
	_expect(sheet.stat_value(&"base_attack_bonus") == 2, "Mercy-Bearer BAB is not +2.", failures)
	_expect(sheet.stat_value(&"fortitude") == 5, "Mercy-Bearer Fortitude is not +5.", failures)
	_expect(sheet.stat_value(&"reflex") == 1, "Mercy-Bearer Reflex is not +1.", failures)
	_expect(sheet.stat_value(&"will") == 6, "Mercy-Bearer Will is not +6.", failures)
	if blackjack != null:
		_expect(sheet.attack_bonus_for(blackjack) == 3, "Mercy-Bearer Blackjack attack is not +3.", failures)
		_expect(sheet.damage_notation_for(blackjack) == "1d6+1", "Mercy-Bearer Blackjack damage is not 1d6+1.", failures)
	for feature_id: StringName in [
		&"feat.combat_casting",
		&"feat.augmented_healing",
		&"feat.spell_focus.compulsion",
		&"feature.mercy_intercession",
	]:
		_expect(sheet.has_trait(feature_id), "Mercy-Bearer lacks %s." % feature_id, failures)
	_expect(sheet.concentration_bonus(false) == 6, "Mercy-Bearer normal Concentration is not +6.", failures)
	_expect(sheet.concentration_bonus(true) == 10, "Combat Casting does not produce +10 defensive Concentration.", failures)

	var expected_abilities: Dictionary = {
		&"action.mercy.cure_light_wounds": [1, 8, 5, 0],
		&"action.mercy.cure_moderate_wounds": [2, 8, 7, 0],
		&"action.mercy.command_kneel": [0, 0, 0, 15],
		&"action.mercy.sanctuary": [0, 0, 0, 14],
		&"action.mercy.hold_person": [0, 0, 0, 16],
		&"action.mercy.mercys_rebuke": [2, 6, 3, 15],
		&"action.mercy.guidance": [0, 0, 0, 0],
		&"action.mercy.resistance": [0, 0, 0, 0],
		&"action.mercy.detect_poison": [0, 0, 0, 0],
		&"action.mercy.light": [0, 0, 0, 0],
	}
	var granted: Array[StringName] = session.state_store.state.granted_action_ids_for_unit(MERCY_ID)
	for raw_action_id: Variant in expected_abilities.keys():
		var action_id := StringName(raw_action_id)
		_expect(granted.has(action_id), "Mercy-Bearer does not possess %s." % action_id, failures)
		var ability: TacticalAbilityDefinition = catalogue.action_definition(action_id) as TacticalAbilityDefinition
		_expect(ability != null, "Mercy ability %s is not a tactical ability definition." % action_id, failures)
		if ability == null:
			continue
		var expected: Array = expected_abilities[raw_action_id] as Array
		_expect(ability.dice_count == int(expected[0]), "%s has the wrong dice count." % ability.display_name, failures)
		_expect(ability.die_size == int(expected[1]), "%s has the wrong die size." % ability.display_name, failures)
		_expect(ability.flat_bonus == int(expected[2]), "%s has the wrong flat bonus." % ability.display_name, failures)
		var expected_dc: int = int(expected[3])
		if action_id == &"action.mercy.sanctuary":
			_expect(ability.bonus_value == expected_dc, "Sanctuary is not Will DC 14.", failures)
		elif expected_dc > 0:
			_expect(ability.save_dc == expected_dc, "%s has the wrong save DC." % ability.display_name, failures)
	_expect(mercy.ability_uses(&"resource.mercy.cure_light_wounds") == 2, "Mercy-Bearer does not have two Cure Light uses.", failures)
	_expect(mercy.ability_uses(&"resource.mercy.cure_moderate_wounds") == 1, "Mercy-Bearer does not have one Cure Moderate use.", failures)
	_expect(mercy.ability_uses(&"resource.mercy.intercession") == 1, "Mercy Intercession is not once per encounter.", failures)

	# Exercise one exact healing transaction and prove its resource is spent once.
	var guard: TacticalUnitState = session.state_store.state.get_unit(GUARD_A_ID)
	if guard != null:
		guard.grid_position = mercy.grid_position + Vector2i(1, 0)
		guard.current_hp = 1
		guard.action_incapacitated = false
		mercy.action_budget.refresh_for_new_round()
		var dice_roller: TacticalDiceRoller = (
			session.combat_dice_roller as TacticalDiceRoller
		)
		_expect(dice_roller != null, "The tactical dice roller is unavailable.", failures)
		if dice_roller == null:
			return
		dice_roller.set_scripted_results([4])
		var healing: OperationResult = session.ability_service.execute(
			MERCY_ID,
			&"action.mercy.cure_light_wounds",
			GUARD_A_ID
		)
		_expect(healing.success, "Cure Light Wounds could not execute.", failures)
		_expect(guard.current_hp == 10, "Cure Light Wounds did not apply the approved 1d8+5 total.", failures)
		_expect(mercy.ability_uses(&"resource.mercy.cure_light_wounds") == 1, "Cure Light Wounds did not spend exactly one use.", failures)


static func _test_control_ownership(
		session: TacticalSession,
		failures: Array[String]
) -> void:
	var state: TacticalState = session.state_store.state
	for player_id: StringName in [PROTAGONIST_ID, MARAUDER_A_ID, MARAUDER_B_ID]:
		var player: TacticalUnitState = state.get_unit(player_id)
		_expect(player != null, "Player unit %s is missing." % player_id, failures)
		if player != null:
			_expect(player.is_player_controlled(), "%s is not player-controlled." % player.display_name, failures)
			_expect(not player.participates_in_enemy_turn, "%s incorrectly receives Enemy Turns." % player.display_name, failures)
	for enemy_id: StringName in [GUARD_A_ID, GUARD_B_ID, ARCHER_ID, MERCY_ID]:
		var enemy: TacticalUnitState = state.get_unit(enemy_id)
		_expect(enemy != null, "Enemy unit %s is missing." % enemy_id, failures)
		if enemy != null:
			_expect(enemy.is_ai_controlled(), "%s is not AI-controlled." % enemy.display_name, failures)
			_expect(enemy.participates_in_enemy_turn, "%s does not receive Enemy Turns." % enemy.display_name, failures)
	for civilian_id: StringName in [
		&"character.life.farmhand.0001",
		&"character.life.farmhand.0002",
	]:
		var civilian: TacticalUnitState = state.get_unit(civilian_id)
		_expect(civilian != null, "Civilian %s is missing." % civilian_id, failures)
		if civilian != null:
			_expect(civilian.controller_type == TacticalUnitState.CONTROLLER_WORLD, "%s is not world-controlled." % civilian.display_name, failures)
			_expect(not civilian.participates_in_enemy_turn, "%s incorrectly receives Enemy Turns." % civilian.display_name, failures)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
