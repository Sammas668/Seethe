class_name MissionGroundItemPlacementDefinition
extends Resource

@export var placement_id: StringName = &""
@export var instance_id: StringName = &""
@export var definition_id: StringName = &""
@export var grid_position: Vector2i = Vector2i.ZERO
@export var quantity: int = 1
@export_range(0.0, 1.0, 0.01) var condition: float = 1.0
@export var source_label: String = "Mission prop"


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if placement_id.is_empty():
		errors.append("Mission item placement has no ID.")
	if instance_id.is_empty():
		errors.append("Mission item placement %s has no instance ID." % placement_id)
	if definition_id.is_empty():
		errors.append("Mission item placement %s has no item definition." % placement_id)
	if quantity < 1:
		errors.append("Mission item placement %s has invalid quantity." % placement_id)
	if map_definition == null or not map_definition.is_inside(grid_position) or map_definition.is_blocked(grid_position):
		errors.append("Mission item placement %s has an illegal tile %s." % [placement_id, grid_position])
	return errors
