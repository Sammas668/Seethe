class_name TacticalInventoryState
extends RefCounted

const KIND_PRIMARY_HAND: StringName = TacticalItemLocationState.CONTAINER_PRIMARY_HAND
const KIND_SECONDARY_HAND: StringName = TacticalItemLocationState.CONTAINER_SECONDARY_HAND
const KIND_BELT: StringName = TacticalItemLocationState.CONTAINER_BELT
const KIND_BACKPACK: StringName = TacticalItemLocationState.CONTAINER_BACKPACK
const KIND_ARMOUR: StringName = TacticalItemLocationState.CONTAINER_ARMOUR
const KIND_WORN_UTILITY: StringName = TacticalItemLocationState.CONTAINER_WORN_UTILITY
const KIND_RAIDER_SACK: StringName = TacticalItemLocationState.CONTAINER_RAIDER_SACK

const BELT_WIDTH: int = 7
const BELT_HEIGHT: int = 2
const BACKPACK_WIDTH: int = 10
const BACKPACK_HEIGHT: int = 4
const RAIDER_SACK_WIDTH: int = 4
const RAIDER_SACK_HEIGHT: int = 3

var maximum_weight_lb: float


func _init(maximum_weight_value: float = 60.0) -> void:
	maximum_weight_lb = maxf(1.0, maximum_weight_value)


func container_width(container_kind: StringName) -> int:
	match container_kind:
		KIND_BELT:
			return BELT_WIDTH
		KIND_RAIDER_SACK:
			return RAIDER_SACK_WIDTH
		_:
			return BACKPACK_WIDTH


func container_height(container_kind: StringName) -> int:
	match container_kind:
		KIND_BELT:
			return BELT_HEIGHT
		KIND_RAIDER_SACK:
			return RAIDER_SACK_HEIGHT
		_:
			return BACKPACK_HEIGHT
