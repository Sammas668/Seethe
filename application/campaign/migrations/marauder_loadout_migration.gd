class_name MarauderLoadoutMigration
extends RefCounted

const MARAUDER_TEMPLATE_ID: StringName = &"character_template.reaver.marauder_tier_1"
const MARAUDER_ONE_ID: StringName = &"character.reaver.marauder.0001"
const MARAUDER_TWO_ID: StringName = &"character.reaver.marauder.0002"
const MARAUDER_TROOP_TYPE_ID: StringName = &"troop.reaver.marauder"
const MARAUDER_STAGE_ID: StringName = &"prestige.reaver.marauder"
const RAIDERS_BURDEN_FEAT_ID: StringName = &"trait.raiders_burden"
const RAIDERS_SACK_DEFINITION_ID: StringName = &"item.raiders_sack"
const RAIDERS_SACK_POSITION: Vector2i = Vector2i(5, 0)
const RAIDERS_SACK_SIZE: Vector2i = Vector2i(2, 2)

const OBSOLETE_DEFINITION_IDS: Array[StringName] = [
	&"item.rations",
	&"item.empty_sack",
	&"item.reinforced_captive_carrying_belt",
]


static func repair_existing_marauders(
		campaign: CampaignState,
		catalogue: ContentCatalogue = null
) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	for character: PersistentCharacterState in campaign.get_characters():
		if character == null:
			continue
		# Save loading must never rebuild a player's ordinary loadout. Legacy
		# pre-sack fixtures belonged only to the old Marauder package, so do not
		# delete similarly named supplies from unrelated characters.
		if character.template_id == MARAUDER_TEMPLATE_ID or should_have_raiders_sack(character):
			for owned_item: CampaignItemState in campaign.items_for_character(character.character_id):
				if owned_item != null and owned_item.definition_id in OBSOLETE_DEFINITION_IDS:
					changed = campaign.remove_item(owned_item.item_id) or changed
		changed = repair_raiders_sack_fixture(campaign, character, catalogue) or changed

	# A fixed Tier fixture may never become a free Storage/shop item. Remove any
	# orphaned copy left by an older save or an obsolete equipment transaction.
	for item: CampaignItemState in campaign.get_items():
		if item == null or item.definition_id != RAIDERS_SACK_DEFINITION_ID:
			continue
		var owner: PersistentCharacterState = null
		if item.location != null and item.location.belongs_to_character(item.location.owner_id):
			owner = campaign.get_character(item.location.owner_id)
		if owner == null or not should_have_raiders_sack(owner):
			changed = campaign.remove_item(item.item_id) or changed
	return changed


static func repair_character(
		campaign: CampaignState,
		character: PersistentCharacterState,
		instance_prefix: StringName,
		catalogue: ContentCatalogue = null
) -> bool:
	if campaign == null or character == null:
		return false
	var changed: bool = false

	for owned_item: CampaignItemState in campaign.items_for_character(
		character.character_id
	):
		if owned_item == null:
			continue
		if owned_item.definition_id in OBSOLETE_DEFINITION_IDS:
			changed = campaign.remove_item(owned_item.item_id) or changed

	for entry: Dictionary in _approved_entries():
		var definition_id := StringName(entry["definition_id"])
		var container_id := StringName(entry["container"])
		var grid_position: Vector2i = entry.get("position", Vector2i.ZERO)
		var quantity: int = int(entry["quantity"])
		var preferred_id := StringName(
			"%s.%s" % [instance_prefix, String(entry["suffix"])]
		)
		var item: CampaignItemState = campaign.get_item(preferred_id) as CampaignItemState
		if item == null:
			for candidate: CampaignItemState in campaign.items_for_character(
				character.character_id
			):
				if candidate != null and candidate.definition_id == definition_id:
					item = candidate
					break
		if item == null:
			item = CampaignItemState.new(
				campaign.unique_item_id(preferred_id),
				definition_id,
				quantity,
				1.0,
				CampaignItemLocationState.character_slot(
					character.character_id, container_id, grid_position
				)
			)
			if campaign.add_item(item):
				changed = true
			else:
				continue

		var item_changed: bool = false
		if item.definition_id != definition_id:
			item.definition_id = definition_id
			item.revision += 1
			item_changed = true
		if item.quantity != quantity:
			item.quantity = quantity
			item.revision += 1
			item_changed = true
		if not _location_matches(
			item.location, character.character_id, container_id, grid_position
		):
			item.set_location(
				CampaignItemLocationState.character_slot(
					character.character_id, container_id, grid_position
				)
			)
			item_changed = true
		if item_changed:
			campaign.upsert_item(item)
			changed = true

	changed = repair_raiders_sack_fixture(campaign, character, catalogue) or changed
	return changed


static func should_have_raiders_sack(character: PersistentCharacterState) -> bool:
	if character == null:
		return false
	if character.active_tier_starting_feat_ids.has(RAIDERS_BURDEN_FEAT_ID):
		return true
	# Compatibility for pre-career saves. Once any explicit Tier package exists,
	# the active package is authoritative and no legacy inference is permitted.
	if not character.active_tier_starting_feat_ids.is_empty():
		return false
	if character.troop_tier > 1:
		return false
	for stage_id: StringName in character.completed_prestige_stage_ids:
		if stage_id != MARAUDER_STAGE_ID:
			return false
	return (
		character.template_id == MARAUDER_TEMPLATE_ID
		and character.current_troop_type_id in [&"", MARAUDER_TROOP_TYPE_ID]
	)


static func repair_raiders_sack_fixture(
		campaign: CampaignState,
		character: PersistentCharacterState,
		catalogue: ContentCatalogue = null
) -> bool:
	if campaign == null or character == null:
		return false
	var changed: bool = false
	var owned_sacks: Array[CampaignItemState] = []
	for item: CampaignItemState in campaign.items_for_character(character.character_id):
		if item != null and item.definition_id == RAIDERS_SACK_DEFINITION_ID:
			owned_sacks.append(item)

	if not should_have_raiders_sack(character):
		for obsolete_sack: CampaignItemState in owned_sacks:
			changed = campaign.remove_item(obsolete_sack.item_id) or changed
		return changed
	# A dead Marauder may retain the fixed sack if it remains on the recovered
	# body, but a sack lost with the body must not be recreated by save migration.
	if character.is_dead and owned_sacks.is_empty():
		return changed

	var sack: CampaignItemState = null
	for candidate: CampaignItemState in owned_sacks:
		if _location_matches(
			candidate.location,
			character.character_id,
			CampaignItemLocationState.CONTAINER_BELT,
			RAIDERS_SACK_POSITION
		):
			sack = candidate
			break
	if sack == null and not owned_sacks.is_empty():
		sack = owned_sacks[0]

	if sack == null:
		var preferred_id := StringName(
			"%s.raiders_sack" % String(_instance_prefix_for(character.character_id))
		)
		sack = CampaignItemState.new(
			campaign.unique_item_id(preferred_id),
			RAIDERS_SACK_DEFINITION_ID,
			1,
			1.0,
			CampaignItemLocationState.character_slot(
				character.character_id,
				CampaignItemLocationState.CONTAINER_BELT,
				RAIDERS_SACK_POSITION
			),
			{&"fixture_source_feat_id": String(RAIDERS_BURDEN_FEAT_ID)}
		)
		if campaign.add_item(sack):
			changed = true
		else:
			return changed

	changed = _return_overlapping_belt_items_to_storage(
		campaign,
		character.character_id,
		sack.item_id,
		catalogue
	) or changed

	var sack_changed: bool = false
	if sack.quantity != 1:
		sack.quantity = 1
		sack_changed = true
	if not is_equal_approx(sack.condition, 1.0):
		sack.condition = 1.0
		sack_changed = true
	if not _location_matches(
		sack.location,
		character.character_id,
		CampaignItemLocationState.CONTAINER_BELT,
		RAIDERS_SACK_POSITION
	) or sack.location.is_rotated:
		sack.set_location(CampaignItemLocationState.character_slot(
			character.character_id,
			CampaignItemLocationState.CONTAINER_BELT,
			RAIDERS_SACK_POSITION,
			false
		))
		sack_changed = true
	if StringName(sack.persistent_modifiers.get(&"fixture_source_feat_id", &"")) != RAIDERS_BURDEN_FEAT_ID:
		sack.persistent_modifiers[&"fixture_source_feat_id"] = String(RAIDERS_BURDEN_FEAT_ID)
		sack_changed = true
	if sack_changed:
		sack.revision += 1
		campaign.upsert_item(sack)
		changed = true

	for duplicate: CampaignItemState in owned_sacks:
		if duplicate != null and duplicate.item_id != sack.item_id:
			changed = campaign.remove_item(duplicate.item_id) or changed
	return changed


static func _return_overlapping_belt_items_to_storage(
		campaign: CampaignState,
		character_id: StringName,
		sack_item_id: StringName,
		catalogue: ContentCatalogue
) -> bool:
	var changed: bool = false
	for item: CampaignItemState in campaign.items_for_character(character_id):
		if item == null or item.item_id == sack_item_id or item.location == null:
			continue
		if item.location.container_id != CampaignItemLocationState.CONTAINER_BELT:
			continue
		var footprint := Vector2i.ONE
		if catalogue != null:
			var definition: ItemDefinition = catalogue.item_definition(item.definition_id)
			if definition != null:
				footprint = definition.inventory_footprint
				if item.location.is_rotated:
					footprint = Vector2i(footprint.y, footprint.x)
		if not _rectangles_overlap(
			item.location.grid_position,
			footprint,
			RAIDERS_SACK_POSITION,
			RAIDERS_SACK_SIZE
		):
			continue
		item.set_location(CampaignItemLocationState.stronghold_storage())
		campaign.upsert_item(item)
		changed = true
	return changed


static func _rectangles_overlap(
		a_position: Vector2i,
		a_size: Vector2i,
		b_position: Vector2i,
		b_size: Vector2i
) -> bool:
	return (
		a_position.x < b_position.x + b_size.x
		and a_position.x + a_size.x > b_position.x
		and a_position.y < b_position.y + b_size.y
		and a_position.y + a_size.y > b_position.y
	)


static func _location_matches(
		location: CampaignItemLocationState,
		character_id: StringName,
		container_id: StringName,
		grid_position: Vector2i
) -> bool:
	if location == null:
		return false
	return (
		location.belongs_to_character(character_id)
		and location.container_id == container_id
		and location.grid_position == grid_position
	)


static func _instance_prefix_for(character_id: StringName) -> StringName:
	match character_id:
		MARAUDER_ONE_ID:
			return &"instance.marauder"
		MARAUDER_TWO_ID:
			return &"instance.marauder_two"
		_:
			return StringName(
				"instance.%s" % String(character_id).replace(".", "_")
			)


static func _approved_entries() -> Array[Dictionary]:
	return [
		{"definition_id": &"item.raiders_axe", "suffix": "axe", "container": CampaignItemLocationState.CONTAINER_PRIMARY_HAND, "position": Vector2i.ZERO, "quantity": 1},
		{"definition_id": &"item.patchwork_raider_armour", "suffix": "armour", "container": CampaignItemLocationState.CONTAINER_ARMOUR, "position": Vector2i.ZERO, "quantity": 1},
		{"definition_id": &"item.mace", "suffix": "mace", "container": CampaignItemLocationState.CONTAINER_BELT, "position": Vector2i(0, 0), "quantity": 1},
		{"definition_id": &"item.reaver_dagger", "suffix": "dagger", "container": CampaignItemLocationState.CONTAINER_BELT, "position": Vector2i(2, 0), "quantity": 1},
		{"definition_id": &"item.manacles", "suffix": "manacles", "container": CampaignItemLocationState.CONTAINER_BELT, "position": Vector2i(3, 0), "quantity": 2},
		{"definition_id": &"item.marauder_keys", "suffix": "keys", "container": CampaignItemLocationState.CONTAINER_BELT, "position": Vector2i(3, 1), "quantity": 1},
		{"definition_id": &"item.bandage", "suffix": "bandage", "container": CampaignItemLocationState.CONTAINER_BELT, "position": Vector2i(4, 1), "quantity": 1},
		{"definition_id": &"item.raiders_sack", "suffix": "raiders_sack", "container": CampaignItemLocationState.CONTAINER_BELT, "position": Vector2i(5, 0), "quantity": 1},
		{"definition_id": &"item.rope", "suffix": "rope", "container": CampaignItemLocationState.CONTAINER_BACKPACK, "position": Vector2i(0, 0), "quantity": 1},
	]
