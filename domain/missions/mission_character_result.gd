class_name MissionCharacterResult
extends RefCounted

const OUTCOME_NOT_DEPLOYED: StringName = &"not_deployed"
const OUTCOME_ACTIVE: StringName = &"active"
const OUTCOME_DOWNED: StringName = &"downed"
const OUTCOME_STABILISED: StringName = &"stabilised"
const OUTCOME_DEAD: StringName = &"dead"

# Stage 4.3.3 explicit extraction outcomes. Legacy values remain valid for
# Stage 3 callers and save compatibility.
const OUTCOME_EXTRACTED_READY: StringName = &"extracted_ready"
const OUTCOME_EXTRACTED_WOUNDED: StringName = &"extracted_wounded"
const OUTCOME_EXTRACTED_CRITICAL: StringName = &"extracted_critical"
const OUTCOME_EXTRACTED_DEAD: StringName = &"extracted_dead"
const OUTCOME_DEAD_UNRECOVERED: StringName = &"dead_unrecovered"
const OUTCOME_ALIVE_UNRECOVERED: StringName = &"alive_unrecovered"
const OUTCOME_CAPTURED_ENEMY: StringName = &"captured_enemy"
const OUTCOME_TEMPORARY_UNIT_REMOVED: StringName = &"temporary_unit_removed"

var character_id: StringName = &""
var was_deployed: bool = false
var survived: bool = true
var extracted: bool = false
var body_recovered: bool = false
var captured: bool = false
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
	if outcome_state not in _known_outcomes():
		errors.append(
			"Mission character result has unknown outcome %s." % outcome_state
		)
	if not was_deployed and outcome_state != OUTCOME_NOT_DEPLOYED:
		errors.append("A non-deployed character has a deployed outcome.")
	if was_deployed and outcome_state == OUTCOME_NOT_DEPLOYED:
		errors.append("A deployed character is marked not deployed.")
	if is_dead_outcome() and survived:
		errors.append("A dead mission outcome cannot be marked survived.")
	if (
		not is_dead_outcome()
		and outcome_state not in [OUTCOME_NOT_DEPLOYED, OUTCOME_TEMPORARY_UNIT_REMOVED]
		and not survived
	):
		errors.append("A living mission outcome must be marked survived.")
	if body_recovered and not extracted:
		errors.append("A recovered body must be physically extracted.")
	if extracted and is_dead_outcome() and not body_recovered:
		errors.append("A dead extracted character must be recorded as a recovered body.")
	if captured and outcome_state != OUTCOME_CAPTURED_ENEMY:
		errors.append("Only a captured-enemy outcome may be marked captured.")
	return errors


func is_dead_outcome() -> bool:
	return outcome_state in [
		OUTCOME_DEAD,
		OUTCOME_EXTRACTED_DEAD,
		OUTCOME_DEAD_UNRECOVERED,
	]


static func _known_outcomes() -> Array[StringName]:
	return [
		OUTCOME_NOT_DEPLOYED,
		OUTCOME_ACTIVE,
		OUTCOME_DOWNED,
		OUTCOME_STABILISED,
		OUTCOME_DEAD,
		OUTCOME_EXTRACTED_READY,
		OUTCOME_EXTRACTED_WOUNDED,
		OUTCOME_EXTRACTED_CRITICAL,
		OUTCOME_EXTRACTED_DEAD,
		OUTCOME_DEAD_UNRECOVERED,
		OUTCOME_ALIVE_UNRECOVERED,
		OUTCOME_CAPTURED_ENEMY,
		OUTCOME_TEMPORARY_UNIT_REMOVED,
	]


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
		"body_recovered": body_recovered,
		"captured": captured,
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
	result.body_recovered = bool(data.get("body_recovered", false))
	result.captured = bool(data.get("captured", false))
	result.current_hp = int(data.get("current_hp", 0))
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


static func outcome_display_name(outcome: StringName) -> String:
	match outcome:
		OUTCOME_NOT_DEPLOYED:
			return "Not deployed"
		OUTCOME_ACTIVE, OUTCOME_EXTRACTED_READY:
			return "Returned safely"
		OUTCOME_DOWNED, OUTCOME_EXTRACTED_WOUNDED:
			return "Wounded"
		OUTCOME_STABILISED, OUTCOME_EXTRACTED_CRITICAL:
			return "Critical recovery"
		OUTCOME_DEAD, OUTCOME_EXTRACTED_DEAD:
			return "Killed — body recovered"
		OUTCOME_DEAD_UNRECOVERED:
			return "Killed — body unrecovered"
		OUTCOME_ALIVE_UNRECOVERED:
			return "Missing / abandoned"
		OUTCOME_CAPTURED_ENEMY:
			return "Captured enemy"
		OUTCOME_TEMPORARY_UNIT_REMOVED:
			return "Temporary unit removed"
	return String(outcome).capitalize()
