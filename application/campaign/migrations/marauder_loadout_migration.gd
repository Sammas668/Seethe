class_name MarauderLoadoutMigration
extends RefCounted

const MARAUDER_TEMPLATE_ID: StringName = &"character_template.reaver.marauder_tier_1"
const MARAUDER_ONE_ID: StringName = &"character.reaver.marauder.0001"
const MARAUDER_TWO_ID: StringName = &"character.reaver.marauder.0002"

const OBSOLETE_DEFINITION_IDS: Array[StringName] = [
	&"item.rations",
	&"item.empty_sack",
	&"item.reinforced_captive_carrying_belt",
]


static func repair_existing_marauders(campaign: CampaignState) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	for character: PersistentCharacterState in campaign.get_characters():
		if character == null or character.template_id != MARAUDER_TEMPLATE_ID:
			continue
		changed = repair_character(
			campaign,
			character,
			_instance_prefix_for(character.character_id)
		) or changed
	return changed


static func repair_character(
		campaign: CampaignState,
		character: PersistentCharacterState,
		instance_prefix: StringName
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

	return changed


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
