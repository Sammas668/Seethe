class_name CharacterRosterState
extends RefCounted

var characters_by_id: Dictionary = {}
var save_version: int = 3
var revision: int = 0
var applied_result_ids: Dictionary = {}


func add_character(character: PersistentCharacterState) -> bool:
	if character == null or character.character_id.is_empty():
		return false
	if characters_by_id.has(character.character_id):
		return false
	characters_by_id[character.character_id] = character
	revision += 1
	return true


func get_character(character_id: StringName) -> PersistentCharacterState:
	return characters_by_id.get(character_id) as PersistentCharacterState


func get_characters() -> Array[PersistentCharacterState]:
	var result: Array[PersistentCharacterState] = []
	for value: Variant in characters_by_id.values():
		var character: PersistentCharacterState = value as PersistentCharacterState
		if character != null:
			result.append(character)
	result.sort_custom(
		func(a: PersistentCharacterState, b: PersistentCharacterState) -> bool:
			return String(a.character_id) < String(b.character_id)
	)
	return result


func characters_for_team(team_id: StringName) -> Array[PersistentCharacterState]:
	var result: Array[PersistentCharacterState] = []
	for character: PersistentCharacterState in get_characters():
		if character.team_id == team_id and not character.is_dead:
			result.append(character)
	return result


func characters_for_role(role: StringName) -> Array[PersistentCharacterState]:
	var result: Array[PersistentCharacterState] = []
	for character: PersistentCharacterState in get_characters():
		if character.roster_role == role and not character.is_dead:
			result.append(character)
	return result


func has_applied_result(result_id: StringName) -> bool:
	return not result_id.is_empty() and applied_result_ids.has(result_id)


func mark_result_applied(result_id: StringName) -> bool:
	if result_id.is_empty() or applied_result_ids.has(result_id):
		return false
	applied_result_ids[result_id] = true
	revision += 1
	return true


func restore_from_dictionary(data: Dictionary) -> void:
	var restored: CharacterRosterState = CharacterRosterState.from_dictionary(data)
	characters_by_id = restored.characters_by_id
	save_version = restored.save_version
	revision = restored.revision
	applied_result_ids = restored.applied_result_ids


func to_dictionary() -> Dictionary:
	var serialized_characters: Array[Dictionary] = []
	for character: PersistentCharacterState in get_characters():
		if character.persistence_scope == PersistentCharacterState.PERSISTENCE_MISSION:
			continue
		serialized_characters.append(character.to_dictionary())
	var serialized_result_ids: Array[String] = []
	for key: Variant in applied_result_ids.keys():
		serialized_result_ids.append(String(key))
	serialized_result_ids.sort()
	return {
		"save_version": save_version,
		"revision": revision,
		"characters": serialized_characters,
		"applied_result_ids": serialized_result_ids,
	}


static func from_dictionary(data: Dictionary) -> CharacterRosterState:
	var roster: CharacterRosterState = CharacterRosterState.new()
	roster.save_version = maxi(3, int(data.get("save_version", 3)))
	roster.revision = maxi(0, int(data.get("revision", 0)))
	var raw_result_ids: Array = data.get("applied_result_ids", [])
	for raw_result_id: Variant in raw_result_ids:
		var result_id: StringName = StringName(raw_result_id)
		if not result_id.is_empty():
			roster.applied_result_ids[result_id] = true
	var raw_characters: Array = data.get("characters", [])
	for raw_character: Variant in raw_characters:
		if not raw_character is Dictionary:
			continue
		var character: PersistentCharacterState = (
			PersistentCharacterState.from_dictionary(raw_character as Dictionary)
		)
		if not character.character_id.is_empty():
			roster.characters_by_id[character.character_id] = character
	return roster
