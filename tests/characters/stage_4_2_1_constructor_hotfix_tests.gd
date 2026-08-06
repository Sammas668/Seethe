class_name Stage421ConstructorHotfixTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var catalogue: ContentCatalogue = SandboxContentCatalogueFactory.create_catalogue()
	var service: CharacterResolutionService = CharacterResolutionService.new()
	service.configure(catalogue)
	var character: PersistentCharacterState = CharacterFactory.create_player_character(
		catalogue.character_template(TacticalSandboxFactory.MARAUDER_TEMPLATE_ID),
		&"character.test.stage_4_2_1",
		"Constructor Test"
	)
	var snapshot: ResolvedCharacterSnapshot = service.resolve_character(character)
	if snapshot.template_id.is_empty():
		failures.append("Configured CharacterResolutionService did not resolve a character.")
	return failures
