class_name ShopTransactionState
extends RefCounted

const KIND_BUY: StringName = &"buy"
const KIND_SELL: StringName = &"sell"

var transaction_id: StringName = &""
var transaction_kind: StringName = KIND_BUY
var item_definition_id: StringName = &""
var item_ids: Array[StringName] = []
var resource_id: StringName = &""
var resource_amount: int = 0
# Quantity is the number of priced lots. Item transactions always use one item
# per lot; resource transactions use the authored trade-lot size.
var quantity: int = 0
var unit_price_gold: int = 0
var total_gold: int = 0
var gold_before: int = 0
var gold_after: int = 0
var campaign_tick: int = 0


func is_resource_transaction() -> bool:
	return not resource_id.is_empty()


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if transaction_id.is_empty():
		errors.append("Shop transaction has no transaction ID.")
	if transaction_kind not in [KIND_BUY, KIND_SELL]:
		errors.append("Shop transaction %s has unknown kind %s." % [transaction_id, transaction_kind])
	if quantity < 1:
		errors.append("Shop transaction %s has an invalid quantity." % transaction_id)
	if unit_price_gold < 0 or total_gold < 0:
		errors.append("Shop transaction %s has a negative price." % transaction_id)
	if total_gold != unit_price_gold * quantity:
		errors.append("Shop transaction %s has an inconsistent total." % transaction_id)
	if gold_before < 0 or gold_after < 0:
		errors.append("Shop transaction %s has an invalid Gold balance." % transaction_id)
	if is_resource_transaction():
		if transaction_kind != KIND_SELL:
			errors.append("Resource transaction %s is not a sale." % transaction_id)
		if resource_id == &"gold":
			errors.append("Shop transaction %s attempts to sell Gold." % transaction_id)
		if resource_amount < 1:
			errors.append("Shop transaction %s records no resource amount." % transaction_id)
		if not item_definition_id.is_empty() or not item_ids.is_empty():
			errors.append("Resource transaction %s also records item identity." % transaction_id)
	else:
		if item_definition_id.is_empty():
			errors.append("Shop transaction %s has no item definition." % transaction_id)
		if item_ids.is_empty():
			errors.append("Shop transaction %s records no exact item identity." % transaction_id)
		if resource_amount != 0:
			errors.append("Item transaction %s records a resource amount." % transaction_id)
	var seen_item_ids: Dictionary = {}
	for item_id: StringName in item_ids:
		if item_id.is_empty():
			errors.append("Shop transaction %s contains an empty item ID." % transaction_id)
		elif seen_item_ids.has(item_id):
			errors.append("Shop transaction %s repeats item %s." % [transaction_id, item_id])
		else:
			seen_item_ids[item_id] = true
	if transaction_kind == KIND_BUY and gold_after != gold_before - total_gold:
		errors.append("Shop purchase %s does not conserve Gold." % transaction_id)
	if transaction_kind == KIND_SELL and gold_after != gold_before + total_gold:
		errors.append("Shop sale %s does not conserve Gold." % transaction_id)
	return errors


func to_dictionary() -> Dictionary:
	var serialized_item_ids: Array[String] = []
	for item_id: StringName in item_ids:
		serialized_item_ids.append(String(item_id))
	return {
		"transaction_id": String(transaction_id),
		"transaction_kind": String(transaction_kind),
		"item_definition_id": String(item_definition_id),
		"item_ids": serialized_item_ids,
		"resource_id": String(resource_id),
		"resource_amount": resource_amount,
		"quantity": quantity,
		"unit_price_gold": unit_price_gold,
		"total_gold": total_gold,
		"gold_before": gold_before,
		"gold_after": gold_after,
		"campaign_tick": campaign_tick,
	}


static func from_dictionary(data: Dictionary) -> ShopTransactionState:
	var result := ShopTransactionState.new()
	result.transaction_id = StringName(data.get("transaction_id", ""))
	result.transaction_kind = StringName(data.get("transaction_kind", KIND_BUY))
	result.item_definition_id = StringName(data.get("item_definition_id", ""))
	for raw_item_id: Variant in data.get("item_ids", []):
		var item_id := StringName(raw_item_id)
		if not item_id.is_empty() and not result.item_ids.has(item_id):
			result.item_ids.append(item_id)
	result.resource_id = StringName(data.get("resource_id", ""))
	result.resource_amount = maxi(0, int(data.get("resource_amount", 0)))
	result.quantity = maxi(0, int(data.get("quantity", 0)))
	result.unit_price_gold = maxi(0, int(data.get("unit_price_gold", 0)))
	result.total_gold = maxi(0, int(data.get("total_gold", 0)))
	result.gold_before = maxi(0, int(data.get("gold_before", 0)))
	result.gold_after = maxi(0, int(data.get("gold_after", 0)))
	result.campaign_tick = maxi(0, int(data.get("campaign_tick", 0)))
	return result
