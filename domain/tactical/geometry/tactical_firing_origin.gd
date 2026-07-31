class_name TacticalFiringOrigin
extends RefCounted

const KIND_CENTRE: StringName = &"centre"
const KIND_OPENING_LEAN: StringName = &"opening_lean"
const KIND_CORNER_LEAN: StringName = &"corner_lean"

var origin_kind: StringName = KIND_CENTRE
var world_position: Vector2 = Vector2.ZERO
var source_edge_id: StringName = &""
var uses_automatic_lean: bool = false
var direction: Vector2i = Vector2i.ZERO


static func centre(tile: Vector2i) -> TacticalFiringOrigin:
	var result := TacticalFiringOrigin.new()
	result.world_position = Vector2(tile) + Vector2(0.5, 0.5)
	return result
