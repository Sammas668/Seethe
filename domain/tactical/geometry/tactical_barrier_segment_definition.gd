class_name TacticalBarrierSegmentDefinition
extends Resource

const HEIGHT_LOW: StringName = &"low"
const HEIGHT_HIGH: StringName = &"high"
const HEIGHT_FULL: StringName = &"full"

const KIND_LOW_WALL: StringName = &"low_wall"
const KIND_HIGH_BARRICADE: StringName = &"high_barricade"
const KIND_FENCE: StringName = &"fence"
const KIND_BARS: StringName = &"bars"

@export var segment_id: StringName = &""
@export var display_name: String = "Barrier"
@export var first_tile: Vector2i = Vector2i.ZERO
@export var second_tile: Vector2i = Vector2i.RIGHT
@export var barrier_kind: StringName = KIND_LOW_WALL
@export var height_profile: StringName = HEIGHT_LOW
@export var blocks_movement: bool = false
@export var blocks_sight: bool = false
@export var blocks_line_of_effect: bool = false
@export var provides_cover: bool = true
@export var material_profile_id: StringName = &"material.wood"
@export var structure_definition_id: StringName = &""


func edge_id() -> StringName:
	return TacticalEdgeKey.make_id(first_tile, second_tile)


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if segment_id.is_empty():
		errors.append("Barrier segment has no ID.")
	if not TacticalEdgeKey.are_adjacent(first_tile, second_tile):
		errors.append("Barrier %s does not occupy one orthogonal edge." % segment_id)
	if map_definition != null:
		if not map_definition.is_inside(first_tile) or not map_definition.is_inside(second_tile):
			errors.append("Barrier %s lies outside the map." % segment_id)
	if height_profile not in [HEIGHT_LOW, HEIGHT_HIGH, HEIGHT_FULL]:
		errors.append("Barrier %s has unknown height profile %s." % [segment_id, height_profile])
	return errors
