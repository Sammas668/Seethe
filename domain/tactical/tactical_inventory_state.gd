class_name TacticalInventoryState
extends RefCounted

const KIND_PRIMARY_HAND: StringName = TacticalItemLocationState.CONTAINER_PRIMARY_HAND
const KIND_SECONDARY_HAND: StringName = TacticalItemLocationState.CONTAINER_SECONDARY_HAND
const KIND_BELT: StringName = TacticalItemLocationState.CONTAINER_BELT
const KIND_BACKPACK: StringName = TacticalItemLocationState.CONTAINER_BACKPACK

const BELT_WIDTH: int = 5
const BELT_HEIGHT: int = 2
const BACKPACK_WIDTH: int = 10
const BACKPACK_HEIGHT: int = 4

var maximum_weight_lb: float


func _init(maximum_weight_value: float = 60.0) -> void:
	maximum_weight_lb = maxf(1.0, maximum_weight_value)


func container_width(container_kind: StringName) -> int:
	return BELT_WIDTH if container_kind == KIND_BELT else BACKPACK_WIDTH


func container_height(container_kind: StringName) -> int:
	return BELT_HEIGHT if container_kind == KIND_BELT else BACKPACK_HEIGHT
