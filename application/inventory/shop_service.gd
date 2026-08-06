extends RefCounted

# Stage 5.4A shop authority. The Shop is an entry point into the existing
# Storage domain: purchases enter Stronghold Storage and sales consume exact
# stored item instances or authored lots of stored strategic resources.
const OperationResultScript = preload("res://core/results/operation_result.gd")
const CampaignItemStateScript = preload("res://domain/campaign/campaign_item_state.gd")
const CampaignItemLocationStateScript = preload(
	"res://domain/campaign/campaign_item_location_state.gd"
)
const ShopTransactionStateScript = preload(
	"res://domain/economy/shop_transaction_state.gd"
)

# Resource liquidation is intentionally less valuable than retaining resources
# for construction and future production. Gold itself is never sellable.
const CONTACT_CATALOGUES: Dictionary = {
	&"contact.military_fence": [
		&"item.raiders_axe",
		&"item.guard_shield",
		&"item.sanctuary.capture_spear",
		&"item.sanctuary.padded_arrows",
	],
}

const RESOURCE_SALE_LOTS: Dictionary = {
	&"wood": {"display_name": "Wood", "lot_size": 10, "gold_per_lot": 2},
	&"stone": {"display_name": "Stone", "lot_size": 10, "gold_per_lot": 1},
	&"metal": {"display_name": "Metal", "lot_size": 10, "gold_per_lot": 5},
	&"food": {"display_name": "Food", "lot_size": 10, "gold_per_lot": 2},
	&"textiles": {"display_name": "Textiles", "lot_size": 10, "gold_per_lot": 3},
	&"magic": {"display_name": "Magic", "lot_size": 1, "gold_per_lot": 2},
}

var _catalogue
var _inventory_service
var _reservation_service


func configure(catalogue, inventory_service, reservation_service = null) -> void:
	_catalogue = catalogue
	_inventory_service = inventory_service
	_reservation_service = reservation_service


func starting_catalogue_entries(campaign = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _catalogue == null:
		return result
	for raw_definition: Variant in _catalogue.item_definitions_by_id.values():
		var definition = raw_definition
		if definition == null or int(definition.shop_buy_price_gold) <= 0:
			continue
		if not _definition_available(campaign, definition.id, bool(definition.shop_starting_available)):
			continue
		result.append(_definition_entry(definition))
	result.sort_custom(_sort_entries)
	return result


func sell_storage_entries(campaign) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if campaign == null:
		return result
	if _catalogue != null:
		for item in campaign.stronghold_storage_items():
			if item == null:
				continue
			var definition = _catalogue.item_definition(item.definition_id)
			if definition == null or int(definition.shop_sell_price_gold) <= 0:
				continue
			var preview = preview_sell(campaign, item.item_id, 1)
			result.append({
				"entry_kind": &"item",
				"item_id": item.item_id,
				"definition_id": item.definition_id,
				"display_name": definition.display_name,
				"description": definition.description,
				"category_id": definition.shop_category_id,
				"quantity": int(item.quantity),
				"unit_price_gold": int(definition.shop_sell_price_gold),
				"weight_lb": float(definition.weight_lb),
				"protected": bool(item.is_protected),
				"available": bool(preview.success),
				"unavailable_reason": "" if preview.success else String(preview.message),
			})
	result.append_array(_resource_sell_entries(campaign))
	result.sort_custom(_sort_entries)
	return result


func preview_buy(campaign, definition_id: StringName, quantity: int = 1):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	if _catalogue == null:
		return OperationResultScript.fail(&"shop_catalogue_missing", "The Shop catalogue is unavailable.")
	var definition = _catalogue.item_definition(definition_id)
	if definition == null:
		return OperationResultScript.fail(&"shop_item_missing", "The selected Shop item is unavailable.")
	if int(definition.shop_buy_price_gold) <= 0 or not _definition_available(
		campaign,
		definition.id,
		bool(definition.shop_starting_available)
	):
		return OperationResultScript.fail(
			&"shop_item_locked",
			"This item is not sold by any currently available contact."
		)
	var requested_quantity: int = maxi(1, quantity)
	if requested_quantity > 99:
		return OperationResultScript.fail(
			&"shop_quantity_excessive",
			"A single Shop transaction may purchase at most 99 units."
		)
	var unit_price: int = int(definition.shop_buy_price_gold)
	var total_gold: int = unit_price * requested_quantity
	var gold_before: int = campaign.resources.amount(&"gold") if campaign.resources != null else 0
	if gold_before < total_gold:
		return OperationResultScript.fail(
			&"shop_insufficient_gold",
			"Requires %d Gold; only %d is stored." % [total_gold, gold_before]
		)
	var storage_required: int = _purchase_storage_space(definition, requested_quantity)
	var storage_snapshot: Dictionary = (
		_inventory_service.storage_capacity_snapshot(campaign)
		if _inventory_service != null
		else {}
	)
	var storage_used: int = int(storage_snapshot.get("used", 0))
	var reserved_output_space: int = (
		_reservation_service.reserved_output_storage_space(campaign)
		if _reservation_service != null
		else 0
	)
	var effective_storage_used: int = storage_used + reserved_output_space
	var storage_maximum: int = int(storage_snapshot.get("maximum", 0))
	if effective_storage_used + storage_required > storage_maximum:
		return OperationResultScript.fail(
			&"shop_storage_capacity_exceeded",
			"Requires %d Storage Space; only %d is free." % [
				storage_required,
				maxi(0, storage_maximum - effective_storage_used),
			]
		)
	return OperationResultScript.ok(
		{
			"entry_kind": &"item",
			"definition_id": definition.id,
			"display_name": definition.display_name,
			"quantity": requested_quantity,
			"unit_price_gold": unit_price,
			"total_gold": total_gold,
			"gold_before": gold_before,
			"gold_after": gold_before - total_gold,
			"storage_required": storage_required,
			"storage_used_before": storage_used,
			"reserved_output_storage_space": reserved_output_space,
			"storage_used_after": effective_storage_used + storage_required,
			"storage_maximum": storage_maximum,
		},
		"Purchase is valid."
	)


func buy_candidate(campaign, definition_id: StringName, quantity: int = 1):
	var preview = preview_buy(campaign, definition_id, quantity)
	if not preview.success:
		return preview
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var definition = _catalogue.item_definition(definition_id)
	if definition == null:
		return OperationResultScript.fail(&"shop_item_missing", "The selected Shop item is unavailable.")
	var total_gold: int = int(data.get("total_gold", 0))
	if campaign.resources == null or not campaign.resources.add(&"gold", -total_gold):
		return OperationResultScript.fail(&"shop_gold_commit_failed", "The purchase could not spend Gold.")
	var remaining: int = int(data.get("quantity", 1))
	var created_item_ids: Array[StringName] = []
	while remaining > 0:
		var stack_quantity: int = 1
		if bool(definition.stackable):
			stack_quantity = mini(remaining, maxi(1, int(definition.maximum_stack_size)))
		var item_id: StringName = campaign.allocate_shop_item_id()
		var item = CampaignItemStateScript.new(
			item_id,
			definition.id,
			stack_quantity,
			1.0,
			CampaignItemLocationStateScript.stronghold_storage()
		)
		if not campaign.add_item(item):
			return OperationResultScript.fail(
				&"shop_item_creation_failed",
				"The purchased item could not be placed in Storage."
			)
		created_item_ids.append(item_id)
		remaining -= stack_quantity
	var transaction = ShopTransactionStateScript.new()
	transaction.transaction_id = campaign.allocate_shop_transaction_id()
	transaction.transaction_kind = ShopTransactionStateScript.KIND_BUY
	transaction.item_definition_id = definition.id
	transaction.item_ids = created_item_ids.duplicate()
	transaction.quantity = int(data.get("quantity", 1))
	transaction.unit_price_gold = int(data.get("unit_price_gold", 0))
	transaction.total_gold = total_gold
	transaction.gold_before = int(data.get("gold_before", 0))
	transaction.gold_after = campaign.resources.amount(&"gold")
	transaction.campaign_tick = int(campaign.campaign_tick)
	if not campaign.record_shop_transaction(transaction):
		return OperationResultScript.fail(
			&"shop_transaction_record_failed",
			"The purchase record could not be stored."
		)
	data["created_item_ids"] = created_item_ids.duplicate()
	data["transaction_id"] = transaction.transaction_id
	return OperationResultScript.ok(
		data,
		"Purchased %d × %s for %d Gold." % [transaction.quantity, definition.display_name, total_gold]
	)


func preview_sell(campaign, item_id: StringName, quantity: int = 1):
	if campaign == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign is loaded.")
	var item = campaign.get_item(item_id)
	if item == null:
		return OperationResultScript.fail(&"item_missing", "The selected item no longer exists.")
	if _catalogue == null:
		return OperationResultScript.fail(&"shop_catalogue_missing", "The Shop catalogue is unavailable.")
	var definition = _catalogue.item_definition(item.definition_id)
	if definition == null:
		return OperationResultScript.fail(&"item_definition_missing", "The selected item's definition is missing.")
	if definition.fixed_inventory_fixture:
		return OperationResultScript.fail(
			&"shop_fixed_fixture",
			"Raider's Sack is granted by Raider's Burden and cannot be sold."
		)
	if item.location == null or not item.location.is_stronghold_storage():
		return OperationResultScript.fail(
			&"shop_item_not_in_storage",
			"Only items currently held in Stronghold Storage can be sold."
		)
	if bool(item.is_protected):
		return OperationResultScript.fail(
			&"shop_item_protected",
			"This item is protected from sale. Remove protection in Storage first."
		)
	if item.condition <= 0.0:
		return OperationResultScript.fail(
			&"shop_item_destroyed",
			"Destroyed items cannot be sold intact. Repair or dismantle them instead."
		)
	if _reservation_service != null:
		var availability = _reservation_service.validate_item_available(campaign, item_id)
		if not availability.success:
			return availability
	var unit_price: int = int(definition.shop_sell_price_gold)
	if unit_price <= 0:
		return OperationResultScript.fail(&"shop_item_unsellable", "No current contact will buy this item.")
	var requested_quantity: int = maxi(1, quantity)
	if requested_quantity > int(item.quantity):
		return OperationResultScript.fail(
			&"shop_sale_quantity_invalid",
			"Only %d unit(s) of this exact stored stack remain." % int(item.quantity)
		)
	var gold_before: int = campaign.resources.amount(&"gold") if campaign.resources != null else 0
	var total_gold: int = unit_price * requested_quantity
	return OperationResultScript.ok(
		{
			"entry_kind": &"item",
			"item_id": item.item_id,
			"definition_id": item.definition_id,
			"display_name": definition.display_name,
			"quantity": requested_quantity,
			"stack_quantity_before": int(item.quantity),
			"unit_price_gold": unit_price,
			"total_gold": total_gold,
			"gold_before": gold_before,
			"gold_after": gold_before + total_gold,
		},
		"Sale is valid."
	)


func sell_candidate(campaign, item_id: StringName, quantity: int = 1):
	var preview = preview_sell(campaign, item_id, quantity)
	if not preview.success:
		return preview
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var item = campaign.get_item(item_id)
	if item == null:
		return OperationResultScript.fail(&"item_missing", "The selected item no longer exists.")
	var sold_quantity: int = int(data.get("quantity", 1))
	if sold_quantity >= int(item.quantity):
		if not campaign.remove_item(item_id):
			return OperationResultScript.fail(&"shop_sale_consume_failed", "The sold item could not be removed.")
	else:
		item.quantity -= sold_quantity
		item.revision += 1
		campaign.revision += 1
	var total_gold: int = int(data.get("total_gold", 0))
	if campaign.resources == null or not campaign.resources.add(&"gold", total_gold):
		return OperationResultScript.fail(&"shop_gold_commit_failed", "The sale could not add Gold.")
	var transaction = ShopTransactionStateScript.new()
	transaction.transaction_id = campaign.allocate_shop_transaction_id()
	transaction.transaction_kind = ShopTransactionStateScript.KIND_SELL
	transaction.item_definition_id = StringName(data.get("definition_id", &""))
	transaction.item_ids.clear()
	transaction.item_ids.append(item_id)
	transaction.quantity = sold_quantity
	transaction.unit_price_gold = int(data.get("unit_price_gold", 0))
	transaction.total_gold = total_gold
	transaction.gold_before = int(data.get("gold_before", 0))
	transaction.gold_after = campaign.resources.amount(&"gold")
	transaction.campaign_tick = int(campaign.campaign_tick)
	if not campaign.record_shop_transaction(transaction):
		return OperationResultScript.fail(
			&"shop_transaction_record_failed",
			"The sale record could not be stored."
		)
	data["transaction_id"] = transaction.transaction_id
	return OperationResultScript.ok(
		data,
		"Sold %d × %s for %d Gold." % [
			sold_quantity,
			String(data.get("display_name", "Item")),
			total_gold,
		]
	)


func preview_sell_resource(campaign, resource_id: StringName, lot_quantity: int = 1):
	if campaign == null or campaign.resources == null:
		return OperationResultScript.fail(&"campaign_missing", "No campaign resources are available.")
	if resource_id == &"gold":
		return OperationResultScript.fail(&"shop_gold_unsellable", "Gold cannot be sold for Gold.")
	var sale_definition: Dictionary = RESOURCE_SALE_LOTS.get(resource_id, {}) as Dictionary
	if sale_definition.is_empty():
		return OperationResultScript.fail(&"shop_resource_unsellable", "No current contact buys this resource.")
	var requested_lots: int = maxi(1, lot_quantity)
	var lot_size: int = maxi(1, int(sale_definition.get("lot_size", 1)))
	var resource_amount: int = requested_lots * lot_size
	var resource_before: int = campaign.resources.amount(resource_id)
	var resource_available: int = (
		_reservation_service.available_resource_amount(campaign, resource_id)
		if _reservation_service != null and _reservation_service.has_method("available_resource_amount")
		else resource_before
	)
	if resource_amount > resource_available:
		return OperationResultScript.fail(
			&"shop_resource_quantity_invalid",
			"Only %d unreserved %s is available; sales use lots of %d." % [
				resource_available,
				String(sale_definition.get("display_name", resource_id)),
				lot_size,
			]
		)
	var gold_per_lot: int = maxi(1, int(sale_definition.get("gold_per_lot", 1)))
	var total_gold: int = requested_lots * gold_per_lot
	var gold_before: int = campaign.resources.amount(&"gold")
	var storage_snapshot: Dictionary = (
		_inventory_service.storage_capacity_snapshot(campaign)
		if _inventory_service != null
		else {}
	)
	var storage_used_before: int = int(storage_snapshot.get("used", 0))
	var resource_storage_before: int = int(storage_snapshot.get("resource_used", 0))
	var resource_storage_after: int = (
		_inventory_service.projected_resource_storage_space(
			campaign,
			{resource_id: -resource_amount}
		)
		if _inventory_service != null
		else resource_storage_before
	)
	var storage_used_after: int = maxi(
		0,
		storage_used_before - resource_storage_before + resource_storage_after
	)
	return OperationResultScript.ok(
		{
			"entry_kind": &"resource",
			"resource_id": resource_id,
			"display_name": String(sale_definition.get("display_name", resource_id)),
			"quantity": requested_lots,
			"lot_size": lot_size,
			"resource_amount": resource_amount,
			"resource_before": resource_before,
			"resource_after": resource_before - resource_amount,
			"unit_price_gold": gold_per_lot,
			"total_gold": total_gold,
			"gold_before": gold_before,
			"gold_after": gold_before + total_gold,
			"storage_used_before": storage_used_before,
			"storage_used_after": storage_used_after,
			"storage_maximum": int(storage_snapshot.get("maximum", 0)),
		},
		"Resource sale is valid."
	)


func sell_resource_candidate(campaign, resource_id: StringName, lot_quantity: int = 1):
	var preview = preview_sell_resource(campaign, resource_id, lot_quantity)
	if not preview.success:
		return preview
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var resource_amount: int = int(data.get("resource_amount", 0))
	var total_gold: int = int(data.get("total_gold", 0))
	if not campaign.resources.add(resource_id, -resource_amount):
		return OperationResultScript.fail(&"shop_resource_commit_failed", "The resource sale could not remove the stored goods.")
	if not campaign.resources.add(&"gold", total_gold):
		return OperationResultScript.fail(&"shop_gold_commit_failed", "The resource sale could not add Gold.")
	var transaction = ShopTransactionStateScript.new()
	transaction.transaction_id = campaign.allocate_shop_transaction_id()
	transaction.transaction_kind = ShopTransactionStateScript.KIND_SELL
	transaction.resource_id = resource_id
	transaction.resource_amount = resource_amount
	transaction.quantity = int(data.get("quantity", 1))
	transaction.unit_price_gold = int(data.get("unit_price_gold", 0))
	transaction.total_gold = total_gold
	transaction.gold_before = int(data.get("gold_before", 0))
	transaction.gold_after = campaign.resources.amount(&"gold")
	transaction.campaign_tick = int(campaign.campaign_tick)
	if not campaign.record_shop_transaction(transaction):
		return OperationResultScript.fail(
			&"shop_transaction_record_failed",
			"The resource sale record could not be stored."
		)
	data["transaction_id"] = transaction.transaction_id
	return OperationResultScript.ok(
		data,
		"Sold %d %s for %d Gold." % [
			resource_amount,
			String(data.get("display_name", resource_id)),
			total_gold,
		]
	)


func _resource_sell_entries(campaign) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if campaign == null or campaign.resources == null:
		return result
	for raw_resource_id: Variant in RESOURCE_SALE_LOTS.keys():
		var resource_id := StringName(raw_resource_id)
		var definition: Dictionary = RESOURCE_SALE_LOTS[raw_resource_id] as Dictionary
		var amount: int = campaign.resources.amount(resource_id)
		var available_amount: int = (
			_reservation_service.available_resource_amount(campaign, resource_id)
			if _reservation_service != null and _reservation_service.has_method("available_resource_amount")
			else amount
		)
		if amount <= 0:
			continue
		var lot_size: int = maxi(1, int(definition.get("lot_size", 1)))
		var maximum_lots: int = available_amount / lot_size
		var preview = preview_sell_resource(campaign, resource_id, 1)
		result.append({
			"entry_kind": &"resource",
			"resource_id": resource_id,
			"display_name": String(definition.get("display_name", resource_id)),
			"description": "Stored strategic resource. Sold in fixed lots through current contacts.",
			"category_id": &"resources",
			"quantity": maxi(1, maximum_lots),
			"maximum_lots": maximum_lots,
			"resource_amount": amount,
			"lot_size": lot_size,
			"unit_price_gold": maxi(1, int(definition.get("gold_per_lot", 1))),
			"available": bool(preview.success),
			"unavailable_reason": "" if preview.success else String(preview.message),
		})
	return result


func _definition_available(campaign, definition_id: StringName, starting_available: bool) -> bool:
	if starting_available:
		return true
	if campaign == null:
		return false
	for raw_contact_id: Variant in CONTACT_CATALOGUES.keys():
		var contact_id := StringName(raw_contact_id)
		if not campaign.has_shop_contact(contact_id):
			continue
		var catalogue_ids: Array = CONTACT_CATALOGUES[raw_contact_id] as Array
		if catalogue_ids.has(definition_id):
			return true
	return false


func _definition_entry(definition) -> Dictionary:
	return {
		"entry_kind": &"item",
		"definition_id": definition.id,
		"display_name": definition.display_name,
		"description": definition.description,
		"category_id": definition.shop_category_id,
		"buy_price_gold": int(definition.shop_buy_price_gold),
		"sell_price_gold": int(definition.shop_sell_price_gold),
		"weight_lb": float(definition.weight_lb),
		"stackable": bool(definition.stackable),
		"maximum_stack_size": int(definition.maximum_stack_size),
		"storage_space": int(definition.storage_space),
	}


func _purchase_storage_space(definition, quantity: int) -> int:
	if definition == null or quantity <= 0:
		return 0
	if not bool(definition.stackable):
		return definition.storage_space_for_quantity(quantity)
	var remaining: int = quantity
	var required: int = 0
	var maximum_stack: int = maxi(1, int(definition.maximum_stack_size))
	while remaining > 0:
		var stack_quantity: int = mini(remaining, maximum_stack)
		required += definition.storage_space_for_quantity(stack_quantity)
		remaining -= stack_quantity
	return required


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	var category_compare: int = String(a.get("category_id", "other")).naturalnocasecmp_to(
		String(b.get("category_id", "other"))
	)
	if category_compare != 0:
		return category_compare < 0
	var name_compare: int = String(a.get("display_name", "")).naturalnocasecmp_to(
		String(b.get("display_name", ""))
	)
	if name_compare != 0:
		return name_compare < 0
	return String(a.get("item_id", a.get("resource_id", ""))) < String(
		b.get("item_id", b.get("resource_id", ""))
	)
