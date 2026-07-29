class_name PersistentCharacterState
extends RefCounted

const ROLE_PLAYER: StringName = &"player"
const ROLE_ENEMY: StringName = &"enemy"
const ROLE_NEUTRAL: StringName = &"neutral"

const PERSISTENCE_CAMPAIGN: StringName = &"campaign"
const PERSISTENCE_REGION: StringName = &"region"
const PERSISTENCE_MISSION: StringName = &"mission"

var character_id: StringName = &""
var template_id: StringName = &""
var display_name: String = "Unnamed Character"
var faction_id: StringName = &""
var team_id: StringName = &"neutral"
var roster_role: StringName = ROLE_NEUTRAL
var persistence_scope: StringName = PERSISTENCE_MISSION

var xp: int = 0
var level_adjustment: int = 0
var ability_adjustments: Dictionary = {}
var stat_adjustments: Dictionary = {}
# Stage 3 compatibility fallback. Real equipped armour items override this.
var equipped_defence_profile_id: StringName = &""
var portrait_override_id: StringName = &""
var injury_entries: Array[String] = []
var permanent_condition_entries: Array[String] = []
var history_entries: Array[String] = []
var trait_entries: Array[String] = []
var deployment_count: int = 0
var is_dead: bool = false
var revision: int = 0


func resolved_level(template: CharacterTemplateDefinition) -> int:
	var template_level := template.base_level if template != null else 1
	return maxi(1, template_level + level_adjustment)


func effective_defence_profile_id(
		template: CharacterTemplateDefinition
) -> StringName:
	if not equipped_defence_profile_id.is_empty():
		return equipped_defence_profile_id
	return template.default_defence_profile_id if template != null else &""


func effective_portrait_id(
		template: CharacterTemplateDefinition
) -> StringName:
	if not portrait_override_id.is_empty():
		return portrait_override_id
	return template.portrait_id if template != null else &""


func set_portrait_override_id(value: StringName) -> void:
	if portrait_override_id == value:
		return
	portrait_override_id = value
	revision += 1


func award_xp(amount: int) -> int:
	if amount <= 0 or is_dead:
		return xp
	xp += amount
	revision += 1
	return xp


func set_level_adjustment(value: int) -> void:
	var next_value := maxi(0, value)
	if level_adjustment == next_value:
		return
	level_adjustment = next_value
	revision += 1


func add_injury(entry: String, stat_changes: Dictionary = {}) -> void:
	var clean_entry := entry.strip_edges()
	if clean_entry.is_empty():
		return
	injury_entries.append(clean_entry)
	for key: Variant in stat_changes.keys():
		var stat_id := String(key)
		stat_adjustments[stat_id] = (
			int(stat_adjustments.get(stat_id, 0))
			+ int(stat_changes[key])
		)
	revision += 1


func add_history(entry: String) -> void:
	var clean_entry := entry.strip_edges()
	if clean_entry.is_empty():
		return
	history_entries.append(clean_entry)
	revision += 1


func validate_state(
		template: CharacterTemplateDefinition = null
) -> Array[String]:
	var errors: Array[String] = []
	if character_id.is_empty():
		errors.append("Persistent character has an empty ID.")
	if template_id.is_empty():
		errors.append("Persistent character %s has no template ID." % character_id)
	if display_name.strip_edges().is_empty():
		errors.append("Persistent character %s has an empty name." % character_id)
	if roster_role not in [ROLE_PLAYER, ROLE_ENEMY, ROLE_NEUTRAL]:
		errors.append(
			"Persistent character %s has unknown roster role %s."
			% [character_id, roster_role]
		)
	if persistence_scope not in [
		PERSISTENCE_CAMPAIGN,
		PERSISTENCE_REGION,
		PERSISTENCE_MISSION,
	]:
		errors.append(
			"Persistent character %s has unknown persistence scope %s."
			% [character_id, persistence_scope]
		)
	if template != null and template.id != template_id:
		errors.append(
			"Persistent character %s was validated against the wrong template."
			% character_id
		)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"character_id": String(character_id),
		"template_id": String(template_id),
		"display_name": display_name,
		"faction_id": String(faction_id),
		"team_id": String(team_id),
		"roster_role": String(roster_role),
		"persistence_scope": String(persistence_scope),
		"xp": xp,
		"level_adjustment": level_adjustment,
		"ability_adjustments": ability_adjustments.duplicate(true),
		"stat_adjustments": stat_adjustments.duplicate(true),
		"equipped_defence_profile_id": String(equipped_defence_profile_id),
		"portrait_override_id": String(portrait_override_id),
		"injury_entries": injury_entries.duplicate(),
		"permanent_condition_entries": permanent_condition_entries.duplicate(),
		"history_entries": history_entries.duplicate(),
		"trait_entries": trait_entries.duplicate(),
		"deployment_count": deployment_count,
		"is_dead": is_dead,
		"revision": revision,
	}


static func from_dictionary(data: Dictionary) -> PersistentCharacterState:
	var result := PersistentCharacterState.new()
	result.character_id = StringName(data.get("character_id", ""))
	result.template_id = StringName(data.get("template_id", ""))
	result.display_name = String(data.get("display_name", "Unnamed Character"))
	result.faction_id = StringName(data.get("faction_id", ""))
	result.team_id = StringName(data.get("team_id", "neutral"))
	result.roster_role = StringName(data.get("roster_role", "neutral"))
	result.persistence_scope = StringName(
		data.get("persistence_scope", "mission")
	)
	result.xp = maxi(0, int(data.get("xp", 0)))
	result.level_adjustment = int(data.get("level_adjustment", 0))
	result.ability_adjustments = (
		data.get("ability_adjustments", {}) as Dictionary
	).duplicate(true)
	result.stat_adjustments = (
		data.get("stat_adjustments", {}) as Dictionary
	).duplicate(true)
	result.equipped_defence_profile_id = StringName(
		data.get("equipped_defence_profile_id", "")
	)
	result.portrait_override_id = StringName(
		data.get("portrait_override_id", "")
	)
	if result.portrait_override_id.is_empty():
		result.portrait_override_id = _migrate_legacy_portrait_path(
			String(data.get("portrait_override_path", ""))
		)


	result.injury_entries = _string_array(data.get("injury_entries", []))
	result.permanent_condition_entries = _string_array(
		data.get("permanent_condition_entries", [])
	)
	result.history_entries = _string_array(data.get("history_entries", []))
	result.trait_entries = _string_array(data.get("trait_entries", []))
	result.deployment_count = maxi(0, int(data.get("deployment_count", 0)))
	result.is_dead = bool(data.get("is_dead", false))
	result.revision = maxi(0, int(data.get("revision", 0)))
	return result


static func _migrate_legacy_portrait_path(path: String) -> StringName:
	var clean_path: String = path.strip_edges()
	if clean_path.ends_with("/hakon_rusk.png"):
		return &"portrait.hakon_rusk"
	return &""


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value as Array
	for entry: Variant in values:
		result.append(String(entry))
	return result
