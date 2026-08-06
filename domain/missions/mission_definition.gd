class_name MissionDefinition
extends Resource

const TYPE_RAID: StringName = &"raid"
const TYPE_ASSAULT: StringName = &"assault"
const TYPE_ASSASSINATE: StringName = &"assassinate"

@export var mission_definition_id: StringName = &""
@export var mission_instance_id: StringName = &""
@export var display_name: String = "Tactical mission"
@export_multiline var briefing_text: String = ""
@export var mission_type: StringName = TYPE_RAID
@export var map_definition: TacticalMapDefinition
@export var protagonist_character_id: StringName = &""
@export var maximum_player_deployment: int = 3
@export var player_character_ids: Array[StringName] = []
@export var character_placements: Array[MissionCharacterPlacementDefinition] = []
@export var ground_item_placements: Array[MissionGroundItemPlacementDefinition] = []
@export var primary_objectives: Array[MissionObjectiveDefinition] = []
@export var optional_objectives: Array[MissionObjectiveDefinition] = []
@export var failure_condition_ids: Array[StringName] = []
@export var loot_profile_id: StringName = &""
@export var notoriety_event_profile_id: StringName = &""
@export var visual_profile_id: StringName = &""
@export var audio_profile_id: StringName = &""
@export var result_rule_profile_id: StringName = &""
@export var reinforcement_profile_id: StringName = &""
@export var mission_round_limit: int = -1
@export var notoriety_preview_lines: Array[String] = []


func all_objectives() -> Array[MissionObjectiveDefinition]:
	var result: Array[MissionObjectiveDefinition] = []
	for objective: MissionObjectiveDefinition in primary_objectives:
		if objective != null:
			result.append(objective)
	for objective: MissionObjectiveDefinition in optional_objectives:
		if objective != null:
			result.append(objective)
	return result


func objective(objective_id: StringName) -> MissionObjectiveDefinition:
	for candidate: MissionObjectiveDefinition in all_objectives():
		if candidate.objective_id == objective_id:
			return candidate
	return null


func placement_for_character(character_id: StringName) -> MissionCharacterPlacementDefinition:
	for placement: MissionCharacterPlacementDefinition in character_placements:
		if placement != null and placement.character_id == character_id:
			return placement
	return null


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if mission_definition_id.is_empty():
		errors.append("Mission definition has no ID.")
	if mission_instance_id.is_empty():
		errors.append("Mission definition %s has no instance ID." % mission_definition_id)
	if display_name.strip_edges().is_empty():
		errors.append("Mission definition %s has no display name." % mission_definition_id)
	if mission_type not in [TYPE_RAID, TYPE_ASSAULT, TYPE_ASSASSINATE]:
		errors.append("Mission definition %s has invalid type %s." % [mission_definition_id, mission_type])
	if map_definition == null:
		errors.append("Mission definition %s has no map." % mission_definition_id)
	else:
		errors.append_array(map_definition.validate_definition())
	if primary_objectives.is_empty():
		errors.append("Mission definition %s has no primary objective." % mission_definition_id)
	var seen_objective_ids: Dictionary = {}
	for objective: MissionObjectiveDefinition in all_objectives():
		if objective == null:
			errors.append("Mission definition %s contains a missing objective." % mission_definition_id)
			continue
		if seen_objective_ids.has(objective.objective_id):
			errors.append("Mission definition %s duplicates objective %s." % [mission_definition_id, objective.objective_id])
		seen_objective_ids[objective.objective_id] = true
		errors.append_array(objective.validate_definition())
	var seen_character_ids: Dictionary = {}
	for placement: MissionCharacterPlacementDefinition in character_placements:
		if placement == null:
			errors.append("Mission definition %s contains a missing character placement." % mission_definition_id)
			continue
		if seen_character_ids.has(placement.character_id):
			errors.append("Mission definition %s places character %s twice." % [mission_definition_id, placement.character_id])
		seen_character_ids[placement.character_id] = true
		errors.append_array(placement.validate_definition(map_definition))
		if map_definition != null and placement.team_id == &"player":
			var inside_deployment: bool = false
			for zone: MapZoneDefinition in map_definition.deployment_zones:
				if (
					zone != null
					and zone.contains(placement.grid_position)
					and (zone.allowed_team_ids.is_empty() or zone.allowed_team_ids.has(&"player"))
				):
					inside_deployment = true
					break
			if not inside_deployment:
				errors.append("Player placement %s is outside an authored deployment zone." % placement.placement_id)
		if (
			map_definition != null
			and not placement.patrol_path_id.is_empty()
			and map_definition.patrol_path(placement.patrol_path_id) == null
		):
			errors.append("Character placement %s references missing patrol path %s." % [placement.placement_id, placement.patrol_path_id])
	var seen_item_ids: Dictionary = {}
	for placement: MissionGroundItemPlacementDefinition in ground_item_placements:
		if placement == null:
			errors.append("Mission definition %s contains a missing item placement." % mission_definition_id)
			continue
		if seen_item_ids.has(placement.instance_id):
			errors.append("Mission definition %s duplicates item %s." % [mission_definition_id, placement.instance_id])
		seen_item_ids[placement.instance_id] = true
		errors.append_array(placement.validate_definition(map_definition))
	if map_definition != null and map_definition.deployment_zones.is_empty():
		errors.append("Mission definition %s has no deployment zone." % mission_definition_id)
	if map_definition != null and map_definition.extraction_zones.is_empty():
		errors.append("Mission definition %s has no extraction zone." % mission_definition_id)
	for player_id: StringName in player_character_ids:
		var player_placement := placement_for_character(player_id)
		if player_placement == null or player_placement.team_id != &"player":
			errors.append("Mission definition %s lists player %s without a player placement." % [mission_definition_id, player_id])
	if not protagonist_character_id.is_empty() and not player_character_ids.has(protagonist_character_id):
		errors.append("Mission definition %s protagonist is not in the selectable player force." % mission_definition_id)
	if loot_profile_id.is_empty():
		errors.append("Mission definition %s has no loot profile." % mission_definition_id)
	if result_rule_profile_id.is_empty():
		errors.append("Mission definition %s has no result rule profile." % mission_definition_id)
	return errors
