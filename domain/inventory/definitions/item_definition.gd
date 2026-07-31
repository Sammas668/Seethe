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
@export var handedness: StringName = HANDEDNESS_ONE
@export var belt_allowed: bool = true
@export var backpack_allowed: bool = true
@export var stackable: bool = false
@export var maximum_stack_size: int = 1
@export var equipment_tags: Array[StringName] = []
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


func is_two_handed() -> bool:
	return handedness == HANDEDNESS_TWO


func can_equip_in_hand() -> bool:
	return handedness in [HANDEDNESS_ONE, HANDEDNESS_TWO]


func has_tag(tag: StringName) -> bool:
	return equipment_tags.has(tag)


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

	for raw_stat_id: Variant in stat_modifiers.keys():
		var stat_id: String = String(raw_stat_id).strip_edges()
		if stat_id.is_empty():
			errors.append("Item %s has an empty stat modifier ID." % id)

	var seen_actions: Dictionary = {}
	for action_id: StringName in granted_action_ids:
		if action_id.is_empty():
			errors.append("Item %s grants an empty action ID." % id)
		elif seen_actions.has(action_id):
			errors.append("Item %s grants duplicate action %s." % [id, action_id])
		else:
			seen_actions[action_id] = true

	return errors
