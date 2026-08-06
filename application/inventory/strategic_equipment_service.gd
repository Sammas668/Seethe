class_name StrategicEquipmentService
extends RefCounted

const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)

var _catalogue: ContentCatalogue
var _inventory_service: InventoryService
var _reservation_service: StrategicReservationServiceScript


func configure(
		catalogue: ContentCatalogue,
		inventory_service: InventoryService,
		reservation_service: StrategicReservationServiceScript = null
) -> void:
	_catalogue = catalogue
	_inventory_service = inventory_service
	_reservation_service = reservation_service


func preview_equip(
		campaign: CampaignState,
		item_id: StringName,
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	return preview_equip_at_position(
		campaign,
		item_id,
		character_id,
		container_id,
		Vector2i(-1, -1),
		false
	)


func preview_equip_at_position(
		campaign: CampaignState,
		item_id: StringName,
		character_id: StringName,
		container_id: StringName,
		grid_position: Vector2i,
		is_rotated: bool = false
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var candidate: CampaignState = CampaignState.from_dictionary(campaign.to_dictionary())
	var result: OperationResult = equip_candidate_at_position(
		candidate,
		item_id,
		character_id,
		container_id,
		grid_position,
		is_rotated
	)
	if not result.success:
		return result
	var errors: Array[String] = CampaignItemValidator.validate_campaign(candidate, _catalogue)
	if not errors.is_empty():
		return OperationResult.fail(
			&"equipment_plan_invalid",
			"The resulting loadout is invalid: %s" % errors[0]
		)
	return result


func equip_candidate(
		campaign: CampaignState,
		item_id: StringName,
		character_id: StringName,
		requested_container_id: StringName
) -> OperationResult:
	return equip_candidate_at_position(
		campaign,
		item_id,
		character_id,
		requested_container_id,
		Vector2i(-1, -1),
		false
	)


func equip_candidate_at_position(
		campaign: CampaignState,
		item_id: StringName,
		character_id: StringName,
		requested_container_id: StringName,
		requested_grid_position: Vector2i,
		requested_rotation: bool = false
) -> OperationResult:
	if campaign == null or _catalogue == null or _inventory_service == null:
		return OperationResult.fail(
			&"equipment_service_unconfigured",
			"Strategic equipment service is not configured."
		)
	var character: PersistentCharacterState = campaign.get_character(character_id)
	if character == null:
		return OperationResult.fail(&"character_missing", "The selected character no longer exists.")
	if character.is_dead:
		return OperationResult.fail(&"character_dead", "Dead characters cannot receive equipment.")
	if _reservation_service != null:
		var character_availability: OperationResult = _reservation_service.validate_character_available(
			campaign,
			character_id
		)
		if not character_availability.success:
			return character_availability
		var item_availability: OperationResult = _reservation_service.validate_item_available(
			campaign,
			item_id
		)
		if not item_availability.success:
			return item_availability
	var item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	if item == null:
		return OperationResult.fail(&"item_missing", "The selected item no longer exists.")
	if item.location == null:
		return OperationResult.fail(&"item_location_missing", "The selected item has no valid location.")
	if not (
		item.location.is_stronghold_storage()
		or item.location.belongs_to_character(character_id)
	):
		return OperationResult.fail(
			&"item_unavailable",
			"The selected item is not in stronghold storage or carried by this character."
		)
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
	if definition == null:
		return OperationResult.fail(&"item_definition_missing", "The selected item definition is missing.")
	if item.condition <= 0.0:
		return OperationResult.fail(&"item_destroyed", "Destroyed items must be repaired before they can be equipped.")
	if definition.fixed_inventory_fixture:
		var requested_position: Vector2i = requested_grid_position
		if requested_position.x < 0 and item.location != null:
			requested_position = item.location.grid_position
		if (
			item.location != null
			and item.location.belongs_to_character(character_id)
			and requested_container_id == CampaignItemLocationState.CONTAINER_BELT
			and item.location.container_id == CampaignItemLocationState.CONTAINER_BELT
			and item.location.grid_position == requested_position
			and item.location.is_rotated == requested_rotation
		):
			return OperationResult.no_change(
				item,
				"Raider's Sack is already fixed in its permanent Belt position."
			)
		return OperationResult.fail(
			&"fixed_inventory_fixture",
			"Raider's Sack is granted by Raider's Burden and cannot be moved, transferred or repositioned."
		)
	if _is_armour_definition(definition) and not is_equal_approx(item.condition, 1.0):
		item.condition = 1.0
		item.revision += 1
	var template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id)
	if template == null:
		return OperationResult.fail(&"character_template_missing", "The selected character template is missing.")
	if (
		not definition.required_proficiency_id.is_empty()
		and not template.proficiency_ids.has(definition.required_proficiency_id)
	):
		return OperationResult.fail(
			&"proficiency_missing",
			"%s lacks the required proficiency." % character.display_name
		)

	var container_id: StringName = requested_container_id
	var legal_result: OperationResult = _validate_container(definition, container_id)
	if not legal_result.success:
		return legal_result
	if definition.is_two_handed():
		container_id = CampaignItemLocationState.CONTAINER_PRIMARY_HAND

	var displaced_ids: Array[StringName] = []
	var final_position := Vector2i.ZERO
	var final_rotation: bool = false
	if container_id in [
		CampaignItemLocationState.CONTAINER_PRIMARY_HAND,
		CampaignItemLocationState.CONTAINER_SECONDARY_HAND,
		CampaignItemLocationState.CONTAINER_ARMOUR,
	]:
		var displacement: OperationResult = _displace_fixed_slot_conflicts(
			campaign,
			character_id,
			item_id,
			container_id,
			definition.is_two_handed()
		)
		if not displacement.success:
			return displacement
		if displacement.data is Array:
			for raw_displaced_id: Variant in displacement.data as Array:
				displaced_ids.append(StringName(raw_displaced_id))
		var assignment: OperationResult = _inventory_service.move_item_to_character_candidate(
			campaign,
			item_id,
			character_id,
			container_id
		)
		if not assignment.success:
			return assignment
	else:
		if requested_rotation and not definition.inventory_rotation_allowed:
			return OperationResult.fail(
				&"item_rotation_forbidden",
				"This item cannot be rotated in a spatial inventory."
			)
		final_rotation = requested_rotation
		var footprint: Vector2i = _effective_footprint(definition, final_rotation)
		final_position = requested_grid_position
		if final_position.x < 0:
			final_position = _first_inventory_position(
				campaign,
				character_id,
				container_id,
				item_id,
				footprint
			)
		elif not _can_fit_inventory_position(
			campaign,
			character_id,
			container_id,
			item_id,
			final_position,
			footprint
		):
			return OperationResult.fail(
				&"inventory_position_blocked",
				"The item does not fit at that position in the selected container."
			)
		if final_position.x < 0:
			return OperationResult.fail(
				&"inventory_space_missing",
				"There is not enough room in the selected container."
			)
		var assignment: OperationResult = _inventory_service.move_item_to_character_candidate(
			campaign,
			item_id,
			character_id,
			container_id,
			final_position,
			final_rotation
		)
		if not assignment.success:
			return assignment

	var weight: float = _character_weight(campaign, character_id)
	if weight > template.maximum_weight_lb + 0.001:
		return OperationResult.fail(
			&"carrying_capacity_exceeded",
			"This loadout would exceed %s's carrying capacity." % character.display_name
		)
	return OperationResult.ok(
		{
			"item_id": item_id,
			"character_id": character_id,
			"container_id": container_id,
			"grid_position": final_position,
			"is_rotated": final_rotation,
			"displaced_item_ids": displaced_ids,
		},
		"%s equipped to %s." % [definition.display_name, character.display_name]
	)


func preview_auto_pack(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var candidate := CampaignState.from_dictionary(campaign.to_dictionary())
	var result: OperationResult = auto_pack_candidate(candidate, character_id, container_id)
	if not result.success:
		return result
	var errors: Array[String] = CampaignItemValidator.validate_campaign(candidate, _catalogue)
	if not errors.is_empty():
		return OperationResult.fail(&"auto_pack_invalid", errors[0])
	return result


func auto_pack_candidate(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	if _reservation_service != null:
		var availability: OperationResult = _reservation_service.validate_character_available(
			campaign,
			character_id
		)
		if not availability.success:
			return availability
	if container_id not in [CampaignItemLocationState.CONTAINER_BELT, CampaignItemLocationState.CONTAINER_BACKPACK]:
		return OperationResult.fail(&"not_spatial_container", "Only Belt and Backpack can be auto-packed.")
	var items: Array[CampaignItemState] = _items_in_container(campaign, character_id, container_id)
	items.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			var a_def: ItemDefinition = _catalogue.item_definition(a.definition_id)
			var b_def: ItemDefinition = _catalogue.item_definition(b.definition_id)
			var a_area: int = a_def.inventory_footprint.x * a_def.inventory_footprint.y if a_def != null else 1
			var b_area: int = b_def.inventory_footprint.x * b_def.inventory_footprint.y if b_def != null else 1
			if a_area != b_area:
				return a_area > b_area
			return String(a.item_id) < String(b.item_id)
	)
	var placed_ids: Array[StringName] = []
	for item: CampaignItemState in items:
		var fixed_definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
		if fixed_definition != null and fixed_definition.fixed_inventory_fixture:
			placed_ids.append(item.item_id)
	for item: CampaignItemState in items:
		var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
		if definition == null:
			return OperationResult.fail(&"item_definition_missing", "An item definition is missing.")
		if definition.fixed_inventory_fixture:
			continue
		var position: Vector2i = _first_inventory_position_for_subset(
			campaign,
			character_id,
			container_id,
			item.item_id,
			definition.inventory_footprint,
			placed_ids
		)
		var rotated: bool = false
		if position.x < 0 and definition.inventory_rotation_allowed and definition.inventory_footprint.x != definition.inventory_footprint.y:
			position = _first_inventory_position_for_subset(
				campaign,
				character_id,
				container_id,
				item.item_id,
				Vector2i(definition.inventory_footprint.y, definition.inventory_footprint.x),
				placed_ids
			)
			rotated = position.x >= 0
		if position.x < 0:
			return OperationResult.fail(&"auto_pack_space_missing", "The current items cannot fit in this container.")
		var moved: OperationResult = _inventory_service.move_item_to_character_candidate(
			campaign,
			item.item_id,
			character_id,
			container_id,
			position,
			rotated
		)
		if not moved.success:
			return moved
		placed_ids.append(item.item_id)
	return OperationResult.ok({"character_id": character_id, "container_id": container_id}, "%s organised." % String(container_id).replace("_", " ").capitalize())


func loadout_status(campaign: CampaignState, character_id: StringName) -> Dictionary:
	var blocking: Array[String] = []
	var warnings: Array[String] = []
	var character: PersistentCharacterState = campaign.get_character(character_id) if campaign != null else null
	if character == null:
		blocking.append("Character is unavailable.")
		return {"ready": false, "blocking": blocking, "warnings": warnings}
	if _reservation_service != null:
		var availability: Dictionary = _reservation_service.character_availability(
			campaign,
			character_id
		)
		if not bool(availability.get("available", true)):
			blocking.append(String(availability.get("reason", "Character is deployed.")))
			return {
				"ready": false,
				"locked": true,
				"lock_reason": String(availability.get("reason", "Character is deployed.")),
				"blocking": blocking,
				"warnings": warnings,
			}
	if character.is_dead:
		blocking.append("Character is dead.")
	var template: CharacterTemplateDefinition = _catalogue.character_template(character.template_id) if _catalogue != null else null
	if template != null and _character_weight(campaign, character_id) > template.maximum_weight_lb + 0.001:
		blocking.append("Carrying capacity is exceeded.")
	if _items_in_container(campaign, character_id, CampaignItemLocationState.CONTAINER_PRIMARY_HAND).is_empty():
		warnings.append("Primary hand is empty; the character will rely on unarmed attacks.")
	return {"ready": blocking.is_empty(), "blocking": blocking, "warnings": warnings}


func preview_return_container_to_storage(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var candidate := CampaignState.from_dictionary(campaign.to_dictionary())
	return return_container_to_storage_candidate(candidate, character_id, container_id)


func return_container_to_storage_candidate(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName
) -> OperationResult:
	if _reservation_service != null:
		var availability: OperationResult = _reservation_service.validate_character_available(
			campaign,
			character_id
		)
		if not availability.success:
			return availability
	var item_ids: Array[StringName] = []
	for item: CampaignItemState in _items_in_container(campaign, character_id, container_id):
		var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
		if definition != null and definition.fixed_inventory_fixture:
			continue
		item_ids.append(item.item_id)
	if item_ids.is_empty():
		return OperationResult.no_change(null, "The selected container has no movable items.")
	for item_id: StringName in item_ids:
		var returned: OperationResult = return_to_storage_candidate(campaign, item_id)
		if not returned.success:
			return returned
	return OperationResult.ok(item_ids, "All movable items returned to stronghold storage.")


func preview_return_to_storage(
		campaign: CampaignState,
		item_id: StringName
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	var candidate: CampaignState = CampaignState.from_dictionary(campaign.to_dictionary())
	var result: OperationResult = return_to_storage_candidate(candidate, item_id)
	if not result.success:
		return result
	var errors: Array[String] = CampaignItemValidator.validate_campaign(candidate, _catalogue)
	if not errors.is_empty():
		return OperationResult.fail(
			&"equipment_plan_invalid",
			"The resulting inventory is invalid: %s" % errors[0]
		)
	return result


func return_to_storage_candidate(
		campaign: CampaignState,
		item_id: StringName,
		intake_policy: StringName = InventoryService.INTAKE_REQUIRE_CAPACITY
) -> OperationResult:
	if campaign == null or _catalogue == null or _inventory_service == null:
		return OperationResult.fail(
			&"equipment_service_unconfigured",
			"Strategic equipment service is not configured."
		)
	var item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	if item == null:
		return OperationResult.fail(&"item_missing", "The selected item no longer exists.")
	var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
	if definition != null and definition.fixed_inventory_fixture:
		return OperationResult.fail(
			&"fixed_inventory_fixture",
			"Raider's Sack is a permanent Marauder Belt fixture and cannot be returned to Storage."
		)
	if _reservation_service != null:
		var item_availability: OperationResult = _reservation_service.validate_item_available(
			campaign,
			item_id
		)
		if not item_availability.success:
			return item_availability
	if item.location == null or item.location.is_stronghold_storage():
		return OperationResult.no_change(item, "The item is already in stronghold storage.")
	if item.location.location_type not in [
		CampaignItemLocationState.LOCATION_CHARACTER_EQUIPMENT,
		CampaignItemLocationState.LOCATION_CHARACTER_INVENTORY,
	]:
		return OperationResult.fail(
			&"item_unavailable",
			"Only character equipment can be returned from this screen."
		)
	var owner: PersistentCharacterState = campaign.get_character(item.location.owner_id)
	if owner == null:
		return OperationResult.fail(&"character_missing", "The item's owner no longer exists.")
	var moved: OperationResult = _inventory_service.move_item_to_stronghold_candidate(
		campaign,
		item_id,
		CampaignItemLocationState.DEFAULT_STRONGHOLD_STORAGE_ID,
		intake_policy
	)
	if not moved.success:
		return moved
	return OperationResult.ok(
		item,
		"%s returned to stronghold storage."
		% (definition.display_name if definition != null else String(item.definition_id))
	)


func _is_armour_definition(definition: ItemDefinition) -> bool:
	return (
		definition != null
		and (
			definition.can_equip_in_slot(CampaignItemLocationState.CONTAINER_ARMOUR)
			or not definition.defence_profile_id.is_empty()
		)
	)


func _validate_container(
		definition: ItemDefinition,
		container_id: StringName
) -> OperationResult:
	match container_id:
		CampaignItemLocationState.CONTAINER_PRIMARY_HAND, CampaignItemLocationState.CONTAINER_SECONDARY_HAND:
			if not definition.can_equip_in_hand():
				return OperationResult.fail(&"illegal_hand_item", "This item cannot be equipped in a hand.")
		CampaignItemLocationState.CONTAINER_ARMOUR:
			if not definition.can_equip_in_slot(container_id):
				return OperationResult.fail(
					&"illegal_equipment_slot",
					"This item cannot occupy the selected equipment slot."
				)
		CampaignItemLocationState.CONTAINER_WORN_UTILITY:
			return OperationResult.fail(
				&"legacy_equipment_slot",
				"Worn Utility is no longer a strategic equipment slot. Use the Belt or Backpack."
			)
		CampaignItemLocationState.CONTAINER_BELT:
			if not definition.belt_allowed:
				return OperationResult.fail(&"illegal_belt_item", "This item cannot be carried on the Belt.")
		CampaignItemLocationState.CONTAINER_BACKPACK:
			if not definition.backpack_allowed:
				return OperationResult.fail(&"illegal_backpack_item", "This item cannot be carried in the Backpack.")
		_:
			return OperationResult.fail(&"unknown_equipment_slot", "The selected equipment slot is unknown.")
	return OperationResult.ok(definition)


func _displace_fixed_slot_conflicts(
		campaign: CampaignState,
		character_id: StringName,
		incoming_item_id: StringName,
		container_id: StringName,
		incoming_two_handed: bool
) -> OperationResult:
	var displaced: Array[StringName] = []
	var target_containers: Array[StringName] = [container_id]
	if incoming_two_handed:
		target_containers = [
			CampaignItemLocationState.CONTAINER_PRIMARY_HAND,
			CampaignItemLocationState.CONTAINER_SECONDARY_HAND,
		]
	elif container_id == CampaignItemLocationState.CONTAINER_SECONDARY_HAND:
		var primary: CampaignItemState = _first_item_in_container(
			campaign,
			character_id,
			CampaignItemLocationState.CONTAINER_PRIMARY_HAND,
			incoming_item_id
		)
		if primary != null:
			var primary_definition: ItemDefinition = _catalogue.item_definition(primary.definition_id)
			if primary_definition != null and primary_definition.is_two_handed():
				target_containers.append(CampaignItemLocationState.CONTAINER_PRIMARY_HAND)

	for target_container: StringName in target_containers:
		for existing: CampaignItemState in _items_in_container(campaign, character_id, target_container):
			if existing.item_id == incoming_item_id:
				continue
			var moved: OperationResult = _inventory_service.move_item_to_stronghold_candidate(
				campaign,
				existing.item_id
			)
			if not moved.success:
				return moved
			displaced.append(existing.item_id)
	return OperationResult.ok(displaced, "Conflicting equipment returned to storage.")


func _items_in_container(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName
) -> Array[CampaignItemState]:
	var result: Array[CampaignItemState] = []
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if item != null and item.location != null and item.location.container_id == container_id:
			result.append(item)
	result.sort_custom(
		func(a: CampaignItemState, b: CampaignItemState) -> bool:
			return String(a.item_id) < String(b.item_id)
	)
	return result


func _first_item_in_container(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName,
		excluded_item_id: StringName = &""
) -> CampaignItemState:
	for item: CampaignItemState in _items_in_container(campaign, character_id, container_id):
		if item.item_id != excluded_item_id:
			return item
	return null


func _first_inventory_position(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName,
		excluded_item_id: StringName,
		footprint: Vector2i
) -> Vector2i:
	var included_ids: Array[StringName] = []
	for item: CampaignItemState in _items_in_container(campaign, character_id, container_id):
		if item.item_id != excluded_item_id:
			included_ids.append(item.item_id)
	return _first_inventory_position_for_subset(
		campaign,
		character_id,
		container_id,
		excluded_item_id,
		footprint,
		included_ids
	)


func _first_inventory_position_for_subset(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName,
		excluded_item_id: StringName,
		footprint: Vector2i,
		included_item_ids: Array[StringName]
) -> Vector2i:
	var dimensions: Vector2i = _inventory_dimensions(container_id)
	var occupied: Dictionary = {}
	for item: CampaignItemState in _items_in_container(campaign, character_id, container_id):
		if item.item_id == excluded_item_id or not included_item_ids.has(item.item_id):
			continue
		var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
		if definition == null:
			continue
		var existing_footprint: Vector2i = _effective_footprint(
			definition,
			item.location.is_rotated
		)
		for y: int in range(existing_footprint.y):
			for x: int in range(existing_footprint.x):
				occupied[item.location.grid_position + Vector2i(x, y)] = true
	for y: int in range(dimensions.y - footprint.y + 1):
		for x: int in range(dimensions.x - footprint.x + 1):
			var origin := Vector2i(x, y)
			var fits: bool = true
			for dy: int in range(footprint.y):
				for dx: int in range(footprint.x):
					if occupied.has(origin + Vector2i(dx, dy)):
						fits = false
						break
				if not fits:
					break
			if fits:
				return origin
	return Vector2i(-1, -1)


func _can_fit_inventory_position(
		campaign: CampaignState,
		character_id: StringName,
		container_id: StringName,
		excluded_item_id: StringName,
		position: Vector2i,
		footprint: Vector2i
) -> bool:
	var dimensions: Vector2i = _inventory_dimensions(container_id)
	if position.x < 0 or position.y < 0:
		return false
	if position.x + footprint.x > dimensions.x or position.y + footprint.y > dimensions.y:
		return false
	var occupied: Dictionary = {}
	for item: CampaignItemState in _items_in_container(campaign, character_id, container_id):
		if item.item_id == excluded_item_id:
			continue
		var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
		if definition == null:
			continue
		var existing_footprint: Vector2i = _effective_footprint(definition, item.location.is_rotated)
		for y: int in range(existing_footprint.y):
			for x: int in range(existing_footprint.x):
				occupied[item.location.grid_position + Vector2i(x, y)] = true
	for y: int in range(footprint.y):
		for x: int in range(footprint.x):
			if occupied.has(position + Vector2i(x, y)):
				return false
	return true


func _inventory_dimensions(container_id: StringName) -> Vector2i:
	if container_id == CampaignItemLocationState.CONTAINER_BELT:
		return Vector2i(TacticalInventoryState.BELT_WIDTH, TacticalInventoryState.BELT_HEIGHT)
	return Vector2i(TacticalInventoryState.BACKPACK_WIDTH, TacticalInventoryState.BACKPACK_HEIGHT)


func _effective_footprint(definition: ItemDefinition, is_rotated: bool) -> Vector2i:
	if definition == null:
		return Vector2i.ONE
	if is_rotated:
		return Vector2i(definition.inventory_footprint.y, definition.inventory_footprint.x)
	return definition.inventory_footprint


func _character_weight(campaign: CampaignState, character_id: StringName) -> float:
	var total: float = 0.0
	for raw_item: Variant in campaign.items_for_character(character_id):
		var item: CampaignItemState = raw_item as CampaignItemState
		if item == null:
			continue
		var definition: ItemDefinition = _catalogue.item_definition(item.definition_id)
		if definition != null:
			total += definition.weight_lb * float(item.quantity)
	return total
