class_name CampaignItemValidator
extends RefCounted


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
				CampaignItemLocationState.CONTAINER_ARMOUR, CampaignItemLocationState.CONTAINER_WORN_UTILITY:
					if not definition.can_equip_in_slot(location.container_id):
						errors.append(
							"Item %s cannot occupy equipment slot %s."
							% [item.item_id, location.container_id]
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
	return errors


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
	var end_position: Vector2i = (
		item.location.grid_position + definition.inventory_footprint
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
		for y: int in range(definition.inventory_footprint.y):
			for x: int in range(definition.inventory_footprint.x):
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
