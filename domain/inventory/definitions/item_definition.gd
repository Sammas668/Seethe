class_name ItemDefinition
extends Resource

const HANDEDNESS_ONE: StringName = &"one_handed"
const HANDEDNESS_TWO: StringName = &"two_handed"
const HANDEDNESS_NONE: StringName = &"not_equippable"

@export var id: StringName = &""
@export var display_name: String = "Unknown item"
@export_multiline var description: String = "Portable tactical item."
@export var weight_lb: float = 0.0
@export var inventory_footprint: Vector2i = Vector2i.ONE
@export var inventory_rotation_allowed: bool = true
@export var handedness: StringName = HANDEDNESS_ONE
@export var belt_allowed: bool = true
@export var backpack_allowed: bool = true
@export var stackable: bool = false
@export var maximum_stack_size: int = 1
# Strategic stronghold storage is a single pooled capacity. Physical objects
# consume authored Storage Space only while their authoritative location is
# Stronghold Storage. Stackable items use bundle rules rather than one point
# per individual arrow, bandage or salvage fragment.
@export var storage_space: int = 1
@export var storage_units_per_bundle: int = 1
@export var storage_space_per_bundle: int = 1
@export var equipment_tags: Array[StringName] = []
# Fixed strategic equipment containers such as Armour are separate from hands
# and spatial Belt/Backpack storage. Worn Utility is retained only as legacy
# tactical/save vocabulary and is not a player-facing strategic slot.
@export var equipment_slot_ids: Array[StringName] = []
@export var granted_action_ids: Array[StringName] = []
@export var defence_profile_id: StringName = &""
@export var stat_modifiers: Dictionary = {}
@export var tactical_visual_category: StringName = &"misc"
# Stage 4.3.2 direct-use body interactions. These fields keep medical,
# healing and restraint behaviour data-driven while the UI only sends intent.
@export var permits_first_aid: bool = false
@export var first_aid_bonus: int = 0
@export var first_aid_uses_consumed: int = 1
@export var permits_administered_healing: bool = false
@export var healing_amount: int = 0
@export var is_restraint: bool = false
# Stage 4.7 Hotfix 5: fixed Belt fixtures and narrow internal containers.
@export var fixed_inventory_fixture: bool = false
@export var internal_container_kind: StringName = &""
@export var internal_container_size: Vector2i = Vector2i.ZERO
@export var internal_allowed_instance_kinds: Array[StringName] = []
@export var internal_single_entity_only: bool = false
# Generic equipment-rule metadata used by resolved defence and proficiency.
@export var maximum_dexterity_bonus: int = 99
@export var armour_check_penalty: int = 0
@export var required_proficiency_id: StringName = &""
# Stage 5.4A strategic Shop metadata. Prices are authored in whole Gold coins.
# The starting flag exposes only the initial common catalogue; Stage 5.4C may
# add contact- and Research-based availability without changing item identity.
@export var shop_category_id: StringName = &"other"
@export var shop_buy_price_gold: int = 0
@export var shop_sell_price_gold: int = 0
@export var shop_starting_available: bool = false


func is_two_handed() -> bool:
	return handedness == HANDEDNESS_TWO


func can_equip_in_hand() -> bool:
	return handedness in [HANDEDNESS_ONE, HANDEDNESS_TWO]


func has_tag(tag: StringName) -> bool:
	return equipment_tags.has(tag)


func can_equip_in_slot(slot_id: StringName) -> bool:
	return equipment_slot_ids.has(slot_id)


func storage_space_for_quantity(quantity: int) -> int:
	if quantity <= 0:
		return 0
	if stackable:
		var bundle_size: int = maxi(1, storage_units_per_bundle)
		var bundle_count: int = ceili(float(quantity) / float(bundle_size))
		return bundle_count * maxi(0, storage_space_per_bundle)
	return maxi(0, storage_space) * quantity


func stat_modifier(stat_id: StringName) -> int:
	return int(stat_modifiers.get(String(stat_id), 0))


func validate_definition() -> Array[String]:
	var errors: Array[String] = []

	if id.is_empty():
		errors.append("Item definition has an empty ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Item %s has an empty display name." % id)
	if weight_lb < 0.0:
		errors.append("Item %s has negative weight." % id)
	if inventory_footprint.x <= 0 or inventory_footprint.y <= 0:
		errors.append("Item %s has a non-positive inventory footprint." % id)
	if handedness not in [
		HANDEDNESS_ONE,
		HANDEDNESS_TWO,
		HANDEDNESS_NONE,
	]:
		errors.append("Item %s has unknown handedness: %s." % [id, handedness])
	if first_aid_uses_consumed < 1:
		errors.append("Item %s consumes fewer than one First Aid use." % id)
	if healing_amount < 0:
		errors.append("Item %s has negative administered healing." % id)
	if fixed_inventory_fixture and not belt_allowed:
		errors.append("Fixed inventory fixture %s must be Belt-legal." % id)
	if not internal_container_kind.is_empty():
		if internal_container_size.x <= 0 or internal_container_size.y <= 0:
			errors.append("Internal container %s has an invalid size." % id)
	if maximum_dexterity_bonus < 0:
		errors.append("Item %s has a negative maximum Dexterity bonus." % id)
	if armour_check_penalty > 0:
		errors.append("Item %s has a positive armour-check penalty." % id)
	if maximum_stack_size < 1:
		errors.append("Item %s has a maximum stack size below 1." % id)
	if not stackable and maximum_stack_size != 1:
		errors.append(
			"Non-stackable item %s must have maximum_stack_size = 1." % id
		)
	if stackable and maximum_stack_size < 2:
		errors.append(
			"Stackable item %s must allow at least two items per stack." % id
		)
	if storage_space < 0:
		errors.append("Item %s has negative Storage Space." % id)
	if storage_units_per_bundle < 1:
		errors.append("Item %s has an invalid storage bundle size." % id)
	if storage_space_per_bundle < 0:
		errors.append("Item %s has negative Storage Space per bundle." % id)
	if not stackable and storage_units_per_bundle != 1:
		errors.append(
			"Non-stackable item %s must use one storage unit per bundle." % id
		)
	if shop_buy_price_gold < 0:
		errors.append("Item %s has a negative Shop purchase price." % id)
	if shop_sell_price_gold < 0:
		errors.append("Item %s has a negative Shop sale price." % id)
	if shop_starting_available and shop_buy_price_gold <= 0:
		errors.append("Starting Shop item %s has no purchase price." % id)
	if shop_buy_price_gold > 0 and shop_sell_price_gold > shop_buy_price_gold:
		errors.append("Item %s can be sold for more than its purchase price." % id)
	if shop_category_id.is_empty():
		errors.append("Item %s has an empty Shop category." % id)

	for raw_stat_id: Variant in stat_modifiers.keys():
		var stat_id: String = String(raw_stat_id).strip_edges()
		if stat_id.is_empty():
			errors.append("Item %s has an empty stat modifier ID." % id)

	var seen_slots: Dictionary = {}
	for slot_id: StringName in equipment_slot_ids:
		if slot_id.is_empty():
			errors.append("Item %s has an empty equipment-slot ID." % id)
		elif seen_slots.has(slot_id):
			errors.append("Item %s repeats equipment slot %s." % [id, slot_id])
		else:
			seen_slots[slot_id] = true

	var seen_actions: Dictionary = {}
	for action_id: StringName in granted_action_ids:
		if action_id.is_empty():
			errors.append("Item %s grants an empty action ID." % id)
		elif seen_actions.has(action_id):
			errors.append("Item %s grants duplicate action %s." % [id, action_id])
		else:
			seen_actions[action_id] = true

	return errors
