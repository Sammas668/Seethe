class_name MovementReactionPreview
extends RefCounted

var unit_id: StringName = &""
var tile_previews: Array[MovementReactionTilePreview] = []
var candidate_summaries: Array[Dictionary] = []
var query_count: int = 0


func has_reaction_risk() -> bool:
	return not tile_previews.is_empty()


func preview_for_tile(tile: Vector2i) -> MovementReactionTilePreview:
	for preview: MovementReactionTilePreview in tile_previews:
		if preview.tile == tile:
			return preview
	return null


func highest_hit_chance() -> int:
	var result: int = 0
	for preview: MovementReactionTilePreview in tile_previews:
		if preview.exact_chance_known:
			result = maxi(result, preview.hit_chance_percent)
	return result
