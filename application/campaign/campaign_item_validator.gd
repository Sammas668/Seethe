class_name CampaignItemValidator
extends RefCounted

const RAIDERS_SACK_DEFINITION_ID: StringName = &"item.raiders_sack"
const RAIDERS_BURDEN_FEAT_ID: StringName = &"trait.raiders_burden"
const MARAUDER_TEMPLATE_ID: StringName = &"character_template.reaver.marauder_tier_1"
const MARAUDER_TROOP_TYPE_ID: StringName = &"troop.reaver.marauder"
const MARAUDER_STAGE_ID: StringName = &"prestige.reaver.marauder"
const RAIDERS_SACK_POSITION: Vector2i = Vector2i(5, 0)


static func validate_item(
		item: CampaignItemState,
		campaign: CampaignState,
		catalogue: ContentCatalogue,
		allow_mission_locations: bool = false
) -> Array[String]:
	var errors: Array[String] = []
	if item == null:
		errors.append("Campaign item is missing.")
		return errors

	errors.append_array(item.validate_state())
	if catalogue == null:
		errors.append("Campaign item validation requires a ContentCatalogue.")
		return errors

	var definition: ItemDefinition = catalogue.item_definition(item.definition_id)
	if definition == null:
		errors.append(
			"Campaign item %s references unknown definition %s."
			% [item.item_id, item.definition_id]
		)
		return errors

	if item.quantity > definition.maximum_stack_size:
		errors.append(
			"Campaign item %s exceeds maximum stack size %d."
			% [item.item_id, definition.maximum_stack_size]
		)
	if not definition.stackable and item.quantity != 1:
		errors.append("Non-stackable campaign item %s has quantity %d." % [item.item_id, item.quantity])
	if item.location == null:
		return errors

	var location: CampaignItemLocationState = item.location
	if definition.fixed_inventory_fixture:
		_validate_fixed_fixture(item, definition, campaign, errors)
	match location.location_type:
		CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT:
			_validate_character_owner(item, campaign, errors)
			match location.container_id:
				CampaignItemLocationState.CONTAINER_PRIMARY_HAND, CampaignItemLocationState.CONTAINER_SECONDARY_HAND:
					if not definition.can_equip_in_hand():
						errors.append(
							"Item %s cannot be equipped in a hand."
							% item.item_id
						)
					if (
						definition.is_two_handed()
						and location.container_id
						== CampaignItemLocationState.CONTAINER_SECONDARY_HAND
					):
						errors.append(
							"Two-handed item %s cannot occupy Secondary Hand."
							% item.item_id
						)
				CampaignItemLocationState.CONTAINER_ARMOUR:
					if not definition.can_equip_in_slot(location.container_id):
						errors.append(
							"Item %s cannot occupy equipment slot %s."
							% [item.item_id, location.container_id]
						)
				CampaignItemLocationState.CONTAINER_WORN_UTILITY:
					errors.append(
						"Item %s remains in the removed Worn Utility slot."
						% item.item_id
					)
		CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY:
			_validate_character_owner(item, campaign, errors)
			if (
				location.container_id == CampaignItemLocationState.CONTAINER_BELT
				and not definition.belt_allowed
			):
				errors.append("Item %s is not allowed on the Belt." % item.item_id)
			if (
				location.container_id
				== CampaignItemLocationState.CONTAINER_BACKPACK
				and not definition.backpack_allowed
			):
				errors.append("Item %s is not allowed in the Backpack." % item.item_id)
			_validate_inventory_bounds(item, definition, errors)
		CampaignItemLocationState.LOCATION_STRONGHOLD_STORAGE:
			# The location object validates the storage owner and container.
			# Definition-level storage capacity is a future Stronghold concern.
			pass
		CampaignItemLocationState.LOCATION_MISSION_GROUND:
			if not allow_mission_locations:
				errors.append(
					"Persistent campaign item %s cannot remain on mission ground."
					% item.item_id
				)

	return errors


static func validate_campaign(
		campaign: CampaignState,
		catalogue: ContentCatalogue
) -> Array[String]:
	var errors: Array[String] = []
	if campaign == null:
		errors.append("Campaign state is missing.")
		return errors
	if catalogue == null:
		errors.append("Campaign validation requires a ContentCatalogue.")
		return errors

	for item: CampaignItemState in campaign.get_items():
		errors.append_array(validate_item(item, campaign, catalogue, false))
	errors.append_array(_validate_inventory_overlaps(campaign, catalogue))
	errors.append_array(_validate_hand_conflicts(campaign, catalogue))
	errors.append_array(_validate_raiders_sack_ownership(campaign))
	return errors


static func _validate_fixed_fixture(
		item: CampaignItemState,
		definition: ItemDefinition,
		campaign: CampaignState,
		errors: Array[String]
) -> void:
	if item.location == null:
		return
	if item.location.location_type != CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY:
		errors.append("Fixed fixture %s must remain in a character inventory." % item.item_id)
		return
	if definition.id != RAIDERS_SACK_DEFINITION_ID:
		return
	if item.location.container_id != CampaignItemLocationState.CONTAINER_BELT:
		errors.append("Raider's Sack %s must remain on its owner's Belt." % item.item_id)
	if item.location.grid_position != RAIDERS_SACK_POSITION or item.location.is_rotated:
		errors.append("Raider's Sack %s must occupy the fixed Belt cells at (5, 0)." % item.item_id)
	var owner: PersistentCharacterState = campaign.get_character(item.location.owner_id) if campaign != null else null
	if owner == null or not _character_should_have_raiders_sack(owner):
		errors.append("Raider's Sack %s is owned by a character without active Raider's Burden." % item.item_id)


static func _validate_raiders_sack_ownership(campaign: CampaignState) -> Array[String]:
	var errors: Array[String] = []
	var sack_count_by_owner: Dictionary = {}
	for item: CampaignItemState in campaign.get_items():
		if item == null or item.definition_id != RAIDERS_SACK_DEFINITION_ID:
			continue
		var owner_id: StringName = &""
		if item.location != null and item.location.belongs_to_character(item.location.owner_id):
			owner_id = item.location.owner_id
		if owner_id.is_empty():
			errors.append("Raider's Sack %s is orphaned outside a Marauder Belt." % item.item_id)
			continue
		sack_count_by_owner[owner_id] = int(sack_count_by_owner.get(owner_id, 0)) + 1
	for character: PersistentCharacterState in campaign.get_characters():
		if character == null:
			continue
		var count: int = int(sack_count_by_owner.get(character.character_id, 0))
		if _character_should_have_raiders_sack(character) and not character.is_dead and count != 1:
			errors.append("Marauder %s must own exactly one fixed Raider's Sack; found %d." % [character.character_id, count])
		elif _character_should_have_raiders_sack(character) and character.is_dead and count > 1:
			errors.append("Dead Marauder %s retains duplicate Raider's Sacks." % character.character_id)
		elif not _character_should_have_raiders_sack(character) and count > 0:
			errors.append("Character %s retains Raider's Sack after Raider's Burden was replaced." % character.character_id)
	return errors


static func _character_should_have_raiders_sack(character: PersistentCharacterState) -> bool:
	if character == null:
		return false
	if character.active_tier_starting_feat_ids.has(RAIDERS_BURDEN_FEAT_ID):
		return true
	if not character.active_tier_starting_feat_ids.is_empty() or character.troop_tier > 1:
		return false
	for stage_id: StringName in character.completed_prestige_stage_ids:
		if stage_id != MARAUDER_STAGE_ID:
			return false
	return (
		character.template_id == MARAUDER_TEMPLATE_ID
		and character.current_troop_type_id in [&"", MARAUDER_TROOP_TYPE_ID]
	)


static func _validate_character_owner(
		item: CampaignItemState,
		campaign: CampaignState,
		errors: Array[String]
) -> void:
	if campaign == null or item.location == null:
		return
	if campaign.get_character(item.location.owner_id) == null:
		errors.append(
			"Campaign item %s references missing character %s."
			% [item.item_id, item.location.owner_id]
		)


static func _validate_inventory_bounds(
		item: CampaignItemState,
		definition: ItemDefinition,
		errors: Array[String]
) -> void:
	var width: int = TacticalInventoryState.BACKPACK_WIDTH
	var height: int = TacticalInventoryState.BACKPACK_HEIGHT
	if item.location.container_id == CampaignItemLocationState.CONTAINER_BELT:
		width = TacticalInventoryState.BELT_WIDTH
		height = TacticalInventoryState.BELT_HEIGHT
	var footprint: Vector2i = definition.inventory_footprint
	if item.location.is_rotated:
		footprint = Vector2i(footprint.y, footprint.x)
	var end_position: Vector2i = (
		item.location.grid_position + footprint
	)
	if end_position.x > width or end_position.y > height:
		errors.append("Campaign item %s exceeds its inventory grid." % item.item_id)


static func _validate_inventory_overlaps(
		campaign: CampaignState,
		catalogue: ContentCatalogue
) -> Array[String]:
	var errors: Array[String] = []
	var occupied: Dictionary = {}
	for item: CampaignItemState in campaign.get_items():
		if item.location == null:
			continue
		if (
			item.location.location_type
			!= CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY
		):
			continue
		var definition: ItemDefinition = catalogue.item_definition(item.definition_id)
		if definition == null:
			continue
		var footprint: Vector2i = definition.inventory_footprint
		if item.location.is_rotated:
			footprint = Vector2i(footprint.y, footprint.x)
		for y: int in range(footprint.y):
			for x: int in range(footprint.x):
				var cell: Vector2i = (
					item.location.grid_position + Vector2i(x, y)
				)
				var key: String = "%s|%s|%d|%d" % [
					item.location.owner_id,
					item.location.container_id,
					cell.x,
					cell.y,
				]
				if occupied.has(key):
					errors.append(
						"Campaign items %s and %s overlap in inventory."
						% [occupied[key], item.item_id]
					)
				else:
					occupied[key] = item.item_id
	return errors


static func _validate_hand_conflicts(
		campaign: CampaignState,
		catalogue: ContentCatalogue
) -> Array[String]:
	var errors: Array[String] = []
	var hands_by_character: Dictionary = {}
	for item: CampaignItemState in campaign.get_items():
		if item.location == null:
			continue
		if (
			item.location.location_type
			!= CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT
		):
			continue

		var owner_hands: Dictionary = hands_by_character.get(
			item.location.owner_id,
			{}
		) as Dictionary
		if owner_hands.has(item.location.container_id):
			errors.append(
				"Campaign items %s and %s occupy the same hand."
				% [owner_hands[item.location.container_id], item.item_id]
			)
		else:
			owner_hands[item.location.container_id] = item.item_id
		hands_by_character[item.location.owner_id] = owner_hands

	for raw_owner_id: Variant in hands_by_character.keys():
		var owner_id: StringName = StringName(raw_owner_id)
		var owner_hands: Dictionary = hands_by_character.get(owner_id, {}) as Dictionary
		var primary_id: StringName = StringName(
			owner_hands.get(CampaignItemLocationState.CONTAINER_PRIMARY_HAND, &"")
		)
		var secondary_id: StringName = StringName(
			owner_hands.get(CampaignItemLocationState.CONTAINER_SECONDARY_HAND, &"")
		)
		if primary_id.is_empty() or secondary_id.is_empty():
			continue
		var primary_item: CampaignItemState = campaign.get_item(primary_id)
		var primary_definition: ItemDefinition = (
			catalogue.item_definition(primary_item.definition_id)
			if primary_item != null
			else null
		)
		if primary_definition != null and primary_definition.is_two_handed():
			errors.append(
				"Two-handed item %s conflicts with Secondary Hand item %s."
				% [primary_id, secondary_id]
			)
	return errors
