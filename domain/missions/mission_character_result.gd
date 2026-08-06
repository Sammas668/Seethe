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
var nonlethal_damage: int = 0
var outcome_state: StringName = OUTCOME_NOT_DEPLOYED
var xp_awarded: int = 0
# Stage 5.3G immutable per-character mission record. These values are derived
# before campaign commitment and survive pending-recovery save/load so the
# mission summary and permanent history cannot disagree about contribution.
var mission_statistics: Dictionary = {}
var completed_objective_ids: Array[StringName] = []
var failed_objective_ids: Array[StringName] = []
var xp_award_breakdown: Array[String] = []
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
	if nonlethal_damage < 0:
		errors.append("Mission character result has negative nonlethal damage.")
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
	for raw_stat_name: Variant in mission_statistics.keys():
		var stat_value: Variant = mission_statistics.get(raw_stat_name)
		if not stat_value is int or int(stat_value) < 0:
			errors.append(
				"Character %s mission statistic %s must be a non-negative integer."
				% [character_id, String(raw_stat_name)]
			)
	_validate_unique_string_names(completed_objective_ids, "completed objective", errors)
	_validate_unique_string_names(failed_objective_ids, "failed objective", errors)
	for objective_id: StringName in completed_objective_ids:
		if failed_objective_ids.has(objective_id):
			errors.append(
				"Character %s lists objective %s as both completed and failed."
				% [character_id, objective_id]
			)
	if xp_awarded > 0 and xp_award_breakdown.is_empty():
		errors.append(
			"Character %s has mission XP without an award breakdown." % character_id
		)
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
		"nonlethal_damage": nonlethal_damage,
		"outcome_state": String(outcome_state),
		"xp_awarded": xp_awarded,
		"mission_statistics": mission_statistics.duplicate(true),
		"completed_objective_ids": _string_name_to_string_array(completed_objective_ids),
		"failed_objective_ids": _string_name_to_string_array(failed_objective_ids),
		"xp_award_breakdown": xp_award_breakdown.duplicate(),
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
	result.nonlethal_damage = maxi(0, int(data.get("nonlethal_damage", 0)))
	var legacy_outcome: StringName = (
		OUTCOME_NOT_DEPLOYED
		if not result.was_deployed
		else (OUTCOME_ACTIVE if result.survived else OUTCOME_DEAD)
	)
	result.outcome_state = StringName(
		data.get("outcome_state", String(legacy_outcome))
	)
	result.xp_awarded = maxi(0, int(data.get("xp_awarded", 0)))
	var raw_statistics: Variant = data.get("mission_statistics", {})
	if raw_statistics is Dictionary:
		result.mission_statistics = (raw_statistics as Dictionary).duplicate(true)
	result.completed_objective_ids = _string_name_array(
		data.get("completed_objective_ids", [])
	)
	result.failed_objective_ids = _string_name_array(
		data.get("failed_objective_ids", [])
	)
	for raw_line: Variant in data.get("xp_award_breakdown", []):
		var line: String = String(raw_line).strip_edges()
		if not line.is_empty():
			result.xp_award_breakdown.append(line)

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


func statistic(stat_id: StringName) -> int:
	return maxi(0, int(mission_statistics.get(stat_id, mission_statistics.get(String(stat_id), 0))))


static func _string_name_to_string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for raw_value: Variant in value as Array:
			var parsed := StringName(raw_value)
			if not parsed.is_empty() and not result.has(parsed):
				result.append(parsed)
	return result


static func _validate_unique_string_names(
		values: Array[StringName],
		label: String,
		errors: Array[String]
) -> void:
	var seen: Dictionary = {}
	for value: StringName in values:
		if value.is_empty():
			errors.append("Mission character result contains an empty %s ID." % label)
		elif seen.has(value):
			errors.append("Mission character result duplicates %s %s." % [label, value])
		else:
			seen[value] = true


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
