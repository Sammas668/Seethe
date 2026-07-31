class_name TacticalItemInstanceState
extends RefCounted

const INSTANCE_KIND_ITEM: StringName = &"item"
const INSTANCE_KIND_BODY: StringName = &"body"

var item_id: StringName
var definition_id: StringName
var definition: ItemDefinition
var quantity: int
var condition: float
var location: TacticalItemLocationState
var tactical_modifiers: Dictionary
# Body items are ordinary persistent tactical item instances with one location.
# The linked unit remains authoritative for HP, identity, equipment and conditions.
var instance_kind: StringName = INSTANCE_KIND_ITEM
var linked_unit_id: StringName = &""
var display_name_override: String = ""
var weight_override_lb: float = -1.0
var footprint_override: Vector2i = Vector2i.ZERO

var display_name: String:
	get:
		if not display_name_override.is_empty():
			return display_name_override
		return definition.display_name if definition != null else "Unknown item"

var weight_lb: float:
	get:
		if weight_override_lb >= 0.0:
			return weight_override_lb
		if definition == null:
			return 0.0
		return definition.weight_lb * quantity

var footprint: Vector2i:
	get:
		if footprint_override.x > 0 and footprint_override.y > 0:
			return footprint_override
		if definition == null:
			return Vector2i.ONE
		return Vector2i(
			maxi(1, definition.inventory_footprint.x),
			maxi(1, definition.inventory_footprint.y)
		)

var two_handed: bool:
	get:
		return definition != null and definition.is_two_handed()

var belt_allowed: bool:
	get:
		return definition != null and definition.belt_allowed

var backpack_allowed: bool:
	get:
		return definition != null and definition.backpack_allowed

var source_label: String:
	get:
		return location.source_label if location != null else ""


func _init(
		item_id_value: StringName = &"",
		definition_value: ItemDefinition = null,
		quantity_value: int = 1,
		condition_value: float = 1.0,
		location_value: TacticalItemLocationState = null,
		tactical_modifiers_value: Dictionary = {}
) -> void:
	item_id = item_id_value
	definition = definition_value
	definition_id = definition.id if definition != null else &""
	quantity = maxi(1, quantity_value)
	condition = clampf(condition_value, 0.0, 1.0)
	location = (
		location_value
		if location_value != null
		else TacticalItemLocationState.new()
	)
	tactical_modifiers = tactical_modifiers_value.duplicate(true)


func compact_display_name() -> String:
	if quantity > 1:
		return "%s ×%d" % [display_name, quantity]
	return display_name


func display_line() -> String:
	var quantity_text := ""
	if quantity > 1:
		quantity_text = " x%d" % quantity
	return "%s%s · %.1f lb" % [display_name, quantity_text, weight_lb]


func is_body() -> bool:
	return instance_kind == INSTANCE_KIND_BODY and not linked_unit_id.is_empty()


static func create_body(
		unit: TacticalUnitState,
		location_value: TacticalItemLocationState
) -> TacticalItemInstanceState:
	var body_definition := ItemDefinition.new()
	body_definition.id = &"item.body"
	body_definition.display_name = "Body"
	body_definition.description = (
		"A fallen character. Its linked character record remains authoritative."
	)
	body_definition.weight_lb = 0.0
	body_definition.inventory_footprint = Vector2i(4, 4)
	body_definition.handedness = ItemDefinition.HANDEDNESS_NONE
	# The spatial inventory footprint remains the authority. Medium bodies do not
	# fit the current Belt, while a future Tiny body may fit and should then use
	# the same packed-body visibility and downing rules as the Backpack.
	body_definition.belt_allowed = true
	body_definition.backpack_allowed = true
	body_definition.tactical_visual_category = &"body"

	var result := TacticalItemInstanceState.new(
		StringName("body.%s" % unit.unit_id),
		body_definition,
		1,
		1.0,
		location_value
	)
	result.instance_kind = INSTANCE_KIND_BODY
	result.linked_unit_id = unit.unit_id
	result.display_name_override = "%s's Body" % unit.display_name
	result.weight_override_lb = unit.body_weight_lb
	result.footprint_override = unit.body_inventory_footprint()
	return result
