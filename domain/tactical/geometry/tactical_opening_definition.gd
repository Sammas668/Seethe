class_name TacticalOpeningDefinition
extends Resource

const KIND_DOOR: StringName = &"door"
const KIND_WINDOW: StringName = &"window"
const KIND_BARRED_OPENING: StringName = &"barred_opening"

const STATE_OPEN: StringName = &"open"
const STATE_CLOSED: StringName = &"closed"
const STATE_LOCKED: StringName = &"locked"
const STATE_BARRED: StringName = &"barred"
const STATE_JAMMED: StringName = &"jammed"
const STATE_DAMAGED: StringName = &"damaged"
const STATE_BROKEN: StringName = &"broken"
const STATE_DESTROYED: StringName = &"destroyed"

@export var opening_id: StringName = &""
@export var display_name: String = "Opening"
@export var first_tile: Vector2i = Vector2i.ZERO
@export var second_tile: Vector2i = Vector2i.RIGHT
@export var opening_kind: StringName = KIND_DOOR
@export var initial_state_id: StringName = STATE_CLOSED
@export var material_profile_id: StringName = &"material.wood"
@export var operation_cost_feet: int = 5
@export var noise_radius_tiles: int = 3
@export var lock_dc: int = 10
@export var required_key_definition_id: StringName = &""
@export var maximum_hp: int = 12
@export var hardness: int = 3
@export var armour_class: int = 5
@export var salvage_item_definition_id: StringName = &"item.broken_timber"
@export var clear_glass: bool = false


func edge_id() -> StringName:
	return TacticalEdgeKey.make_id(first_tile, second_tile)


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if opening_id.is_empty():
		errors.append("Opening has no ID.")
	if not TacticalEdgeKey.are_adjacent(first_tile, second_tile):
		errors.append("Opening %s does not occupy one orthogonal edge." % opening_id)
	if map_definition != null:
		if not map_definition.is_inside(first_tile) or not map_definition.is_inside(second_tile):
			errors.append("Opening %s lies outside the map." % opening_id)
	if opening_kind not in [KIND_DOOR, KIND_WINDOW, KIND_BARRED_OPENING]:
		errors.append("Opening %s has unknown kind %s." % [opening_id, opening_kind])
	if initial_state_id not in [
		STATE_OPEN,
		STATE_CLOSED,
		STATE_LOCKED,
		STATE_BARRED,
		STATE_JAMMED,
		STATE_DAMAGED,
		STATE_BROKEN,
		STATE_DESTROYED,
	]:
		errors.append("Opening %s has unknown initial state %s." % [opening_id, initial_state_id])
	if operation_cost_feet < 0:
		errors.append("Opening %s has negative operation cost." % opening_id)
	if maximum_hp < 1:
		errors.append("Opening %s has non-positive HP." % opening_id)
	if hardness < 0:
		errors.append("Opening %s has negative Hardness." % opening_id)
	return errors
