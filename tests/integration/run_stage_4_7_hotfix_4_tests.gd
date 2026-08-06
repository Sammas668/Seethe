extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var campaign: CampaignState = CampaignState.new()
	var template: CharacterTemplateDefinition = catalogue.character_template(&"character_template.reaver.marauder_tier_1")
	var character: PersistentCharacterState = CharacterFactory.create_player_character(template, &"test.marauder", "Test Marauder")
	campaign.add_character(character)
	CharacterFactory.add_default_loadout_to_campaign(campaign, character, template)
	var service := CharacterResolutionService.new(); service.configure(catalogue)
	var normal: ResolvedCharacterSnapshot = service.resolve_character(character, [], campaign.items_for_character(character.character_id))
	_expect(normal.ability_score("DEX") == 13, "DEX must be 13.", failures)
	_expect(normal.ability_score("CHA") == 8, "CHA must be 8.", failures)
	_expect(normal.stat_value(&"maximum_hp") == 32, "Normal HP must be 32.", failures)
	_expect(normal.stat_value(&"fortitude") == 5, "Normal Fortitude must be +5.", failures)
	_expect(normal.stat_value(&"reflex") == 2, "Normal Reflex must be +2.", failures)
	_expect(normal.stat_value(&"will") == 2, "Normal Will must be +2.", failures)
	_expect(normal.stat_value(&"maximum_weight_lb") == 350, "Normal maximum load must be 350 lb.", failures)
	var raging: ResolvedCharacterSnapshot = service.resolve_character(character, [&"effect.rage"], campaign.items_for_character(character.character_id))
	_expect(raging.ability_score("STR") == 19, "Raging Strength must be 19.", failures)
	_expect(raging.ability_score("CON") == 18, "Raging Constitution must be 18.", failures)
	_expect(raging.stat_value(&"maximum_hp") == 38, "Raging HP must be 38.", failures)
	_expect(raging.stat_value(&"armour_class") == 12, "Raging AC must be 12.", failures)
	_expect(raging.stat_value(&"fortitude") == 7, "Raging Fortitude must be +7.", failures)
	_expect(raging.stat_value(&"will") == 4, "Raging Will must be +4.", failures)
	_expect(raging.stat_value(&"maximum_weight_lb") == 600, "Raging maximum load must be 600 lb.", failures)
	if failures.is_empty(): print("Stage 4.7 Hotfix 4 runtime sheet tests PASSED.")
	else:
		for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _expect(value: bool, message: String, failures: Array[String]) -> void:
	if not value: failures.append(message)
