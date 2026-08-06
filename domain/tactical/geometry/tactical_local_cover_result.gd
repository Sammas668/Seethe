class_name TacticalLocalCoverResult
extends RefCounted

var defended_tile: Vector2i = Vector2i(-1, -1)
var strongest_local_cover: StringName = TacticalCombatGeometryResult.COVER_NONE
var directional_cover_by_sector: Dictionary = {}
var source_feature_ids: Array[StringName] = []
var geometry_revision: int = 0
var knowledge_revision: int = 0


func category_for(direction: Vector2i) -> StringName:
	return StringName(directional_cover_by_sector.get(
		direction,
		TacticalCombatGeometryResult.COVER_NONE
	))
