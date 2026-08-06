class_name LoadoutItemRule
extends RefCounted

var rule_id: StringName = &""
var exact_item_id: StringName = &""
var item_definition_id: StringName = &""
var required_tags: Array[StringName] = []
var preferred_tags: Array[StringName] = []
var quantity: int = 1
var minimum_tier: int = 0
var minimum_condition: float = 0.01
var preferred_container_id: StringName = CampaignItemLocationState.CONTAINER_BACKPACK
var preferred_grid_position: Vector2i = Vector2i(-1, -1)
var fixed_position: bool = false
var preferred_is_rotated: bool = false
var allow_rotation: bool = true
var required: bool = true
var allow_substitution: bool = true


func clone() -> LoadoutItemRule:
	return LoadoutItemRule.from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	var required_tag_strings: Array[String] = []
	for tag: StringName in required_tags:
		required_tag_strings.append(String(tag))
	var preferred_tag_strings: Array[String] = []
	for tag: StringName in preferred_tags:
		preferred_tag_strings.append(String(tag))
	return {
		"rule_id": String(rule_id),
		"exact_item_id": String(exact_item_id),
		"item_definition_id": String(item_definition_id),
		"required_tags": required_tag_strings,
		"preferred_tags": preferred_tag_strings,
		"quantity": quantity,
		"minimum_tier": minimum_tier,
		"minimum_condition": minimum_condition,
		"preferred_container_id": String(preferred_container_id),
		"preferred_grid_position": [preferred_grid_position.x, preferred_grid_position.y],
		"fixed_position": fixed_position,
		"preferred_is_rotated": preferred_is_rotated,
		"allow_rotation": allow_rotation,
		"required": required,
		"allow_substitution": allow_substitution,
	}


static func from_dictionary(data: Dictionary) -> LoadoutItemRule:
	var result := LoadoutItemRule.new()
	result.rule_id = StringName(data.get("rule_id", ""))
	result.exact_item_id = StringName(data.get("exact_item_id", ""))
	result.item_definition_id = StringName(data.get("item_definition_id", ""))
	result.required_tags = _string_name_array(data.get("required_tags", []))
	result.preferred_tags = _string_name_array(data.get("preferred_tags", []))
	result.quantity = maxi(1, int(data.get("quantity", 1)))
	result.minimum_tier = maxi(0, int(data.get("minimum_tier", 0)))
	result.minimum_condition = clampf(float(data.get("minimum_condition", 0.01)), 0.0, 1.0)
	result.preferred_container_id = StringName(
		data.get("preferred_container_id", CampaignItemLocationState.CONTAINER_BACKPACK)
	)
	if result.preferred_container_id == CampaignItemLocationState.CONTAINER_WORN_UTILITY:
		result.preferred_container_id = CampaignItemLocationState.CONTAINER_BACKPACK
	result.preferred_grid_position = CampaignItemLocationState._vector_from_value(
		data.get("preferred_grid_position", [-1, -1])
	)
	result.fixed_position = bool(data.get("fixed_position", false))
	result.preferred_is_rotated = bool(data.get("preferred_is_rotated", false))
	result.allow_rotation = bool(data.get("allow_rotation", true))
	result.required = bool(data.get("required", true))
	result.allow_substitution = bool(data.get("allow_substitution", true))
	return result


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for entry: Variant in value as Array:
		var parsed := StringName(entry)
		if not parsed.is_empty():
			result.append(parsed)
	return result
