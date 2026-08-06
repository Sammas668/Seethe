class_name MissionCharacterPlacementDefinition
extends Resource

@export var placement_id: StringName = &""
@export var character_id: StringName = &""
@export var template_id: StringName = &""
@export var display_name: String = "Mission character"
@export var team_id: StringName = &"enemy"
@export var faction_id: StringName = &""
@export var grid_position: Vector2i = Vector2i.ZERO
@export var facing: Vector2i = Vector2i(0, 1)
@export var squad_id: StringName = &""
@export var ai_controlled: bool = true
@export var auto_pass_turn: bool = false
@export var counts_for_victory: bool = true
@export var role_tags: Array[StringName] = []
@export var patrol_path_id: StringName = &""
@export var ai_profile_override_id: StringName = &""


func has_role_tag(tag: StringName) -> bool:
	return role_tags.has(tag)


func validate_definition(map_definition: TacticalMapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if placement_id.is_empty():
		errors.append("Mission character placement has no ID.")
	if character_id.is_empty():
		errors.append("Mission character placement %s has no character ID." % placement_id)
	if template_id.is_empty():
		errors.append("Mission character placement %s has no template ID." % placement_id)
	if map_definition == null or not map_definition.is_inside(grid_position) or map_definition.is_blocked(grid_position):
		errors.append("Mission character placement %s has an illegal tile %s." % [placement_id, grid_position])
	return errors
