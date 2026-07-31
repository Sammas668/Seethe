class_name MovementDetectionPreview
extends RefCounted

var tile_previews: Array[MovementDetectionTilePreview] = []
var requires_roll: bool = false
var automatic_detection: bool = false
var avoid_detection_chance_percent: int = 100
var effective_detection_dc: int = 0
var stealth_bonus: int = 0
var primary_observer_id: StringName = &""
var relevant_observer_ids: Array[StringName] = []
var first_exposure_tile: Vector2i = Vector2i(-1, -1)
var has_unknown_observers: bool = false
var reason: String = ""


func has_detection_risk() -> bool:
	return not tile_previews.is_empty()


func display_percent() -> String:
	if has_unknown_observers:
		return "?"
	return "%d%%" % avoid_detection_chance_percent


func risk_tile_count() -> int:
	return tile_previews.size()


func preview_for_tile(tile: Vector2i) -> MovementDetectionTilePreview:
	for tile_preview: MovementDetectionTilePreview in tile_previews:
		if tile_preview.tile == tile:
			return tile_preview
	return null
