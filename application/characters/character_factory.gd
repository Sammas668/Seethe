class_name CharacterFactory
extends RefCounted


static func create_character(
		template: CharacterTemplateDefinition,
		character_id: StringName,
		display_name: String,
		faction_id: StringName,
		team_id: StringName,
		roster_role: StringName,
		persistence_scope: StringName
) -> PersistentCharacterState:
	var result: PersistentCharacterState = PersistentCharacterState.new()
	if template == null:
		return result

	result.character_id = character_id
	result.template_id = template.id
	result.display_name = display_name
	result.faction_id = faction_id
	result.team_id = team_id
	result.roster_role = roster_role
	result.persistence_scope = persistence_scope
	result.xp = template.base_xp
	result.equipped_defence_profile_id = template.default_defence_profile_id
	return result


static func create_player_character(
		template: CharacterTemplateDefinition,
		character_id: StringName,
		display_name: String,
		faction_id: StringName = &"faction.fifth_god"
) -> PersistentCharacterState:
	return create_character(
		template,
		character_id,
		display_name,
		faction_id,
		&"player",
		PersistentCharacterState.ROLE_PLAYER,
		PersistentCharacterState.PERSISTENCE_CAMPAIGN
	)


static func create_enemy_character(
		template: CharacterTemplateDefinition,
		character_id: StringName,
		display_name: String,
		faction_id: StringName,
		persistence_scope: StringName = PersistentCharacterState.PERSISTENCE_MISSION
) -> PersistentCharacterState:
	return create_character(
		template,
		character_id,
		display_name,
		faction_id,
		&"enemy",
		PersistentCharacterState.ROLE_ENEMY,
		persistence_scope
	)


static func create_neutral_character(
		template: CharacterTemplateDefinition,
		character_id: StringName,
		display_name: String,
		faction_id: StringName,
		persistence_scope: StringName = PersistentCharacterState.PERSISTENCE_MISSION
) -> PersistentCharacterState:
	return create_character(
		template,
		character_id,
		display_name,
		faction_id,
		&"neutral",
		PersistentCharacterState.ROLE_NEUTRAL,
		persistence_scope
	)


static func add_default_loadout_to_campaign(
		campaign: CampaignState,
		character: PersistentCharacterState,
		template: CharacterTemplateDefinition,
		instance_id_by_definition_id: Dictionary = {}
) -> Array[StringName]:
	var added_ids: Array[StringName] = []
	if campaign == null or character == null or template == null:
		return added_ids

	for item: CampaignItemState in create_default_item_states(
		template,
		character.character_id,
		instance_id_by_definition_id
	):
		item.item_id = campaign.unique_item_id(item.item_id)
		if campaign.add_item(item):
			added_ids.append(item.item_id)
	return added_ids


static func create_default_item_states(
		template: CharacterTemplateDefinition,
		character_id: StringName,
		instance_id_by_definition_id: Dictionary = {}
) -> Array[CampaignItemState]:
	var result: Array[CampaignItemState] = []
	if template == null or character_id.is_empty():
		return result

	for index: int in range(template.default_loadout_entries.size()):
		var entry: Dictionary = template.default_loadout_entries[index].duplicate(true)
		var definition_id: StringName = StringName(entry.get("definition_id", &""))
		if definition_id.is_empty():
			continue
		var preferred_instance_id: StringName = StringName(
			instance_id_by_definition_id.get(definition_id, &"")
		)
		if preferred_instance_id.is_empty():
			preferred_instance_id = StringName(
				"%s.item.%02d.%s"
				% [character_id, index + 1, String(definition_id).replace(".", "_")]
			)
		var container_id: StringName = StringName(
			entry.get("container_kind", CampaignItemLocationState.CONTAINER_BACKPACK)
		)
		var grid_position: Vector2i = entry.get(
			"grid_position",
			Vector2i.ZERO
		)
		result.append(
			CampaignItemState.new(
				preferred_instance_id,
				definition_id,
				maxi(1, int(entry.get("quantity", 1))),
				clampf(float(entry.get("condition", 1.0)), 0.0, 1.0),
				CampaignItemLocationState.character_slot(
					character_id,
					container_id,
					grid_position
				)
			)
		)
	return result
