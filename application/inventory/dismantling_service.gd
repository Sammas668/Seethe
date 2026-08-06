extends RefCounted

# Parser-isolated application service. Dismantling is immediate and atomic when
# called through CampaignSession's CampaignChangeSet.
const OperationResultScript = preload("res://core/results/operation_result.gd")
const LOCATION_STRONGHOLD_STORAGE: StringName = &"stronghold_storage"

var _catalogue
var _inventory_service
var _reservation_service


func configure(catalogue, inventory_service, reservation_service = null) -> void:
	_catalogue = catalogue
	_inventory_service = inventory_service
	_reservation_service = reservation_service


func preview_dismantle(campaign, item_id: StringName):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	var item = campaign.get_item(item_id)
	if item == null:
		return OperationResultScript.fail(&"item_missing", "The selected item no longer exists.")
	if _catalogue == null:
		return OperationResultScript.fail(&"content_catalogue_missing", "Dismantling content is unavailable.")
	var definition = _catalogue.item_definition(item.definition_id)
	if definition == null:
		return OperationResultScript.fail(&"item_definition_missing", "The selected item's definition is missing.")
	if definition.fixed_inventory_fixture:
		return OperationResultScript.fail(
			&"dismantle_fixed_fixture",
			"Raider's Sack is granted by Raider's Burden and cannot be dismantled."
		)
	if bool(item.is_protected):
		return OperationResultScript.fail(
			&"dismantle_item_protected",
			"This item is protected from dismantling. Remove protection first."
		)
	if _reservation_service != null:
		var availability = _reservation_service.validate_item_available(campaign, item_id)
		if not availability.success:
			return availability
	if item.location == null or item.location.location_type != LOCATION_STRONGHOLD_STORAGE:
		var owner_name: String = ""
		if item.location != null and not item.location.owner_id.is_empty():
			var owner = campaign.get_character(item.location.owner_id)
			owner_name = owner.display_name if owner != null else String(item.location.owner_id)
		return OperationResultScript.fail(
			&"dismantle_item_not_in_storage",
			"This item is carried by %s." % owner_name
			if not owner_name.is_empty()
			else "This object is not currently in Stronghold Storage."
		)
	var recipe = _catalogue.dismantling_recipe_for_item(item.definition_id)
	if recipe == null or not recipe.basic_dismantling_allowed:
		return OperationResultScript.fail(
			&"dismantling_recipe_missing",
			"This object has no authored dismantling recipe."
		)
	if definition.stackable or item.quantity != 1:
		return OperationResultScript.fail(
			&"stacked_dismantling_unsupported",
			"Stacked items cannot yet be dismantled."
		)
	if not recipe.required_facility_definition_id.is_empty() or not recipe.required_research_id.is_empty():
		return OperationResultScript.fail(
			&"advanced_dismantling_locked",
			"This object requires a later Workshop or Research dismantling method."
		)
	var yields: Dictionary = recipe.clean_resource_yields()
	if yields.is_empty():
		return OperationResultScript.fail(
			&"dismantling_recipe_invalid",
			"The dismantling recipe grants no valid resources."
		)
	var storage_snapshot: Dictionary = (
		_inventory_service.storage_capacity_snapshot(campaign)
		if _inventory_service != null
		else {}
	)
	var storage_released: int = (
		_inventory_service.storage_space_for_item(item)
		if _inventory_service != null
		else definition.storage_space_for_quantity(maxi(1, int(item.quantity)))
	)
	var storage_used_before: int = int(storage_snapshot.get("used", 0))
	var storage_maximum: int = int(storage_snapshot.get("maximum", 0))
	var resource_storage_before: int = int(storage_snapshot.get("resource_used", 0))
	var resource_storage_after: int = (
		_inventory_service.projected_resource_storage_space(campaign, yields)
		if _inventory_service != null
		else resource_storage_before
	)
	var resource_storage_delta: int = resource_storage_after - resource_storage_before
	var storage_used_after: int = maxi(
		0,
		storage_used_before - storage_released + resource_storage_delta
	)
	if storage_used_after > storage_maximum:
		return OperationResultScript.fail(
			&"dismantling_storage_capacity_exceeded",
			"Dismantling would require %d Storage Space, but the stronghold can hold only %d."
			% [storage_used_after, storage_maximum]
		)
	return OperationResultScript.ok(
		{
			"item_id": item.item_id,
			"item_name": definition.display_name,
			"definition_id": item.definition_id,
			"recipe_id": recipe.id,
			"resource_yields": yields.duplicate(true),
			"storage_space_released": storage_released,
			"resource_storage_before": resource_storage_before,
			"resource_storage_after": resource_storage_after,
			"resource_storage_delta": resource_storage_delta,
			"storage_used_before": storage_used_before,
			"storage_used_after": storage_used_after,
			"storage_maximum": storage_maximum,
		},
		"This exact item can be dismantled."
	)


func dismantle_candidate(campaign, item_id: StringName):
	var preview = preview_dismantle(campaign, item_id)
	if not preview.success:
		return preview
	if _inventory_service == null:
		return OperationResultScript.fail(&"inventory_service_missing", "Inventory service is unavailable.")
	var consume_result = _inventory_service.consume_exact_item_candidate(
		campaign,
		item_id,
		&"basic_dismantling"
	)
	if not consume_result.success:
		return consume_result
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var yields: Dictionary = data.get("resource_yields", {}) as Dictionary
	for raw_resource_id: Variant in yields.keys():
		var resource_id := StringName(raw_resource_id)
		var amount: int = int(yields[raw_resource_id])
		if amount <= 0 or campaign.resources == null or not campaign.resources.add(resource_id, amount):
			return OperationResultScript.fail(
				&"dismantling_resource_grant_failed",
				"The campaign resources could not be updated; no changes were made."
			)
	campaign.revision += 1
	return OperationResultScript.ok(data, _success_message(data))


func _success_message(data: Dictionary) -> String:
	var yields: Dictionary = data.get("resource_yields", {}) as Dictionary
	var parts: Array[String] = []
	for raw_resource_id: Variant in yields.keys():
		parts.append("+%d %s" % [
			int(yields[raw_resource_id]),
			String(raw_resource_id).capitalize(),
		])
	parts.sort()
	return "%s dismantled: %s." % [
		String(data.get("item_name", "Item")),
		", ".join(parts),
	]
