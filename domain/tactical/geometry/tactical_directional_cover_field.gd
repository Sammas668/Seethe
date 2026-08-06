class_name TacticalDirectionalCoverField
extends RefCounted

var defended_tile: Vector2i = Vector2i(-1, -1)
var categories_by_tile: Dictionary = {}
var geometry_revision: int = 0
var knowledge_revision: int = 0
var strongest_local_cover: StringName = TacticalCombatGeometryResult.COVER_NONE
var directional_cover_by_sector: Dictionary = {}


func category_at(tile: Vector2i) -> StringName:
	return StringName(categories_by_tile.get(
		tile,
		TacticalCombatGeometryResult.COVER_NONE
	))


func is_empty() -> bool:
	return categories_by_tile.is_empty()
