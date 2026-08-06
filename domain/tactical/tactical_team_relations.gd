class_name TacticalTeamRelations
extends RefCounted

const RELATION_ALLIED: StringName = &"allied"
const RELATION_HOSTILE: StringName = &"hostile"
const RELATION_NEUTRAL: StringName = &"neutral"


static func relationship(
		source_team_id: StringName,
		target_team_id: StringName
) -> StringName:
	if source_team_id.is_empty() or target_team_id.is_empty():
		return RELATION_NEUTRAL
	if source_team_id == target_team_id:
		return RELATION_ALLIED
	if (
		(source_team_id == &"player" and target_team_id == &"enemy")
		or (source_team_id == &"enemy" and target_team_id == &"player")
	):
		return RELATION_HOSTILE
	return RELATION_NEUTRAL


static func are_hostile(
		source_team_id: StringName,
		target_team_id: StringName
) -> bool:
	return relationship(source_team_id, target_team_id) == RELATION_HOSTILE


static func are_allied(
		source_team_id: StringName,
		target_team_id: StringName
) -> bool:
	return relationship(source_team_id, target_team_id) == RELATION_ALLIED
