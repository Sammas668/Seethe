class_name SquadVisibilityService
extends RefCounted


func build_snapshot(
	campaign: CampaignState,
	character_ids: Array[StringName],
	catalogue: ContentCatalogue,
	created_tick: int,
	snapshot_id: StringName = &"visibility.preview"
) -> SquadVisibilitySnapshot:
	var result := SquadVisibilitySnapshot.new()
	result.snapshot_id = snapshot_id
	result.created_tick = maxi(0, created_tick)
	if campaign == null or catalogue == null:
		return result
	for character_id: StringName in character_ids:
		var character: PersistentCharacterState = campaign.get_character(character_id)
		if character == null or character.is_dead:
			continue
		var character_snapshot: CharacterVisibilitySnapshot = _character_snapshot(
			campaign,
			character,
			catalogue
		)
		result.character_snapshots.append(character_snapshot)
		result.total_visibility += character_snapshot.final_visibility
	_apply_band(result)
	return result


func character_snapshot(
	campaign: CampaignState,
	character_id: StringName,
	catalogue: ContentCatalogue
) -> CharacterVisibilitySnapshot:
	if campaign == null or catalogue == null:
		return null
	var character: PersistentCharacterState = campaign.get_character(character_id)
	return _character_snapshot(campaign, character, catalogue) if character != null else null


func _character_snapshot(
	campaign: CampaignState,
	character: PersistentCharacterState,
	catalogue: ContentCatalogue
) -> CharacterVisibilitySnapshot:
	var result := CharacterVisibilitySnapshot.new()
	result.character_id = character.character_id
	result.display_name = character.display_name
	result.base_visibility = 1
	var template: CharacterTemplateDefinition = catalogue.character_template(character.template_id)
	if template != null and (template.footprint.x > 1 or template.footprint.y > 1):
		_add_modifier(result, "Large creature", 2)
	var backpack_weight: float = 0.0
	var has_armour: bool = false
	var has_shield: bool = false
	var has_conspicuous_weapon: bool = false
	var has_bulky_item: bool = false
	for item: CampaignItemState in campaign.items_for_character(character.character_id):
		result.equipment_revision += item.revision
		var definition: ItemDefinition = catalogue.item_definition(item.definition_id)
		if definition == null:
			continue
		var quantity_weight: float = definition.weight_lb * float(maxi(1, item.quantity))
		if item.location != null and item.location.container_id == CampaignItemLocationState.CONTAINER_BACKPACK:
			backpack_weight += quantity_weight
		if definition.has_tag(&"armour"):
			has_armour = true
		if definition.has_tag(&"shield"):
			has_shield = true
		if definition.has_tag(&"bulky") or quantity_weight >= 15.0:
			has_bulky_item = true
		if (
			definition.is_two_handed()
			or definition.has_tag(&"spear")
			or definition.has_tag(&"bow")
		):
			has_conspicuous_weapon = true
	if has_armour:
		_add_modifier(result, "Visible armour", 1)
	if has_shield:
		_add_modifier(result, "Shield", 1)
	if has_conspicuous_weapon:
		_add_modifier(result, "Conspicuous weapon", 1)
	if has_bulky_item:
		_add_modifier(result, "Bulky equipment", 1)
	if backpack_weight >= 12.0:
		_add_modifier(result, "Loaded backpack", 1)
	result.final_visibility = result.base_visibility
	for line: Dictionary in result.modifier_lines:
		result.final_visibility += int(line.get("value", 0))
	result.final_visibility = maxi(0, result.final_visibility)
	return result


func _add_modifier(snapshot: CharacterVisibilitySnapshot, label: String, value: int) -> void:
	if snapshot == null or value == 0:
		return
	snapshot.modifier_lines.append({"label": label, "value": value})


func _apply_band(snapshot: SquadVisibilitySnapshot) -> void:
	if snapshot.total_visibility <= 4:
		snapshot.category = SquadVisibilitySnapshot.CATEGORY_LOW
		snapshot.travel_multiplier = 0.75
	elif snapshot.total_visibility <= 8:
		snapshot.category = SquadVisibilitySnapshot.CATEGORY_STANDARD
		snapshot.travel_multiplier = 1.0
	elif snapshot.total_visibility <= 13:
		snapshot.category = SquadVisibilitySnapshot.CATEGORY_HIGH
		snapshot.travel_multiplier = 1.25
	else:
		snapshot.category = SquadVisibilitySnapshot.CATEGORY_SEVERE
		snapshot.travel_multiplier = 1.5
