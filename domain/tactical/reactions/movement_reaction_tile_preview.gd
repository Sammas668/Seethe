class_name MovementReactionTilePreview
extends RefCounted

var tile: Vector2i = Vector2i(-1, -1)
var reaction_kind: StringName = &""
var hit_chance_percent: int = 0
var exact_chance_known: bool = true
var reaction_count: int = 1
var source_unit_ids: Array[StringName] = []
var path_index: int = -1


func display_percent() -> String:
	return "%d%%" % hit_chance_percent if exact_chance_known else "?"
