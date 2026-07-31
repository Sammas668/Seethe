class_name TacticalStructureDefinition
extends Resource

const GEOMETRY_TILE: StringName = &"tile"
const GEOMETRY_EDGE: StringName = &"edge"

const STATE_INTACT: StringName = &"intact"
const STATE_DAMAGED: StringName = &"damaged"
const STATE_BREACHED: StringName = &"breached"
const STATE_DESTROYED: StringName = &"destroyed"
const STATE_CLEARED: StringName = &"cleared"

@export var definition_id: StringName = &""
@export var structure_id: StringName = &""
@export var display_name: String = "Structure"
@export var geometry_kind: StringName = GEOMETRY_EDGE
@export var tile_coordinates: Array[Vector2i] = []
@export var first_tile: Vector2i = Vector2i.ZERO
@export var second_tile: Vector2i = Vector2i.RIGHT
@export var height_profile: StringName = TacticalBarrierSegmentDefinition.HEIGHT_HIGH
@export var blocks_movement_intact: bool = true
@export var blocks_sight_intact: bool = false
@export var blocks_line_of_effect_intact: bool = false
@export var armour_class: int = 5
@export var hardness: int = 3
@export var maximum_hp: int = 15
@export var damaged_threshold_hp: int = 10
@export var breached_threshold_hp: int = 4
@export var rubble_difficult_terrain: bool = true
@export var salvage_item_definition_id: StringName = &"item.broken_timber"
@export var salvage_quantity: int = 1
@export var material_profile_id: StringName = &"material.wood"


func edge_id() -> StringName:
	return TacticalEdgeKey.make_id(first_tile, second_tile)


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if definition_id.is_empty():
		errors.append("Structure definition has no definition ID.")
	if structure_id.is_empty():
		errors.append("Structure definition %s has no instance ID." % definition_id)
	if geometry_kind == GEOMETRY_EDGE:
		if not TacticalEdgeKey.are_adjacent(first_tile, second_tile):
			errors.append("Structure %s does not occupy one orthogonal edge." % structure_id)
		elif map_definition != null and (
			not map_definition.is_inside(first_tile)
			or not map_definition.is_inside(second_tile)
		):
			errors.append("Structure %s lies outside the map." % structure_id)
	elif geometry_kind == GEOMETRY_TILE:
		if tile_coordinates.is_empty():
			errors.append("Tile structure %s has no occupied tiles." % structure_id)
		if map_definition != null:
			for tile: Vector2i in tile_coordinates:
				if not map_definition.is_inside(tile):
					errors.append("Structure %s has an out-of-map tile %s." % [structure_id, tile])
	else:
		errors.append("Structure %s has unknown geometry kind %s." % [structure_id, geometry_kind])
	if maximum_hp < 1:
		errors.append("Structure %s has non-positive HP." % structure_id)
	if hardness < 0:
		errors.append("Structure %s has negative Hardness." % structure_id)
	if breached_threshold_hp < 0 or damaged_threshold_hp < breached_threshold_hp:
		errors.append("Structure %s has invalid integrity thresholds." % structure_id)
	if salvage_quantity < 0:
		errors.append("Structure %s has negative salvage quantity." % structure_id)
	return errors
