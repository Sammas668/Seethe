class_name Stage312CharacterSystemTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_catalogue_and_session_validate(failures)
	_test_marauder_baseline_resolution(failures)
	_test_rage_recalculates_from_sources(failures)
	_test_template_generates_unique_individual_items(failures)
	_test_player_enemy_and_neutral_generation(failures)
	_test_campaign_round_trip_preserves_identity_and_items(failures)
	_test_mission_scope_is_not_saved(failures)
	_test_deployment_and_redeployment(failures)
	_test_runtime_recalculation_preserves_spent_state(failures)
	_test_character_sheet_uses_resolved_snapshot(failures)
	_test_portrait_resolution_and_persistence(failures)
	return failures


static func _test_catalogue_and_session_validate(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	_expect(
		session.content_catalogue.validate_catalogue().is_empty(),
		"Stage 3.12 content catalogue must validate.",
		failures
	)
	_expect(
		session.validate_session().is_empty(),
		"Stage 3.14 tactical session must validate.",
		failures
	)


static func _marauder_fixture(
		character_id: StringName
) -> Dictionary:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var template: CharacterTemplateDefinition = catalogue.character_template(
		TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	)
	var character: PersistentCharacterState = CharacterFactory.create_player_character(
		template,
		character_id,
		"Test Marauder"
	)
	var items: Array[CampaignItemState] = CharacterFactory.create_default_item_states(
		template,
		character_id
	)
	return {
		"catalogue": catalogue,
		"template": template,
		"character": character,
		"items": items,
	}


static func _test_marauder_baseline_resolution(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _marauder_fixture(&"character.test.marauder.baseline")
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var character: PersistentCharacterState = (
		fixture.get("character") as PersistentCharacterState
	)
	var items: Array[CampaignItemState] = []
	for value: Variant in fixture.get("items", []):
		items.append(value as CampaignItemState)
	var snapshot: ResolvedCharacterSnapshot = (
		CharacterResolutionService.new(catalogue).resolve_character(
			character,
			[],
			items
		)
	)

	_expect(snapshot.ability_score("STR") == 15, "Marauder STR must resolve to 15.", failures)
	_expect(snapshot.ability_score("CON") == 14, "Marauder CON must resolve to 14.", failures)
	_expect(snapshot.stat_value(&"maximum_hp") == 32, "Marauder HP must resolve to 32.", failures)
	_expect(snapshot.stat_value(&"armour_class") == 14, "Marauder AC must resolve to 14.", failures)
	_expect(snapshot.stat_value(&"initiative") == 1, "Marauder Initiative must resolve to +1.", failures)
	_expect(snapshot.stat_value(&"turn_capacity") == 80, "Marauder capacity must resolve to 80 ft.", failures)
	_expect(snapshot.stat_value(&"half_action_cost") == 40, "Marauder Half Action must resolve to 40 ft.", failures)
	_expect(snapshot.stat_value(&"sprint_distance") == 120, "Marauder Sprint must resolve to 120 ft.", failures)
	_expect(snapshot.stat_value(&"base_attack_bonus") == 3, "Marauder BAB must resolve to +3.", failures)
	_expect(snapshot.stat_value(&"fortitude") == 5, "Marauder Fortitude must resolve to +5.", failures)
	_expect(snapshot.stat_value(&"reflex") == 2, "Marauder Reflex must resolve to +2.", failures)
	_expect(snapshot.stat_value(&"will") == 2, "Marauder Will must resolve to +2.", failures)
	_expect(snapshot.stat_value(&"grapple") == 5, "Marauder Grapple must resolve to +5.", failures)
	_expect(snapshot.stat_value(&"passive_perception") == 17, "Marauder Passive Perception must resolve to 17.", failures)

	var axe: AttackDefinition = catalogue.attack_definition(&"action.raiders_axe_attack")
	var thrown: AttackDefinition = catalogue.attack_definition(
		&"action.reaver_thrown_dagger_attack"
	)
	_expect(snapshot.attack_bonus_for(axe) == 5, "Raider's Axe attack must resolve to +5.", failures)
	_expect(snapshot.damage_notation_for(axe) == "1d8+2", "Raider's Axe damage must resolve to 1d8+2.", failures)
	_expect(snapshot.attack_bonus_for(thrown) == 4, "Thrown Dagger attack must resolve to +4.", failures)


static func _test_rage_recalculates_from_sources(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _marauder_fixture(&"character.test.marauder.rage")
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var character: PersistentCharacterState = (
		fixture.get("character") as PersistentCharacterState
	)
	var items: Array = fixture.get("items", [])
	var modifiers: Array[StringName] = [&"effect.rage"]
	var snapshot: ResolvedCharacterSnapshot = (
		CharacterResolutionService.new(catalogue).resolve_character(
			character,
			modifiers,
			items
		)
	)
	_expect(snapshot.ability_score("STR") == 19, "Rage must resolve STR 15 to 19.", failures)
	_expect(snapshot.ability_score("CON") == 18, "Rage must resolve CON 14 to 18.", failures)
	_expect(snapshot.stat_value(&"maximum_hp") == 38, "Rage must resolve HP 32 to 38.", failures)
	_expect(snapshot.stat_value(&"armour_class") == 12, "Rage must resolve AC 14 to 12.", failures)
	_expect(snapshot.stat_value(&"fortitude") == 7, "Rage must resolve Fortitude +5 to +7.", failures)
	_expect(snapshot.stat_value(&"will") == 4, "Rage must resolve Will +2 to +4.", failures)


static func _test_template_generates_unique_individual_items(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var template: CharacterTemplateDefinition = catalogue.character_template(
		TacticalSandboxFactory.MARAUDER_TEMPLATE_ID
	)
	var first_items: Array[CampaignItemState] = CharacterFactory.create_default_item_states(
		template,
		&"character.test.marauder.one"
	)
	var second_items: Array[CampaignItemState] = CharacterFactory.create_default_item_states(
		template,
		&"character.test.marauder.two"
	)
	var first_ids: Dictionary = {}
	for item: CampaignItemState in first_items:
		first_ids[item.item_id] = true
	for item: CampaignItemState in second_items:
		_expect(
			not first_ids.has(item.item_id),
			"Two individuals generated from one template must have unique item IDs.",
			failures
		)
	for authored_entry: Dictionary in template.default_loadout_entries:
		_expect(
			not authored_entry.has("instance_id"),
			"Authored templates must not own persistent item instance IDs.",
			failures
		)


static func _test_player_enemy_and_neutral_generation(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var player: PersistentCharacterState = CharacterFactory.create_player_character(
		catalogue.character_template(TacticalSandboxFactory.MARAUDER_TEMPLATE_ID),
		&"character.test.player",
		"Player"
	)
	var enemy: PersistentCharacterState = CharacterFactory.create_enemy_character(
		catalogue.character_template(TacticalSandboxFactory.ENEMY_TEMPLATE_ID),
		&"character.test.enemy",
		"Enemy",
		&"faction.test.enemy"
	)
	var neutral: PersistentCharacterState = CharacterFactory.create_neutral_character(
		catalogue.character_template(TacticalSandboxFactory.NEUTRAL_TEMPLATE_ID),
		&"character.test.neutral",
		"Neutral",
		&"faction.test.neutral",
		PersistentCharacterState.PERSISTENCE_REGION
	)
	_expect(player.roster_role == PersistentCharacterState.ROLE_PLAYER, "Player role must be preserved.", failures)
	_expect(enemy.roster_role == PersistentCharacterState.ROLE_ENEMY, "Enemy role must be preserved.", failures)
	_expect(neutral.roster_role == PersistentCharacterState.ROLE_NEUTRAL, "Neutral role must be preserved.", failures)


static func _test_campaign_round_trip_preserves_identity_and_items(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _marauder_fixture(&"character.test.round_trip")
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	var template: CharacterTemplateDefinition = fixture.get("template") as CharacterTemplateDefinition
	character.award_xp(450)
	character.set_level_adjustment(1)
	character.add_injury("Scarred shoulder", {"armour_class": -1})
	character.add_history("Survived the test mission.")

	var campaign: CampaignState = CampaignState.new()
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(campaign, character, template)
	var restored: CampaignState = CampaignState.from_dictionary(
		campaign.to_dictionary()
	)
	var restored_character: PersistentCharacterState = restored.get_character(
		character.character_id
	)
	_expect(restored_character != null, "Saved named character must reload by the same ID.", failures)
	if restored_character == null:
		return
	_expect(restored_character.xp == character.xp, "Character XP must survive save/load.", failures)
	_expect(restored.items_for_character(character.character_id).size() == campaign.items_for_character(character.character_id).size(), "Campaign-owned character equipment must survive save/load.", failures)
	var serialized_campaign: Dictionary = restored.to_dictionary()
	var serialized_characters: Array = serialized_campaign.get("characters", [])
	if not serialized_characters.is_empty():
		var serialized_character: Dictionary = serialized_characters[0] as Dictionary
		_expect(not serialized_character.has("loadout_entries"), "Characters must not serialize duplicate item data.", failures)


static func _test_mission_scope_is_not_saved(
		failures: Array[String]
) -> void:
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var campaign: CampaignState = CampaignState.new()
	var mission_enemy: PersistentCharacterState = CharacterFactory.create_enemy_character(
		catalogue.character_template(TacticalSandboxFactory.ENEMY_TEMPLATE_ID),
		&"character.test.enemy.mission",
		"Mission Enemy",
		&"faction.test"
	)
	var region_enemy: PersistentCharacterState = CharacterFactory.create_enemy_character(
		catalogue.character_template(TacticalSandboxFactory.ENEMY_TEMPLATE_ID),
		&"character.test.enemy.region",
		"Region Enemy",
		&"faction.test",
		PersistentCharacterState.PERSISTENCE_REGION
	)
	campaign.add_character(mission_enemy)
	campaign.add_character(region_enemy)
	var restored: CampaignState = CampaignState.from_dictionary(campaign.to_dictionary())
	_expect(restored.get_character(mission_enemy.character_id) == null, "Mission-only characters must not enter the campaign save.", failures)
	_expect(restored.get_character(region_enemy.character_id) != null, "Region-persistent enemies must survive save/load.", failures)


static func _test_deployment_and_redeployment(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _marauder_fixture(&"character.test.redeploy")
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	var items: Array[CampaignItemState] = []
	for value: Variant in fixture.get("items", []):
		items.append(value as CampaignItemState)
	var service: CharacterResolutionService = CharacterResolutionService.new(catalogue)
	var deployer: TacticalCharacterDeploymentService = TacticalCharacterDeploymentService.new(catalogue, service)

	var first_state: TacticalState = TacticalState.new()
	var first_unit: TacticalUnitState = deployer.deploy_character(
		first_state,
		character,
		Vector2i(12, 12),
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		[],
		items
	)
	_expect(first_unit != null, "Persistent character must deploy into a tactical unit.", failures)
	if first_unit == null:
		return
	_expect(first_state.get_items().size() == items.size(), "Deployment must instantiate campaign-owned equipment.", failures)

	var item_ids: Dictionary = {}
	for item: TacticalItemInstanceState in first_state.get_items():
		item_ids[item.item_id] = true
	var second_state: TacticalState = TacticalState.new()
	var second_unit: TacticalUnitState = deployer.deploy_character(
		second_state,
		character,
		Vector2i(13, 13),
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		[],
		items
	)
	_expect(second_unit != null, "The same individual must redeploy.", failures)
	for item: TacticalItemInstanceState in second_state.get_items():
		_expect(item_ids.has(item.item_id), "Redeployment must preserve item IDs.", failures)


static func _test_runtime_recalculation_preserves_spent_state(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _marauder_fixture(&"character.test.runtime")
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	var items: Array[CampaignItemState] = []
	for value: Variant in fixture.get("items", []):
		items.append(value as CampaignItemState)
	var service: CharacterResolutionService = CharacterResolutionService.new(catalogue)
	var state: TacticalState = TacticalState.new()
	var unit: TacticalUnitState = TacticalCharacterDeploymentService.new(
		catalogue,
		service
	).deploy_character(
		state,
		character,
		Vector2i(14, 14),
		TacticalSandboxFactory.MOVEMENT_TEST_MAP,
		[],
		items
	)
	if unit == null:
		_expect(false, "Runtime recalculation fixture must deploy.", failures)
		return
	unit.current_hp = 27
	unit.action_budget.spend_normal_capacity(20)
	unit.action_budget.spend_quick_action()
	unit.set_character_modifier_active(&"effect.rage", true)
	service.refresh_tactical_unit(unit, character, state.get_items())
	_expect(unit.maximum_hp == 38, "Rage refresh must update maximum HP.", failures)
	_expect(unit.current_hp == 33, "Rage refresh must preserve existing damage.", failures)
	unit.set_character_modifier_active(&"effect.rage", false)
	service.refresh_tactical_unit(unit, character, state.get_items())
	_expect(unit.maximum_hp == 32, "Ending Rage must restore maximum HP.", failures)


static func _test_character_sheet_uses_resolved_snapshot(
		failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var unit: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(unit != null, "Character Sheet fixture must include the Marauder.", failures)
	if unit == null:
		return
	_expect(unit.character_sheet.resolved_snapshot == unit.resolved_character, "Character Sheet must use the resolved snapshot.", failures)
	_expect(unit.character_sheet.stat_value(&"armour_class") == 14, "Character Sheet must display resolved AC.", failures)


static func _test_portrait_resolution_and_persistence(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _marauder_fixture(&"character.test.portrait")
	var catalogue: ContentCatalogue = fixture.get("catalogue") as ContentCatalogue
	var template: CharacterTemplateDefinition = fixture.get("template") as CharacterTemplateDefinition
	var character: PersistentCharacterState = fixture.get("character") as PersistentCharacterState
	template.portrait_id = &"portrait.test.template"
	var service: CharacterResolutionService = CharacterResolutionService.new(catalogue)
	var fallback_snapshot: ResolvedCharacterSnapshot = service.resolve_character(character)
	_expect(fallback_snapshot.portrait_id == &"portrait.test.template", "Template portrait fallback must resolve.", failures)
	character.set_portrait_override_id(TacticalSandboxFactory.HAKON_PORTRAIT_ID)
	var override_snapshot: ResolvedCharacterSnapshot = service.resolve_character(character)
	_expect(override_snapshot.portrait_id == TacticalSandboxFactory.HAKON_PORTRAIT_ID, "Named portrait override must resolve.", failures)
	var restored: PersistentCharacterState = PersistentCharacterState.from_dictionary(character.to_dictionary())
	_expect(restored.portrait_override_id == TacticalSandboxFactory.HAKON_PORTRAIT_ID, "Portrait override must survive save/load.", failures)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
