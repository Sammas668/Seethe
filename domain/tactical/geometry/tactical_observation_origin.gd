class_name TacticalObservationOrigin
extends RefCounted

const KIND_CENTRE: StringName = &"centre"
const KIND_OPENING_PEEK: StringName = &"opening_peek"
const KIND_CORNER_PEEK: StringName = &"corner_peek"

var origin_kind: StringName = KIND_CENTRE
var origin_tile: Vector2i = Vector2i.ZERO
var world_position: Vector2 = Vector2.ZERO
var source_edge_id: StringName = &""
var uses_automatic_peek: bool = false
var direction: Vector2i = Vector2i.ZERO


static func centre(tile: Vector2i) -> TacticalObservationOrigin:
	var result := TacticalObservationOrigin.new()
	result.origin_tile = tile
	result.world_position = Vector2(tile) + Vector2(0.5, 0.5)
	return result
