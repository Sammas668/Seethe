class_name PatrolPathDefinition
extends Resource

@export var patrol_path_id: StringName = &""
@export var ordered_positions: Array[Vector2i] = []
@export var loop: bool = true
@export var wait_rounds_by_node: Dictionary = {}


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if patrol_path_id.is_empty():
		errors.append("Patrol path has no ID.")
	if ordered_positions.is_empty():
		errors.append("Patrol path %s has no positions." % patrol_path_id)
	for position: Vector2i in ordered_positions:
		if map_definition == null or not map_definition.is_inside(position) or map_definition.is_blocked(position):
			errors.append("Patrol path %s contains illegal position %s." % [patrol_path_id, position])
	return errors
