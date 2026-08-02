class_name Stage47Hotfix5MarauderMechanicsTests
extends RefCounted

const MISSION_ID: StringName = &"mission_definition.life.farm_storehouse_raid_01"
const MARAUDER_ID: StringName = &"character.reaver.marauder.0001"
const MARAUDER_TWO_ID: StringName = &"character.reaver.marauder.0002"
const GUARD_ID: StringName = &"character.life.sanctuary_spear_guard.0001"


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_raiders_sack_definition_and_loadout(failures)
	_test_legacy_marauder_loadout_migration(failures)
	_test_rage_fatigue_and_badges(failures)
	_test_encumbrance_thresholds(failures)
	_test_restraint_and_raiders_sack_transfer(failures)
	_test_minimum_grapple_pipeline(failures)
	return failures


static func _create_session(failures: Array[String], suffix: String) -> TacticalSession:
	var definition: MissionDefinition = MissionDefinitionRegistry.definition(MISSION_ID)
	_expect(definition != null, "The authored farm mission is not registered.", failures)
	if definition == null:
		return null
	var session: TacticalSession = AuthoredMissionFactory.create_session(
		definition,
		[],
		false,
		"user://stage_4_7_hotfix_5_%s.json" % suffix
	)
	_expect(session != null, "The Hotfix 5 test mission could not be created.", failures)
	return session


static func _test_raiders_sack_definition_and_loadout(failures: Array[String]) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var definition: ItemDefinition = catalogue.item_definition(&"item.raiders_sack")
	_expect(definition != null, "Raider's Sack is not registered.", failures)
	if definition != null:
		_expect(definition.fixed_inventory_fixture, "Raider's Sack is not a fixed fixture.", failures)
		_expect(definition.inventory_footprint == Vector2i(2, 2), "Raider's Sack is not 2x2 on the Belt.", failures)
		_expect(definition.internal_container_size == Vector2i(4, 3), "Raider's Sack does not open to a 4x3 grid.", failures)
		_expect(definition.internal_single_entity_only, "Raider's Sack does not enforce one entity.", failures)
	var template: CharacterTemplateDefinition = catalogue.character_template(
		&"character_template.reaver.marauder_tier_1"
	)
	_expect(template != null, "The production Marauder template is missing.", failures)
	if template == null:
		return
	var sack_count: int = 0
	for entry: Dictionary in template.default_loadout_entries:
		var item_id := StringName(entry.get("definition_id", &""))
		_expect(item_id not in [
			&"item.rations", &"item.empty_sack", &"item.reinforced_captive_carrying_belt",
		], "The Marauder loadout still contains obsolete item %s." % item_id, failures)
		if item_id == &"item.raiders_sack":
			sack_count += 1
			_expect(StringName(entry.get("container_kind", &"")) == TacticalInventoryState.KIND_BELT, "Raider's Sack is not on the Belt.", failures)
			_expect(entry.get("grid_position", Vector2i(-1, -1)) == Vector2i(5, 0), "Raider's Sack does not reserve the rightmost 2x2 Belt cells.", failures)
	_expect(sack_count == 1, "Each Marauder must receive exactly one Raider's Sack.", failures)

	var session: TacticalSession = _create_session(failures, "sack_presence")
	if session != null:
		for marauder_id: StringName in [MARAUDER_ID, MARAUDER_TWO_ID]:
			var deployed_sack: TacticalItemInstanceState = (
				session.state_store.state.raider_sack_item_for_unit(marauder_id)
			)
			_expect(
				deployed_sack != null,
				"Deployed Marauder %s does not contain Raider's Sack." % marauder_id,
				failures
			)
			if deployed_sack != null:
				_expect(deployed_sack.location.container_kind == TacticalInventoryState.KIND_BELT, "The deployed Raider's Sack is not in the Belt.", failures)
				_expect(deployed_sack.location.grid_position == Vector2i(5, 0), "The deployed Raider's Sack is not in the rightmost 2x2 Belt cells.", failures)


static func _test_legacy_marauder_loadout_migration(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var campaign := CampaignState.new()
	TacticalSandboxFactory._ensure_sandbox_campaign(campaign, catalogue)
	var marauder: PersistentCharacterState = campaign.get_character(MARAUDER_ID)
	_expect(marauder != null, "Legacy migration test could not create the Marauder.", failures)
	if marauder == null:
		return

	var sack: CampaignItemState = campaign.get_item(&"instance.marauder.raiders_sack") as CampaignItemState
	var armour: CampaignItemState = campaign.get_item(&"instance.marauder.armour") as CampaignItemState
	if sack != null:
		campaign.remove_item(sack.item_id)
	if armour != null:
		campaign.remove_item(armour.item_id)
	var mace: CampaignItemState = campaign.get_item(&"instance.marauder.mace") as CampaignItemState
	var axe: CampaignItemState = campaign.get_item(&"instance.marauder.axe") as CampaignItemState
	var manacles: CampaignItemState = campaign.get_item(&"instance.marauder.manacles") as CampaignItemState
	var rope: CampaignItemState = campaign.get_item(&"instance.marauder.rope") as CampaignItemState
	if mace != null:
		mace.set_location(CampaignItemLocationState.character_slot(
			MARAUDER_ID, CampaignItemLocationState.CONTAINER_PRIMARY_HAND
		))
	if axe != null:
		axe.set_location(CampaignItemLocationState.character_slot(
			MARAUDER_ID, CampaignItemLocationState.CONTAINER_BACKPACK, Vector2i(0, 0)
		))
	if manacles != null:
		manacles.set_location(CampaignItemLocationState.character_slot(
			MARAUDER_ID, CampaignItemLocationState.CONTAINER_BACKPACK, Vector2i(2, 0)
		))
	if rope != null:
		rope.set_location(CampaignItemLocationState.character_slot(
			MARAUDER_ID, CampaignItemLocationState.CONTAINER_BACKPACK, Vector2i(4, 0)
		))
	var legacy := CampaignItemState.new(
		&"instance.marauder.legacy_carrying_belt",
		&"item.reinforced_captive_carrying_belt",
		1,
		1.0,
		CampaignItemLocationState.character_slot(
			MARAUDER_ID, CampaignItemLocationState.CONTAINER_BACKPACK, Vector2i(6, 0)
		)
	)
	campaign.add_item(legacy)

	TacticalSandboxFactory._ensure_sandbox_campaign(campaign, catalogue)
	var errors: Array[String] = CampaignItemValidator.validate_campaign(campaign, catalogue)
	_expect(errors.is_empty(), "Legacy Marauder loadout migration is invalid: %s" % (errors[0] if not errors.is_empty() else ""), failures)
	var repaired_sack: CampaignItemState = campaign.get_item(&"instance.marauder.raiders_sack") as CampaignItemState
	var repaired_armour: CampaignItemState = campaign.get_item(&"instance.marauder.armour") as CampaignItemState
	_expect(repaired_sack != null, "Legacy migration did not add Raider's Sack.", failures)
	_expect(repaired_armour != null, "Legacy migration did not restore Patchwork Raider Armour.", failures)
	if repaired_sack != null:
		_expect(repaired_sack.location.container_id == CampaignItemLocationState.CONTAINER_BELT, "Migrated Raider's Sack is not on the Belt.", failures)
		_expect(repaired_sack.location.grid_position == Vector2i(5, 0), "Migrated Raider's Sack is not in the rightmost 2x2 cells.", failures)
	_expect(campaign.get_item(legacy.item_id) == null, "Deprecated carrying belt survived migration.", failures)
	if mace != null:
		_expect(mace.location.container_id == CampaignItemLocationState.CONTAINER_BELT, "Migration did not return the Mace to the Belt.", failures)
	if axe != null:
		_expect(axe.location.container_id == CampaignItemLocationState.CONTAINER_PRIMARY_HAND, "Migration did not return Raider's Axe to Primary Hand.", failures)


static func _test_rage_fatigue_and_badges(failures: Array[String]) -> void:
	var session: TacticalSession = _create_session(failures, "rage")
	if session == null:
		return
	var unit: TacticalUnitState = session.state_store.state.get_unit(MARAUDER_ID)
	_expect(unit != null, "Marauder was not deployed for Rage testing.", failures)
	if unit == null:
		return
	_expect(session.set_character_modifier_active(MARAUDER_ID, &"effect.rage", true), "Rage could not be activated.", failures)
	var raging: ResolvedCharacterSnapshot = unit.resolved_character
	_expect(raging.ability_score("STR") == 19, "Rage Strength is not 19.", failures)
	_expect(raging.ability_score("CON") == 18, "Rage Constitution is not 18.", failures)
	_expect(unit.maximum_hp == 38, "Rage maximum HP is not 38.", failures)
	_expect(unit.armour_class == 12, "Rage AC is not 12.", failures)
	_expect(raging.stat_value(&"fortitude") == 7, "Rage Fortitude is not +7.", failures)
	_expect(raging.stat_value(&"will") == 4, "Rage Will is not +4.", failures)
	_expect(raging.stat_value(&"grapple") == 7, "Rage Grapple is not +7.", failures)
	_expect(unit.rage_rounds_remaining == 7, "Rage did not start at seven rounds.", failures)
	var rage_badge: Dictionary = TacticalStatusBadgeProvider.for_unit(unit)
	_expect(StringName(rage_badge.get("condition_kind", &"")) == TacticalStatusBadgeProvider.CONDITION_KIND_RAGE, "Rage token badge is missing.", failures)
	var calm_reason: String = session.screen_facade.action_unavailable_reason(
		MARAUDER_ID, &"action.mercy.hold_person"
	)
	_expect(calm_reason.contains("Raging"), "Rage does not reject concentration actions.", failures)
	_expect(session.set_character_modifier_active(MARAUDER_ID, &"effect.rage", false), "Rage could not be ended.", failures)
	var fatigued: ResolvedCharacterSnapshot = unit.resolved_character
	_expect(fatigued.ability_score("STR") == 13, "Fatigued Strength is not 13.", failures)
	_expect(fatigued.ability_score("DEX") == 11, "Fatigued Dexterity is not 11.", failures)
	_expect(unit.sprint_distance_feet == 0, "Fatigued Marauder can still Sprint.", failures)
	var fatigue_badge: Dictionary = TacticalStatusBadgeProvider.for_unit(unit)
	_expect(StringName(fatigue_badge.get("condition_kind", &"")) == TacticalStatusBadgeProvider.CONDITION_KIND_FATIGUED, "Fatigued token badge is missing.", failures)


static func _test_encumbrance_thresholds(failures: Array[String]) -> void:
	var session: TacticalSession = _create_session(failures, "encumbrance")
	if session == null:
		return
	var state: TacticalState = session.state_store.state
	var unit: TacticalUnitState = state.get_unit(MARAUDER_ID)
	if unit == null:
		failures.append("Marauder was not deployed for encumbrance testing.")
		return
	var current: float = state.calculated_carried_weight(MARAUDER_ID)
	var medium_delta: float = maxf(0.1, 117.0 - current)
	var medium_item: TacticalItemInstanceState = _test_weight_item(
		&"test.hotfix5.medium_weight", medium_delta, MARAUDER_ID, Vector2i(8, 0)
	)
	_expect(state.add_item(medium_item, session.map_definition, false), "Medium-load test item could not be added.", failures)
	state.refresh_unit_encumbrance(MARAUDER_ID)
	_expect(unit.load_category == TacticalUnitState.LOAD_MEDIUM, "117 lb did not resolve as Medium load.", failures)
	_expect(unit.action_budget.maximum_turn_capacity_feet == 60, "Medium load did not set 60-foot capacity.", failures)
	_expect(unit.sprint_distance_feet == 90, "Medium load did not set 90-foot Sprint.", failures)
	var heavy_delta: float = maxf(0.1, 234.0 - state.calculated_carried_weight(MARAUDER_ID))
	var heavy_item: TacticalItemInstanceState = _test_weight_item(
		&"test.hotfix5.heavy_weight", heavy_delta, MARAUDER_ID, Vector2i(8, 1)
	)
	_expect(state.add_item(heavy_item, session.map_definition, false), "Heavy-load test item could not be added.", failures)
	state.refresh_unit_encumbrance(MARAUDER_ID)
	_expect(unit.load_category == TacticalUnitState.LOAD_HEAVY, "234 lb did not resolve as Heavy load.", failures)
	_expect(unit.action_budget.maximum_turn_capacity_feet == 40, "Heavy load did not set 40-foot capacity.", failures)
	_expect(unit.sprint_distance_feet == 0, "Heavy load did not prohibit Sprint.", failures)
	state.remove_item(medium_item.item_id, false)
	state.remove_item(heavy_item.item_id, false)
	state.refresh_unit_encumbrance(MARAUDER_ID)
	_expect(unit.load_category == TacticalUnitState.LOAD_LIGHT, "Removing weight did not restore Light load.", failures)
	_expect(unit.action_budget.maximum_turn_capacity_feet == 80, "Light load did not restore 80-foot capacity.", failures)
	_expect(unit.sprint_distance_feet == 120, "Light load did not restore 120-foot Sprint.", failures)


static func _test_weight_item(
		item_id: StringName,
		weight: float,
		unit_id: StringName,
		position: Vector2i
) -> TacticalItemInstanceState:
	var definition := ItemDefinition.new()
	definition.id = StringName("definition.%s" % item_id)
	definition.display_name = "Hotfix 5 Test Weight"
	definition.weight_lb = weight
	definition.inventory_footprint = Vector2i.ONE
	definition.backpack_allowed = true
	return TacticalItemInstanceState.new(
		item_id,
		definition,
		1,
		1.0,
		TacticalItemLocationState.unit_grid(
			unit_id, TacticalInventoryState.KIND_BACKPACK, position
		)
	)


static func _test_restraint_and_raiders_sack_transfer(failures: Array[String]) -> void:
	var session: TacticalSession = _create_session(failures, "sack")
	if session == null:
		return
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(MARAUDER_ID)
	var guard: TacticalUnitState = state.get_unit(GUARD_ID)
	if marauder == null or guard == null:
		failures.append("Marauder or Guard is missing for Raider's Sack testing.")
		return
	_expect(_place_adjacent(state, marauder, guard, session.map_definition), "Could not place Guard adjacent to Marauder.", failures)
	guard.apply_damage(guard.current_hp, TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL)
	guard.record_nonlethal_incapacitation(marauder.unit_id, &"test.hotfix5.nonlethal")
	state.synchronise_body_items(session.map_definition)
	var body_item: TacticalItemInstanceState = state.body_item_for_unit(guard.unit_id)
	var manacles: TacticalItemInstanceState = _owned_item_by_definition(
		state, marauder.unit_id, &"item.manacles"
	)
	_expect(body_item != null, "Guard body item was not created.", failures)
	if body_item != null:
		_expect(body_item.footprint == Vector2i(4, 3), "Medium body footprint is not 4x3.", failures)
	_expect(manacles != null, "Marauder manacles are missing.", failures)
	if body_item == null or manacles == null:
		return
	var restrained: OperationResult = session.body_action_handler.restrain(
		marauder.unit_id, body_item.item_id, manacles.item_id
	)
	_expect(restrained.success, "Take Them Alive restraint failed: %s" % restrained.message, failures)
	_expect(guard.restrained, "Guard was not marked Restrained.", failures)
	_expect(manacles.quantity == 1, "Applying restraints did not split one manacle set.", failures)
	_expect(not marauder.action_budget.quick_action_available, "Take Them Alive did not spend the Quick Action.", failures)
	var loaded: OperationResult = session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			marauder.unit_id,
			TacticalItemLocationState.CONTAINER_GROUND,
			body_item.item_id,
			TacticalInventoryState.KIND_RAIDER_SACK,
			0
		)
	)
	_expect(loaded.success, "Captive could not enter Raider's Sack: %s" % loaded.message, failures)
	_expect(body_item.location.owner_id == marauder.unit_id, "Raider's Sack did not retain carrier ownership.", failures)
	_expect(body_item.location.container_kind == TacticalInventoryState.KIND_RAIDER_SACK, "Captive is not in Raider's Sack.", failures)
	_expect(state.raider_sack_body_for_unit(marauder.unit_id) == body_item, "Raider's Sack did not preserve body identity.", failures)
	_expect(state.get_hand_item(marauder.unit_id, TacticalInventoryState.KIND_SECONDARY_HAND) == null, "Raider's Sack occupied the free hand.", failures)
	var released: OperationResult = session.inventory_transfer_handler.execute(
		TacticalInventoryTransferCommand.new(
			marauder.unit_id,
			TacticalInventoryState.KIND_RAIDER_SACK,
			body_item.item_id,
			TacticalItemLocationState.CONTAINER_GROUND,
			-1
		)
	)
	_expect(released.success, "Captive could not leave Raider's Sack: %s" % released.message, failures)
	_expect(body_item.location.location_type == TacticalItemLocationState.LOCATION_TACTICAL_GROUND, "Released captive did not return to the ground.", failures)
	_expect(state.get_item(body_item.item_id) == body_item, "Captive item identity changed during Sack transfer.", failures)


static func _test_minimum_grapple_pipeline(failures: Array[String]) -> void:
	var session: TacticalSession = _create_session(failures, "grapple")
	if session == null:
		return
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(MARAUDER_ID)
	var guard: TacticalUnitState = state.get_unit(GUARD_ID)
	if marauder == null or guard == null:
		failures.append("Marauder or Guard is missing for Grapple testing.")
		return
	_expect(_place_adjacent(state, marauder, guard, session.map_definition), "Could not place Grapple target adjacent.", failures)
	var before: int = marauder.action_budget.remaining_turn_capacity_feet
	var result: OperationResult = session.grapple_handler.initiate(
		marauder.unit_id, guard.unit_id
	)
	_expect(result.success, "Grapple action did not resolve: %s" % result.message, failures)
	_expect(marauder.action_budget.remaining_turn_capacity_feet == before - 40, "Grapple did not spend one Half Action.", failures)
	if marauder.is_grappling():
		_expect(guard.grappled_by_unit_id == marauder.unit_id, "Successful Grapple did not preserve controller identity.", failures)
		var released: OperationResult = session.grapple_handler.release(marauder.unit_id)
		_expect(released.success, "Grapple controller could not release the hold.", failures)


static func _place_adjacent(
		state: TacticalState,
		actor: TacticalUnitState,
		target: TacticalUnitState,
		map_definition: TacticalMapDefinition
) -> bool:
	for offset: Vector2i in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]:
		var candidate: Vector2i = actor.grid_position + offset
		if state.set_unit_position(target.unit_id, candidate, map_definition, false):
			return true
	return false


static func _owned_item_by_definition(
		state: TacticalState,
		unit_id: StringName,
		definition_id: StringName
) -> TacticalItemInstanceState:
	for item: TacticalItemInstanceState in state.get_items():
		if (
			item.definition_id == definition_id
			and item.location != null
			and item.location.owner_id == unit_id
		):
			return item
	return null


static func _expect(value: bool, message: String, failures: Array[String]) -> void:
	if not value:
		failures.append(message)
