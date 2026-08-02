class_name TacticalItemLocationState
extends RefCounted

const LOCATION_UNIT_EQUIPMENT: StringName = &"unit_equipment"
const LOCATION_UNIT_INVENTORY: StringName = &"unit_inventory"
const LOCATION_TACTICAL_GROUND: StringName = &"tactical_ground"
const LOCATION_TACTICAL_CONTAINER: StringName = &"tactical_container"
const LOCATION_BODY_ATTACHMENT: StringName = &"body_attachment"
const LOCATION_DESTROYED: StringName = &"destroyed"

const CONTAINER_PRIMARY_HAND: StringName = &"main_hand"
const CONTAINER_SECONDARY_HAND: StringName = &"off_hand"
const CONTAINER_BELT: StringName = &"belt"
const CONTAINER_BACKPACK: StringName = &"backpack"
const CONTAINER_ARMOUR: StringName = &"armour"
const CONTAINER_WORN_UTILITY: StringName = &"worn_utility"
const CONTAINER_GROUND: StringName = &"ground"
const CONTAINER_RESTRAINT: StringName = &"restraint"
const CONTAINER_RAIDER_SACK: StringName = &"raider_sack"

var location_type: StringName
var owner_id: StringName
var container_kind: StringName
var grid_position: Vector2i
var map_position: Vector2i
var source_label: String
# A body in a Hand remains on the ground and follows the actor.
var transport_mode: StringName = &""


func _init(
		location_type_value: StringName = LOCATION_DESTROYED,
		owner_id_value: StringName = &"",
		container_kind_value: StringName = &"",
		grid_position_value: Vector2i = Vector2i.ZERO,
		map_position_value: Vector2i = Vector2i.ZERO,
		source_label_value: String = ""
) -> void:
	location_type = location_type_value
	owner_id = owner_id_value
	container_kind = container_kind_value
	grid_position = grid_position_value
	map_position = map_position_value
	source_label = source_label_value


static func unit_slot(
		unit_id: StringName,
		slot_kind: StringName
) -> TacticalItemLocationState:
	return TacticalItemLocationState.new(
		LOCATION_UNIT_EQUIPMENT,
		unit_id,
		slot_kind
	)


static func unit_hand(
		unit_id: StringName,
		hand_kind: StringName
) -> TacticalItemLocationState:
	return unit_slot(unit_id, hand_kind)


static func unit_grid(
		unit_id: StringName,
		container_kind_value: StringName,
		position: Vector2i
) -> TacticalItemLocationState:
	return TacticalItemLocationState.new(
		LOCATION_UNIT_INVENTORY,
		unit_id,
		container_kind_value,
		position
	)


static func ground(
		position: Vector2i,
		source_label_value: String = "Ground"
) -> TacticalItemLocationState:
	return TacticalItemLocationState.new(
		LOCATION_TACTICAL_GROUND,
		&"",
		CONTAINER_GROUND,
		Vector2i.ZERO,
		position,
		source_label_value
	)


static func raider_sack(
		unit_id: StringName,
		position: Vector2i = Vector2i.ZERO
) -> TacticalItemLocationState:
	return unit_grid(unit_id, CONTAINER_RAIDER_SACK, position)


func clone() -> TacticalItemLocationState:
	var result := TacticalItemLocationState.new(
		location_type,
		owner_id,
		container_kind,
		grid_position,
		map_position,
		source_label
	)
	result.transport_mode = transport_mode
	return result


func matches(other: TacticalItemLocationState) -> bool:
	if other == null:
		return false
	return (
		location_type == other.location_type
		and owner_id == other.owner_id
		and container_kind == other.container_kind
		and grid_position == other.grid_position
		and map_position == other.map_position
		and transport_mode == other.transport_mode
	)


static func dragged_body(
		unit_id: StringName,
		hand_kind: StringName,
		body_cell: Vector2i
) -> TacticalItemLocationState:
	var result := unit_hand(unit_id, hand_kind)
	result.transport_mode = &"dragging"
	result.map_position = body_cell
	return result


static func body_attachment(
		unit_id: StringName
) -> TacticalItemLocationState:
	return TacticalItemLocationState.new(
		LOCATION_BODY_ATTACHMENT,
		unit_id,
		CONTAINER_RESTRAINT
	)
