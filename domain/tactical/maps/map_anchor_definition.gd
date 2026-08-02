class_name MapAnchorDefinition
extends Resource

@export var anchor_id: StringName = &""
@export var position: Vector2i = Vector2i.ZERO
@export var facing: Vector2i = Vector2i(0, 1)
@export var anchor_kind: StringName = &"generic"
@export var tags: Array[StringName] = []


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if anchor_id.is_empty():
		errors.append("Map anchor has no ID.")
	if map_definition == null or not map_definition.is_inside(position) or map_definition.is_blocked(position):
		errors.append("Map anchor %s has illegal position %s." % [anchor_id, position])
	return errors
