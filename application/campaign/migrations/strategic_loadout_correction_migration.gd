class_name StrategicLoadoutCorrectionMigration
extends RefCounted


static func repair_campaign(
		campaign: CampaignState,
		catalogue: ContentCatalogue
) -> bool:
	if campaign == null:
		return false
	var changed: bool = false
	var inventory := InventoryService.new()
	var equipment: StrategicEquipmentService
	if catalogue != null:
		equipment = StrategicEquipmentService.new()
		equipment.configure(catalogue, inventory)

	for item: CampaignItemState in campaign.get_items():
		if item == null:
			continue
		var definition: ItemDefinition = (
			catalogue.item_definition(item.definition_id)
			if catalogue != null
			else null
		)
		if _is_armour(definition) and not is_equal_approx(item.condition, 1.0):
			item.condition = 1.0
			item.revision += 1
			changed = true
		if (
			item.location == null
			or item.location.container_id
			!= CampaignItemLocationState.CONTAINER_WORN_UTILITY
		):
			continue
		var character_id: StringName = item.location.owner_id
		var moved: bool = false
		if equipment != null and definition != null and definition.belt_allowed:
			var belt_result: OperationResult = equipment.equip_candidate(
				campaign,
				item.item_id,
				character_id,
				CampaignItemLocationState.CONTAINER_BELT
			)
			moved = belt_result.success
		if not moved and equipment != null and definition != null and definition.backpack_allowed:
			var backpack_result: OperationResult = equipment.equip_candidate(
				campaign,
				item.item_id,
				character_id,
				CampaignItemLocationState.CONTAINER_BACKPACK
			)
			moved = backpack_result.success
		if not moved:
			moved = inventory.move_item_to_stronghold_candidate(
				campaign,
				item.item_id,
				CampaignItemLocationState.DEFAULT_STRONGHOLD_STORAGE_ID,
				InventoryService.INTAKE_ALLOW_OVERFLOW
			).success
		changed = moved or changed

	for template: LoadoutTemplateState in campaign.get_loadout_templates():
		if template == null:
			continue
		var template_changed: bool = false
		for rule: LoadoutItemRule in template.rules:
			if (
				rule == null
				or rule.preferred_container_id
				!= CampaignItemLocationState.CONTAINER_WORN_UTILITY
			):
				continue
			rule.preferred_container_id = CampaignItemLocationState.CONTAINER_BACKPACK
			rule.preferred_grid_position = Vector2i(-1, -1)
			rule.preferred_is_rotated = false
			rule.fixed_position = false
			template_changed = true
		if template_changed:
			template.template_version = maxi(template.template_version, 2)
			changed = true

	if changed:
		campaign.revision += 1
	return changed


static func _is_armour(definition: ItemDefinition) -> bool:
	return (
		definition != null
		and (
			definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
			or not definition.defence_profile_id.is_empty()
		)
	)
