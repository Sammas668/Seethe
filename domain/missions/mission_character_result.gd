class_name MissionCharacterResult
extends RefCounted

const OUTCOME_NOT_DEPLOYED: StringName = &"not_deployed"
const OUTCOME_ACTIVE: StringName = &"active"
const OUTCOME_DOWNED: StringName = &"downed"
const OUTCOME_STABILISED: StringName = &"stabilised"
const OUTCOME_DEAD: StringName = &"dead"

var character_id: StringName = &""
var was_deployed: bool = false
var survived: bool = true
var extracted: bool = false
var current_hp: int = 0
var outcome_state: StringName = OUTCOME_NOT_DEPLOYED
var xp_awarded: int = 0
var equipment_item_ids: Array[StringName] = []
var loot_item_ids: Array[StringName] = []
var injury_entries: Array[String] = []
var history_entry: String = ""


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if character_id.is_empty():
		errors.append("Mission character result has no character ID.")
	if xp_awarded < 0:
		errors.append("Mission character result awards negative XP.")
	if outcome_state not in [
		OUTCOME_NOT_DEPLOYED,
		OUTCOME_ACTIVE,
		OUTCOME_DOWNED,
		OUTCOME_STABILISED,
		OUTCOME_DEAD,
	]:
		errors.append(
			"Mission character result has unknown outcome %s." % outcome_state
		)
	if not was_deployed and outcome_state != OUTCOME_NOT_DEPLOYED:
		errors.append("A non-deployed character has a deployed outcome.")
	if was_deployed and outcome_state == OUTCOME_NOT_DEPLOYED:
		errors.append("A deployed character is marked not deployed.")
	if survived == (outcome_state == OUTCOME_DEAD):
		errors.append("Character survival flag disagrees with the outcome state.")
	if extracted and outcome_state == OUTCOME_DEAD:
		errors.append("A dead character cannot be extracted as a survivor.")
	return errors


func to_dictionary() -> Dictionary:
	var equipment_ids: Array[String] = []
	for item_id: StringName in equipment_item_ids:
		equipment_ids.append(String(item_id))
	var loot_ids: Array[String] = []
	for item_id: StringName in loot_item_ids:
		loot_ids.append(String(item_id))

	return {
		"character_id": String(character_id),
		"was_deployed": was_deployed,
		"survived": survived,
		"extracted": extracted,
		"current_hp": current_hp,
		"outcome_state": String(outcome_state),
		"xp_awarded": xp_awarded,
		"equipment_item_ids": equipment_ids,
		"loot_item_ids": loot_ids,
		"injury_entries": injury_entries.duplicate(),
		"history_entry": history_entry,
	}


static func from_dictionary(data: Dictionary) -> MissionCharacterResult:
	var result: MissionCharacterResult = MissionCharacterResult.new()
	result.character_id = StringName(data.get("character_id", ""))
	result.was_deployed = bool(data.get("was_deployed", false))
	result.survived = bool(data.get("survived", true))
	result.extracted = bool(data.get("extracted", false))
	result.current_hp = maxi(0, int(data.get("current_hp", 0)))
	var legacy_outcome: StringName = (
		OUTCOME_NOT_DEPLOYED
		if not result.was_deployed
		else (OUTCOME_ACTIVE if result.survived else OUTCOME_DEAD)
	)
	result.outcome_state = StringName(
		data.get("outcome_state", String(legacy_outcome))
	)
	result.xp_awarded = maxi(0, int(data.get("xp_awarded", 0)))

	var raw_equipment_ids: Array = data.get("equipment_item_ids", [])
	for raw_item_id: Variant in raw_equipment_ids:
		result.equipment_item_ids.append(StringName(raw_item_id))

	var raw_loot_ids: Array = data.get("loot_item_ids", [])
	for raw_item_id: Variant in raw_loot_ids:
		result.loot_item_ids.append(StringName(raw_item_id))

	var raw_injuries: Array = data.get("injury_entries", [])
	for raw_injury: Variant in raw_injuries:
		result.injury_entries.append(String(raw_injury))
	result.history_entry = String(data.get("history_entry", ""))
	return result
