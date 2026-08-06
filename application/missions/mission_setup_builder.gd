class_name MissionSetupBuilder
extends RefCounted


static func create_from_campaign(
		campaign: CampaignState,
		character_ids: Array[StringName],
		mission_id_value: StringName,
		source_revision_override: int = -1,
		mission_seed_value: int = 0
) -> MissionSetupSnapshot:
	# Returns a mutable setup draft. Call finalize_setup() after all mission-only
	# characters, ground items and intended participants have been added.
	var result: MissionSetupSnapshot = MissionSetupSnapshot.new()
	var source_revision: int = (
		source_revision_override
		if source_revision_override >= 0
		else (campaign.revision if campaign != null else 0)
	)
	result.configure_identity(mission_id_value, source_revision)
	result.configure_mission_seed(maxi(0, mission_seed_value))
	if campaign == null:
		return result

	for character_id: StringName in character_ids:
		var source_character: PersistentCharacterState = campaign.get_character(
			character_id
		)
		if source_character == null:
			continue
		result.add_character_copy(source_character)
		for item: CampaignItemState in campaign.items_for_character(character_id):
			result.add_item_copy(item)
		if source_character.team_id == &"player":
			result.append_player_unit(character_id)
	return result


static func configure_authored_mission(
		setup: MissionSetupSnapshot,
		definition: MissionDefinition,
		protagonist_character_id: StringName
) -> bool:
	if setup == null or setup.is_finalized() or definition == null:
		return false
	return setup.configure_authored_mission(definition, protagonist_character_id)


static func configure_mission_definition(
		setup: MissionSetupSnapshot,
		map_definition: TacticalMapDefinition,
		protagonist_character_id: StringName
) -> bool:
	if setup == null or setup.is_finalized():
		return false
	return setup.configure_mission_definition(
		map_definition, protagonist_character_id
	)


static func add_isolated_character(
		setup: MissionSetupSnapshot,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition = null,
		instance_id_by_definition_id: Dictionary = {}
) -> bool:
	if setup == null or setup.is_finalized() or character == null:
		return false
	var item_states: Array[CampaignItemState] = []
	if template != null:
		item_states = CharacterFactory.create_default_item_states(
			template,
			character.character_id,
			instance_id_by_definition_id
		)
	return setup.add_isolated_character(character, item_states)


static func mark_intended_participants(
		setup: MissionSetupSnapshot,
		character_ids: Array[StringName]
) -> bool:
	if setup == null or setup.is_finalized():
		return false
	for character_id: StringName in character_ids:
		if not setup.mark_deployed(character_id):
			return false
	return true


static func finalize_setup(setup: MissionSetupSnapshot) -> OperationResult:
	if setup == null:
		return OperationResult.fail(
			&"mission_setup_missing",
			"No mission setup draft was supplied."
		)
	var errors: Array[String] = setup.finalize()
	if not errors.is_empty():
		return OperationResult.fail(
			&"mission_setup_invalid",
			errors[0]
		)
	return OperationResult.ok(setup, "Mission setup finalized.")
