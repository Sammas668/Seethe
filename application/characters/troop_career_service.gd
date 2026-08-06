class_name TroopCareerService
extends RefCounted

var _catalogue: ContentCatalogue


func configure(catalogue: ContentCatalogue) -> void:
	_catalogue = catalogue


func career_for_character(character: PersistentCharacterState) -> TroopCareerDefinition:
	if character == null or _catalogue == null or character.career_id.is_empty():
		return null
	return _catalogue.troop_career(character.career_id)


func stages_for_character(character: PersistentCharacterState) -> Array[TroopPrestigeStageDefinition]:
	var result: Array[TroopPrestigeStageDefinition] = []
	var career: TroopCareerDefinition = career_for_character(character)
	if career == null:
		return result
	for stage_id: StringName in career.stage_ids:
		var stage: TroopPrestigeStageDefinition = _catalogue.prestige_stage(stage_id)
		if stage != null:
			result.append(stage)
	return result


func next_stage(character: PersistentCharacterState) -> TroopPrestigeStageDefinition:
	var stages: Array[TroopPrestigeStageDefinition] = stages_for_character(character)
	var index: int = character.completed_prestige_stage_ids.size() if character != null else 0
	return stages[index] if index >= 0 and index < stages.size() else null


func is_next_stage(character: PersistentCharacterState, stage_id: StringName) -> bool:
	var next: TroopPrestigeStageDefinition = next_stage(character)
	return next != null and next.stage_id == stage_id


func stage_history(character: PersistentCharacterState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if character == null:
		return result
	for stage: TroopPrestigeStageDefinition in stages_for_character(character):
		result.append({
			"stage": stage,
			"completed": character.completed_prestige_stage_ids.has(stage.stage_id),
			"current": character.troop_tier == stage.troop_tier,
			"next": is_next_stage(character, stage.stage_id),
		})
	return result
