class_name TacticalGeneratedItemProvenance
extends RefCounted

const CREATION_STRUCTURAL_SALVAGE: StringName = &"structural_salvage"
const CREATION_TRANSFORMED_ITEM: StringName = &"transformed_item"
const CREATION_MISSION_CRAFTED_ITEM: StringName = &"mission_crafted_item"
const CREATION_CORPSE_GENERATED_LOOT: StringName = &"corpse_generated_loot"
const CREATION_MAGICALLY_CREATED: StringName = &"magically_created_persistent_item"
const CREATION_SCRIPTED_REWARD: StringName = &"scripted_objective_reward"

const ALLOWED_CREATION_KINDS: Array[StringName] = [
	CREATION_STRUCTURAL_SALVAGE,
	CREATION_TRANSFORMED_ITEM,
	CREATION_MISSION_CRAFTED_ITEM,
	CREATION_CORPSE_GENERATED_LOOT,
	CREATION_MAGICALLY_CREATED,
	CREATION_SCRIPTED_REWARD,
]

var provenance_id: StringName = &""
var mission_id: StringName = &""
var source_setup_hash: String = ""
var generated_item_id: StringName = &""
var creation_kind: StringName = &""
var source_event_id: StringName = &""
var source_entity_id: StringName = &""
var source_item_ids: Array[StringName] = []
var consumed_source_item_ids: Array[StringName] = []
var definition_id: StringName = &""
var quantity: int = 1
var condition: float = 1.0
var persistent_modifiers: Dictionary = {}
var creation_revision: int = 0


func duplicate_record() -> TacticalGeneratedItemProvenance:
	return from_dictionary(to_dictionary())


func validate_record() -> Array[String]:
	var errors: Array[String] = []
	if provenance_id.is_empty():
		errors.append("Generated-item provenance has no ID.")
	if mission_id.is_empty():
		errors.append("Generated-item provenance has no mission ID.")
	if source_setup_hash.length() != 64:
		errors.append("Generated-item provenance has no valid setup hash.")
	if generated_item_id.is_empty():
		errors.append("Generated-item provenance has no item ID.")
	if creation_kind not in ALLOWED_CREATION_KINDS:
		errors.append("Generated-item provenance uses an unknown creation kind.")
	if source_event_id.is_empty():
		errors.append("Generated-item provenance has no source event.")
	if definition_id.is_empty() or quantity < 1:
		errors.append("Generated-item provenance has invalid item values.")
	if condition < 0.0 or condition > 1.0:
		errors.append("Generated-item provenance has invalid condition.")
	return errors


func matches_item(item: TacticalItemInstanceState) -> bool:
	return (
		item != null
		and item.item_id == generated_item_id
		and item.definition_id == definition_id
		and item.quantity == quantity
		and is_equal_approx(item.condition, condition)
		and item.tactical_modifiers == persistent_modifiers
	)


func matches_campaign_item(item: CampaignItemState) -> bool:
	return (
		item != null
		and item.item_id == generated_item_id
		and item.definition_id == definition_id
		and item.quantity == quantity
		and is_equal_approx(item.condition, condition)
		and item.persistent_modifiers == persistent_modifiers
	)


func to_dictionary() -> Dictionary:
	return {
		"provenance_id": String(provenance_id),
		"mission_id": String(mission_id),
		"source_setup_hash": source_setup_hash,
		"generated_item_id": String(generated_item_id),
		"creation_kind": String(creation_kind),
		"source_event_id": String(source_event_id),
		"source_entity_id": String(source_entity_id),
		"source_item_ids": _serialize_ids(source_item_ids),
		"consumed_source_item_ids": _serialize_ids(consumed_source_item_ids),
		"definition_id": String(definition_id),
		"quantity": quantity,
		"condition": condition,
		"persistent_modifiers": persistent_modifiers.duplicate(true),
		"creation_revision": creation_revision,
	}


static func from_dictionary(data: Dictionary) -> TacticalGeneratedItemProvenance:
	var result := TacticalGeneratedItemProvenance.new()
	result.provenance_id = StringName(data.get("provenance_id", ""))
	result.mission_id = StringName(data.get("mission_id", ""))
	result.source_setup_hash = String(data.get("source_setup_hash", ""))
	result.generated_item_id = StringName(data.get("generated_item_id", ""))
	result.creation_kind = StringName(data.get("creation_kind", ""))
	result.source_event_id = StringName(data.get("source_event_id", ""))
	result.source_entity_id = StringName(data.get("source_entity_id", ""))
	result.source_item_ids = _deserialize_ids(data.get("source_item_ids", []))
	result.consumed_source_item_ids = _deserialize_ids(
		data.get("consumed_source_item_ids", [])
	)
	result.definition_id = StringName(data.get("definition_id", ""))
	result.quantity = maxi(0, int(data.get("quantity", 0)))
	result.condition = float(data.get("condition", 1.0))
	var modifiers: Variant = data.get("persistent_modifiers", {})
	if modifiers is Dictionary:
		result.persistent_modifiers = (modifiers as Dictionary).duplicate(true)
	result.creation_revision = maxi(0, int(data.get("creation_revision", 0)))
	return result


static func _serialize_ids(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _deserialize_ids(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value: Variant in values as Array:
			var item := StringName(value)
			if not item.is_empty():
				result.append(item)
	return result
