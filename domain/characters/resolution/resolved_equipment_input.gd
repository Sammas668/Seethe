class_name ResolvedEquipmentInput
extends RefCounted

var item_id: StringName = &""
var definition_id: StringName = &""
var definition: ItemDefinition
var location_type: StringName = &""
var container_id: StringName = &""
var quantity: int = 1
var condition: float = 1.0
var persistent_modifiers: Dictionary = {}
var equipped: bool = false
var carried: bool = false


func configure(
		item_id_value: StringName,
		definition_value: ItemDefinition,
		location_type_value: StringName,
		container_id_value: StringName,
		quantity_value: int,
		condition_value: float,
		persistent_modifiers_value: Dictionary,
		equipped_value: bool,
		carried_value: bool
) -> void:
	item_id = item_id_value
	definition = definition_value
	definition_id = definition.id if definition != null else &""
	location_type = location_type_value
	container_id = container_id_value
	quantity = maxi(1, quantity_value)
	condition = clampf(condition_value, 0.0, 1.0)
	persistent_modifiers = persistent_modifiers_value.duplicate(true)
	equipped = equipped_value
	carried = carried_value


func stat_modifier(stat_id: StringName) -> int:
	var total: int = 0
	if definition != null:
		total += int(definition.stat_modifier(stat_id))
	var nested: Variant = persistent_modifiers.get("stat_modifiers", {})
	if nested is Dictionary:
		total += int((nested as Dictionary).get(String(stat_id), 0))
	total += int(persistent_modifiers.get(String(stat_id), 0))
	return total
