class_name TacticalItemLocationState
extends RefCounted

const LOCATION_UNIT_EQUIPMENT: StringName = &"unit_equipment"
const LOCATION_UNIT_INVENTORY: StringName = &"unit_inventory"
const LOCATION_TACTICAL_GROUND: StringName = &"tactical_ground"
const LOCATION_TACTICAL_CONTAINER: StringName = &"tactical_container"
const LOCATION_DESTROYED: StringName = &"destroyed"

const CONTAINER_PRIMARY_HAND: StringName = &"main_hand"
const CONTAINER_SECONDARY_HAND: StringName = &"off_hand"
const CONTAINER_BELT: StringName = &"belt"
const CONTAINER_BACKPACK: StringName = &"backpack"
const CONTAINER_GROUND: StringName = &"ground"

var location_type: StringName
var owner_id: StringName
var container_kind: StringName
var grid_position: Vector2i
var map_position: Vector2i
var source_label: String


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


static func unit_hand(
		unit_id: StringName,
		hand_kind: StringName
) -> TacticalItemLocationState:
	return TacticalItemLocationState.new(
		LOCATION_UNIT_EQUIPMENT,
		unit_id,
		hand_kind
	)


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


func clone() -> TacticalItemLocationState:
	return TacticalItemLocationState.new(
		location_type,
		owner_id,
		container_kind,
		grid_position,
		map_position,
		source_label
	)


func matches(other: TacticalItemLocationState) -> bool:
	if other == null:
		return false
	return (
		location_type == other.location_type
		and owner_id == other.owner_id
		and container_kind == other.container_kind
		and grid_position == other.grid_position
		and map_position == other.map_position
	)
