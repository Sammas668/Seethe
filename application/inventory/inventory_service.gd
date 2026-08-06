class_name InventoryService
extends RefCounted

const StrategicReservationServiceScript = preload(
	"res://application/inventory/strategic_reservation_service.gd"
)

const INTAKE_REQUIRE_CAPACITY: StringName = &"require_capacity"
const INTAKE_ALLOW_OVERFLOW: StringName = &"allow_overflow"
const LOCATION_STRONGHOLD_STORAGE: StringName = &"stronghold_storage"
const CONDITION_OPERATIONAL: StringName = &"operational"
const CONDITION_UNDER_CONSTRUCTION: StringName = &"under_construction"
const CONDITION_UPGRADING: StringName = &"upgrading"
const CONDITION_DAMAGED: StringName = &"damaged"
const CONDITION_DISABLED: StringName = &"disabled"

var _reservation_service: StrategicReservationServiceScript
var _catalogue
var _stronghold_registry


func configure(
		reservation_service: StrategicReservationServiceScript = null,
		catalogue = null,
		stronghold_registry = null
) -> void:
	_reservation_service = reservation_service
	_catalogue = catalogue
	_stronghold_registry = stronghold_registry


func move_item_to_character_candidate(
		campaign: CampaignState,
		item_id: StringName,
		character_id: StringName,
		container_id: StringName,
		grid_position: Vector2i = Vector2i.ZERO,
		is_rotated: bool = false
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
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
	var definition = _catalogue.item_definition(item.definition_id) if _catalogue != null else null
	if definition != null and definition.fixed_inventory_fixture:
		if (
			item.location != null
			and item.location.belongs_to_character(character_id)
			and item.location.container_id == container_id
			and item.location.grid_position == grid_position
			and item.location.is_rotated == is_rotated
		):
			return OperationResult.no_change(
				item,
				"Raider's Sack is already fixed in its permanent Belt position."
			)
		return OperationResult.fail(
			&"fixed_inventory_fixture",
			"Raider's Sack is granted by Raider's Burden and cannot be moved, transferred or repositioned."
		)
	if campaign.get_character(character_id) == null:
		return OperationResult.fail(&"character_missing", "The selected character no longer exists.")
	if not campaign.assign_item_to_character(
		item_id,
		character_id,
		container_id,
		grid_position,
		is_rotated
	):
		return OperationResult.fail(&"item_transfer_failed", "The item could not be assigned to the character.")
	return OperationResult.ok(item)


func move_item_to_stronghold_candidate(
		campaign: CampaignState,
		item_id: StringName,
		storage_id: StringName = CampaignItemLocationState.DEFAULT_STRONGHOLD_STORAGE_ID,
		intake_policy: StringName = INTAKE_REQUIRE_CAPACITY
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if _reservation_service != null:
		var item_availability: OperationResult = _reservation_service.validate_item_available(
			campaign,
			item_id
		)
		if not item_availability.success:
			return item_availability
	var item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	if item == null:
		return OperationResult.fail(&"item_missing", "The selected item no longer exists.")
	var definition = _catalogue.item_definition(item.definition_id) if _catalogue != null else null
	if definition != null and definition.fixed_inventory_fixture:
		return OperationResult.fail(
			&"fixed_inventory_fixture",
			"Raider's Sack is a permanent Marauder Belt fixture and cannot be returned to Storage."
		)
	if item.location == null or item.location.location_type != LOCATION_STRONGHOLD_STORAGE:
		var intake_item_ids: Array[StringName] = [item_id]
		var capacity_result: OperationResult = validate_storage_intake(
			campaign,
			intake_item_ids,
			intake_policy
		)
		if not capacity_result.success:
			return capacity_result
	if not campaign.move_item_to_stronghold(item_id, storage_id):
		return OperationResult.fail(&"storage_transfer_failed", "The item could not be returned to storage.")
	return OperationResult.ok(item)


func storage_space_for_item(item, catalogue_override = null) -> int:
	if item == null:
		return 0
	var catalogue_value = catalogue_override if catalogue_override != null else _catalogue
	if catalogue_value == null:
		return maxi(1, int(item.quantity))
	var definition = catalogue_value.item_definition(item.definition_id)
	if definition == null:
		return maxi(1, int(item.quantity))
	return definition.storage_space_for_quantity(maxi(1, int(item.quantity)))


func used_item_storage_space(campaign, catalogue_override = null) -> int:
	if campaign == null:
		return 0
	var used: int = 0
	for item in campaign.get_items():
		if (
			item != null
			and item.location != null
			and item.location.location_type == LOCATION_STRONGHOLD_STORAGE
		):
			used += storage_space_for_item(item, catalogue_override)
	return used


func resource_storage_space(campaign) -> int:
	if campaign == null or campaign.resources == null:
		return 0
	return campaign.resources.total_storage_space()


func projected_resource_storage_space(campaign, resource_deltas: Dictionary = {}) -> int:
	if campaign == null or campaign.resources == null:
		return 0
	var used: int = 0
	for resource_id: StringName in CampaignResourceBalances.STORAGE_RESOURCE_IDS:
		var amount: int = campaign.resources.amount(resource_id) + int(resource_deltas.get(resource_id, 0))
		amount = maxi(0, amount)
		if amount > 0:
			used += ceili(float(amount) / float(CampaignResourceBalances.RESOURCE_STORAGE_UNITS_PER_SPACE))
	return used


func used_storage_space(campaign, catalogue_override = null) -> int:
	return used_item_storage_space(campaign, catalogue_override) + resource_storage_space(campaign)


func maximum_storage_space(campaign, stronghold_definition = null) -> int:
	if campaign == null or campaign.stronghold == null:
		return 0
	var definition = stronghold_definition
	if definition == null and _stronghold_registry != null:
		definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
	if definition == null:
		return 0
	var maximum: int = 0
	for facility in campaign.stronghold.get_facilities():
		if facility == null:
			continue
		var facility_definition = definition.facility_definition(facility.definition_id)
		if facility_definition == null:
			continue
		var contribution: int = facility_definition.storage_capacity_for_level(facility.level)
		match facility.condition:
			CONDITION_UNDER_CONSTRUCTION, CONDITION_DISABLED:
				contribution = 0
			CONDITION_DAMAGED:
				contribution = floori(float(contribution) * 0.5)
			CONDITION_OPERATIONAL, CONDITION_UPGRADING:
				pass
			_:
				contribution = 0
		maximum += maxi(0, contribution)
	return maximum


func storage_capacity_snapshot(
		campaign,
		stronghold_definition = null,
		catalogue_override = null
) -> Dictionary:
	var catalogue_value = catalogue_override if catalogue_override != null else _catalogue
	var definition = stronghold_definition
	if definition == null and campaign != null and campaign.stronghold != null and _stronghold_registry != null:
		definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
	var item_used: int = used_item_storage_space(campaign, catalogue_value)
	var resource_used: int = resource_storage_space(campaign)
	var used: int = item_used + resource_used
	var maximum: int = maximum_storage_space(campaign, definition)
	var capacity_sources: Array[Dictionary] = []
	if campaign != null and campaign.stronghold != null and definition != null:
		for facility in campaign.stronghold.get_facilities():
			if facility == null:
				continue
			var facility_definition = definition.facility_definition(facility.definition_id)
			if facility_definition == null:
				continue
			var base_capacity: int = facility_definition.storage_capacity_for_level(facility.level)
			if base_capacity <= 0:
				continue
			var contribution: int = base_capacity
			match facility.condition:
				CONDITION_UNDER_CONSTRUCTION, CONDITION_DISABLED:
					contribution = 0
				CONDITION_DAMAGED:
					contribution = floori(float(contribution) * 0.5)
				CONDITION_OPERATIONAL, CONDITION_UPGRADING:
					pass
				_:
					contribution = 0
			var source_name: String = facility_definition.display_name
			if facility.definition_id == &"facility.fifth_god_heart":
				source_name = "Fifth-God Heart vaults"
			elif facility_definition.max_level > 1:
				source_name = "%s Level %d" % [source_name, facility.level]
			capacity_sources.append({
				"source_id": facility.instance_id,
				"definition_id": facility.definition_id,
				"display_name": source_name,
				"capacity": maxi(0, contribution),
				"base_capacity": maxi(0, base_capacity),
				"condition": facility.condition,
			})
	var usage_by_category: Dictionary = {}
	var resource_usage: Dictionary = {}
	if campaign != null and campaign.resources != null:
		resource_usage = campaign.resources.storage_space_by_resource()
		if resource_used > 0:
			usage_by_category[&"resources"] = resource_used
	if campaign != null and catalogue_value != null:
		for item in campaign.get_items():
			if item == null or item.location == null or item.location.location_type != LOCATION_STRONGHOLD_STORAGE:
				continue
			var item_definition = catalogue_value.item_definition(item.definition_id)
			var category_id: StringName = _storage_category(item_definition)
			usage_by_category[category_id] = int(usage_by_category.get(category_id, 0)) + storage_space_for_item(item, catalogue_value)
	return {
		"used": used,
		"item_used": item_used,
		"resource_used": resource_used,
		"resource_usage": resource_usage,
		"resource_units_per_space": CampaignResourceBalances.RESOURCE_STORAGE_UNITS_PER_SPACE,
		"maximum": maximum,
		"free": maximum - used,
		"overflow": maxi(0, used - maximum),
		"usage_ratio": float(used) / float(maxi(1, maximum)),
		"is_over_capacity": used > maximum,
		"capacity_sources": capacity_sources,
		"usage_by_category": usage_by_category,
	}


func validate_storage_intake(
		campaign,
		item_ids: Array[StringName],
		policy: StringName = INTAKE_REQUIRE_CAPACITY,
		stronghold_definition = null,
		catalogue_override = null
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if policy == INTAKE_ALLOW_OVERFLOW:
		return OperationResult.ok(item_ids, "Mandatory storage intake may create overflow.")
	if policy != INTAKE_REQUIRE_CAPACITY:
		return OperationResult.fail(&"storage_intake_policy_invalid", "The storage intake policy is invalid.")
	var catalogue_value = catalogue_override if catalogue_override != null else _catalogue
	var resolved_definition = stronghold_definition
	if resolved_definition == null and campaign.stronghold != null and _stronghold_registry != null:
		resolved_definition = _stronghold_registry.definition(campaign.stronghold.definition_id)
	# Preserve legacy/unit-test callers that use InventoryService without the
	# campaign-shell content and stronghold authorities. Production CampaignSession
	# always configures both, so capacity remains enforced in actual play.
	if catalogue_value == null or campaign.stronghold == null or resolved_definition == null:
		return OperationResult.ok(item_ids, "Storage capacity authority is unavailable for this compatibility context.")
	var incoming_space: int = 0
	var first_name: String = "This item"
	for item_id: StringName in item_ids:
		var item = campaign.get_item(item_id)
		if item == null:
			return OperationResult.fail(&"item_missing", "The selected item no longer exists.")
		if item.location != null and item.location.location_type == LOCATION_STRONGHOLD_STORAGE:
			continue
		var item_space: int = storage_space_for_item(item, catalogue_value)
		incoming_space += item_space
		if first_name == "This item" and catalogue_value != null:
			var item_definition = catalogue_value.item_definition(item.definition_id)
			if item_definition != null:
				first_name = item_definition.display_name
	var snapshot: Dictionary = storage_capacity_snapshot(campaign, resolved_definition, catalogue_value)
	var free_space: int = maxi(0, int(snapshot.get("maximum", 0)) - int(snapshot.get("used", 0)))
	if incoming_space > free_space:
		return OperationResult.fail(
			&"storage_capacity_insufficient",
			"%s requires %d Storage Space, but only %d is available." % [
				first_name,
				incoming_space,
				free_space,
			]
		)
	return OperationResult.ok(
		{
			"required_space": incoming_space,
			"free_space": free_space,
			"resulting_used": int(snapshot.get("used", 0)) + incoming_space,
			"maximum": int(snapshot.get("maximum", 0)),
		},
		"Storage intake has sufficient capacity."
	)


func _storage_category(definition) -> StringName:
	if definition == null:
		return &"other"
	if definition.has_tag(&"furniture") or definition.has_tag(&"bulky") and definition.has_tag(&"loot"):
		return &"furniture"
	if definition.has_tag(&"salvage"):
		return &"salvage"
	if definition.has_tag(&"ammunition"):
		return &"ammunition"
	if definition.has_tag(&"consumable") or definition.has_tag(&"medical"):
		return &"consumables"
	if definition.has_tag(&"weapon") or definition.has_tag(&"armour") or definition.has_tag(&"shield"):
		return &"equipment"
	return &"other"


func set_item_protected_candidate(
		campaign: CampaignState,
		item_id: StringName,
		protected_value: bool
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if _reservation_service != null:
		var item_availability: OperationResult = _reservation_service.validate_item_available(
			campaign,
			item_id
		)
		if not item_availability.success:
			return item_availability
	var item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	if item == null:
		return OperationResult.fail(&"item_missing", "The selected item no longer exists.")
	if item.is_protected == protected_value:
		return OperationResult.no_change(item, "Item protection is already set.")
	item.set_protected(protected_value)
	return OperationResult.ok(item)


func consume_exact_item_candidate(
		campaign: CampaignState,
		item_id: StringName,
		purpose: StringName = &"item_consumption"
) -> OperationResult:
	if campaign == null:
		return OperationResult.fail(&"campaign_missing", "No campaign is loaded.")
	if _reservation_service != null:
		var availability: OperationResult = _reservation_service.validate_item_available(
			campaign,
			item_id
		)
		if not availability.success:
			return availability
	var item: CampaignItemState = campaign.get_item(item_id) as CampaignItemState
	if item == null:
		return OperationResult.fail(&"item_missing", "The selected item no longer exists.")
	if item.quantity != 1:
		return OperationResult.fail(
			&"exact_item_quantity_invalid",
			"Only one complete exact item may be consumed by this action."
		)
	if not campaign.remove_item(item_id):
		return OperationResult.fail(
			&"item_consumption_failed",
			"The exact item could not be consumed for %s." % String(purpose).replace("_", " ")
		)
	return OperationResult.ok(item, "Exact item consumed.")
