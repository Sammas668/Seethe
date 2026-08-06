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
# Stage 5.3F career identity. Character Level, XP and all ordinary progression
# remain authoritative on this record. Only active_tier_starting_feat_ids is
# replaced by Prestige; every other earned feature remains.
var base_class_id: StringName = &""
var class_ranks: Dictionary = {}
var archetype_ranks: Dictionary = {}
var career_id: StringName = &""
var base_henchman_type_id: StringName = &""
var current_troop_type_id: StringName = &""
var troop_tier: int = 0
var completed_prestige_stage_ids: Array[StringName] = []
var active_tier_starting_feat_ids: Array[StringName] = []
var active_tier_starting_feat_parameters: Dictionary = {}
var prestige_feat_ids: Array[StringName] = []
var prestige_trait_ids: Array[StringName] = []
var prestige_ability_ids: Array[StringName] = []
var prestige_action_ids: Array[StringName] = []
var prestige_proficiency_ids: Array[StringName] = []
var prestige_role_tag_ids: Array[StringName] = []
var prestige_ability_entries: Array[String] = []
var prestige_feature_parameters: Dictionary = {}
var permanent_grants: Array[CharacterPermanentGrantState] = []
var ordinary_feat_choice_ids: Array[StringName] = []
var active_feature_upgrade_ids: Dictionary = {}
var body_transition_history: Array[StringName] = []
var active_companion_id: StringName = &""
var legacy_progression_exception: bool = false
var migration_warnings: Array[String] = []
# Stage 5.3c persistent health. Legacy characters remain implicitly at full
# health until a mission result or explicit migration initializes these fields.
var health_initialized: bool = false
var current_hp: int = 0
var nonlethal_damage: int = 0
# Recovery progress is stored as integer healing units. 1,440 units heal one
# point, allowing exact per-minute recovery without floating-point drift.
var lethal_recovery_units: int = 0
var nonlethal_recovery_units: int = 0
var ability_adjustments: Dictionary = {}
var stat_adjustments: Dictionary = {}
# Stage 3 compatibility fallback. Real equipped armour items override this.
var equipped_defence_profile_id: StringName = &""
var portrait_override_id: StringName = &""
var injury_entries: Array[String] = []
var permanent_condition_entries: Array[String] = []
var history_entries: Array[String] = []
var trait_entries: Array[String] = []
var selected_talent_ids: Array[StringName] = []
var preferred_loadout_template_id: StringName = &""
var deployment_count: int = 0
var is_dead: bool = false
var revision: int = 0


func resolved_current_hp(maximum_hp: int) -> int:
	var resolved_maximum: int = maxi(1, maximum_hp)
	if not health_initialized:
		return resolved_maximum
	return mini(resolved_maximum, current_hp)


func resolved_nonlethal_damage() -> int:
	return maxi(0, nonlethal_damage) if health_initialized else 0


func initialize_health(maximum_hp: int) -> bool:
	var resolved_maximum: int = maxi(1, maximum_hp)
	if health_initialized:
		var changed: bool = false
		if current_hp > resolved_maximum:
			current_hp = resolved_maximum
			changed = true
		if nonlethal_damage < 0:
			nonlethal_damage = 0
			changed = true
		if changed:
			revision += 1
		return changed
	health_initialized = true
	current_hp = resolved_maximum
	nonlethal_damage = 0
	lethal_recovery_units = 0
	nonlethal_recovery_units = 0
	revision += 1
	return true


func set_persistent_health(
		hp_value: int,
		nonlethal_value: int,
		maximum_hp: int
) -> void:
	health_initialized = true
	current_hp = mini(maxi(1, maximum_hp), hp_value)
	nonlethal_damage = maxi(0, nonlethal_value)
	lethal_recovery_units = 0
	nonlethal_recovery_units = 0
	revision += 1


func missing_lethal_hp(maximum_hp: int) -> int:
	return maxi(0, maxi(1, maximum_hp) - resolved_current_hp(maximum_hp))


func is_persistently_unconscious(maximum_hp: int) -> bool:
	if is_dead:
		return true
	var hp_value: int = resolved_current_hp(maximum_hp)
	return hp_value <= 0 or resolved_nonlethal_damage() >= maxi(1, hp_value)


func is_missing_or_unrecovered() -> bool:
	return injury_entries.has("Missing / Unrecovered")


func can_deploy_with_health(maximum_hp: int) -> bool:
	return (
		not is_dead
		and not is_missing_or_unrecovered()
		and not is_persistently_unconscious(maximum_hp)
	)


func health_condition_id(maximum_hp: int) -> StringName:
	if is_dead:
		return &"dead"
	var resolved_maximum: int = maxi(1, maximum_hp)
	var hp_value: int = resolved_current_hp(resolved_maximum)
	var nonlethal_value: int = resolved_nonlethal_damage()
	if hp_value <= 0 or nonlethal_value >= maxi(1, hp_value):
		return &"gravely_wounded"
	if hp_value * 2 <= resolved_maximum:
		return &"gravely_wounded"
	if hp_value < resolved_maximum or nonlethal_value > 0 or not injury_entries.is_empty():
		return &"wounded"
	return &"ready"


func apply_strategic_recovery(
		delta_minutes: int,
		maximum_hp: int,
		lethal_points_per_day: int,
		nonlethal_points_per_day: int
) -> bool:
	if delta_minutes <= 0 or is_dead or not health_initialized:
		return false
	var resolved_maximum: int = maxi(1, maximum_hp)
	var changed: bool = false
	if current_hp < resolved_maximum and lethal_points_per_day > 0:
		lethal_recovery_units += delta_minutes * lethal_points_per_day
		var lethal_healing: int = lethal_recovery_units / 1440
		if lethal_healing > 0:
			var before_hp: int = current_hp
			current_hp = mini(resolved_maximum, current_hp + lethal_healing)
			lethal_recovery_units -= (current_hp - before_hp) * 1440
			if current_hp >= resolved_maximum:
				lethal_recovery_units = 0
			changed = current_hp != before_hp
	else:
		lethal_recovery_units = 0
	if nonlethal_damage > 0 and nonlethal_points_per_day > 0:
		nonlethal_recovery_units += delta_minutes * nonlethal_points_per_day
		var nonlethal_healing: int = nonlethal_recovery_units / 1440
		if nonlethal_healing > 0:
			var before_nonlethal: int = nonlethal_damage
			nonlethal_damage = maxi(0, nonlethal_damage - nonlethal_healing)
			nonlethal_recovery_units -= (before_nonlethal - nonlethal_damage) * 1440
			if nonlethal_damage <= 0:
				nonlethal_recovery_units = 0
			changed = changed or nonlethal_damage != before_nonlethal
	else:
		nonlethal_recovery_units = 0
	if current_hp >= resolved_maximum and nonlethal_damage <= 0:
		var retained_injuries: Array[String] = []
		for injury: String in injury_entries:
			if injury not in ["Wounded", "Gravely Wounded"]:
				retained_injuries.append(injury)
		if retained_injuries.size() != injury_entries.size():
			injury_entries = retained_injuries
			changed = true
	if changed:
		revision += 1
	return changed


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


func class_rank(class_id: StringName) -> int:
	return maxi(0, int(class_ranks.get(class_id, class_ranks.get(String(class_id), 0))))


func archetype_rank(archetype_id: StringName) -> int:
	return maxi(0, int(archetype_ranks.get(archetype_id, archetype_ranks.get(String(archetype_id), 0))))


func has_permanent_grant(grant_id: StringName, source_id: StringName = &"") -> bool:
	for grant: CharacterPermanentGrantState in permanent_grants:
		if grant == null or grant.grant_id != grant_id:
			continue
		if source_id.is_empty() or grant.source_id == source_id:
			return true
	return false


func add_permanent_grant(grant: CharacterPermanentGrantState) -> bool:
	if grant == null or grant.grant_id.is_empty() or has_permanent_grant(grant.grant_id, grant.source_id):
		return false
	permanent_grants.append(grant)
	revision += 1
	return true


func troop_display_name(fallback: String = "Individual") -> String:
	if current_troop_type_id.is_empty():
		return fallback
	return String(current_troop_type_id).get_slice(".", String(current_troop_type_id).count(".")).replace("_", " ").capitalize()


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
	if nonlethal_damage < 0:
		errors.append("Persistent character %s has negative nonlethal damage." % character_id)
	if lethal_recovery_units < 0 or nonlethal_recovery_units < 0:
		errors.append("Persistent character %s has negative recovery progress." % character_id)
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
	if troop_tier < 0:
		errors.append("Persistent character %s has a negative troop Tier." % character_id)
	var seen_stages: Dictionary = {}
	for stage_id: StringName in completed_prestige_stage_ids:
		if stage_id.is_empty() or seen_stages.has(stage_id):
			errors.append("Persistent character %s has an empty or repeated Prestige stage." % character_id)
		seen_stages[stage_id] = true
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
		"base_class_id": String(base_class_id),
		"class_ranks": class_ranks.duplicate(true),
		"archetype_ranks": archetype_ranks.duplicate(true),
		"career_id": String(career_id),
		"base_henchman_type_id": String(base_henchman_type_id),
		"current_troop_type_id": String(current_troop_type_id),
		"troop_tier": troop_tier,
		"completed_prestige_stage_ids": _string_name_to_string_array(completed_prestige_stage_ids),
		"active_tier_starting_feat_ids": _string_name_to_string_array(active_tier_starting_feat_ids),
		"active_tier_starting_feat_parameters": active_tier_starting_feat_parameters.duplicate(true),
		"prestige_feat_ids": _string_name_to_string_array(prestige_feat_ids),
		"prestige_trait_ids": _string_name_to_string_array(prestige_trait_ids),
		"prestige_ability_ids": _string_name_to_string_array(prestige_ability_ids),
		"prestige_action_ids": _string_name_to_string_array(prestige_action_ids),
		"prestige_proficiency_ids": _string_name_to_string_array(prestige_proficiency_ids),
		"prestige_role_tag_ids": _string_name_to_string_array(prestige_role_tag_ids),
		"prestige_ability_entries": prestige_ability_entries.duplicate(),
		"prestige_feature_parameters": prestige_feature_parameters.duplicate(true),
		"permanent_grants": _grant_dictionaries(permanent_grants),
		"ordinary_feat_choice_ids": _string_name_to_string_array(ordinary_feat_choice_ids),
		"active_feature_upgrade_ids": active_feature_upgrade_ids.duplicate(true),
		"body_transition_history": _string_name_to_string_array(body_transition_history),
		"active_companion_id": String(active_companion_id),
		"legacy_progression_exception": legacy_progression_exception,
		"migration_warnings": migration_warnings.duplicate(),
		"health_initialized": health_initialized,
		"current_hp": current_hp,
		"nonlethal_damage": nonlethal_damage,
		"lethal_recovery_units": lethal_recovery_units,
		"nonlethal_recovery_units": nonlethal_recovery_units,
		"ability_adjustments": ability_adjustments.duplicate(true),
		"stat_adjustments": stat_adjustments.duplicate(true),
		"equipped_defence_profile_id": String(equipped_defence_profile_id),
		"portrait_override_id": String(portrait_override_id),
		"injury_entries": injury_entries.duplicate(),
		"permanent_condition_entries": permanent_condition_entries.duplicate(),
		"history_entries": history_entries.duplicate(),
		"trait_entries": trait_entries.duplicate(),
		"selected_talent_ids": _string_name_to_string_array(selected_talent_ids),
		"preferred_loadout_template_id": String(preferred_loadout_template_id),
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
	result.base_class_id = StringName(data.get("base_class_id", ""))
	result.class_ranks = (data.get("class_ranks", {}) as Dictionary).duplicate(true)
	result.archetype_ranks = (data.get("archetype_ranks", {}) as Dictionary).duplicate(true)
	result.career_id = StringName(data.get("career_id", ""))
	result.base_henchman_type_id = StringName(data.get("base_henchman_type_id", ""))
	result.current_troop_type_id = StringName(data.get("current_troop_type_id", ""))
	result.troop_tier = maxi(0, int(data.get("troop_tier", 0)))
	result.completed_prestige_stage_ids = _string_name_array(data.get("completed_prestige_stage_ids", []))
	result.active_tier_starting_feat_ids = _string_name_array(data.get("active_tier_starting_feat_ids", []))
	result.active_tier_starting_feat_parameters = (data.get("active_tier_starting_feat_parameters", {}) as Dictionary).duplicate(true)
	result.prestige_feat_ids = _string_name_array(data.get("prestige_feat_ids", []))
	result.prestige_trait_ids = _string_name_array(data.get("prestige_trait_ids", []))
	result.prestige_ability_ids = _string_name_array(data.get("prestige_ability_ids", []))
	result.prestige_action_ids = _string_name_array(data.get("prestige_action_ids", []))
	result.prestige_proficiency_ids = _string_name_array(data.get("prestige_proficiency_ids", []))
	result.prestige_role_tag_ids = _string_name_array(data.get("prestige_role_tag_ids", []))
	result.prestige_ability_entries = _string_array(data.get("prestige_ability_entries", []))
	result.prestige_feature_parameters = (data.get("prestige_feature_parameters", {}) as Dictionary).duplicate(true)
	result.permanent_grants = _grant_array(data.get("permanent_grants", []))
	result.ordinary_feat_choice_ids = _string_name_array(data.get("ordinary_feat_choice_ids", []))
	result.active_feature_upgrade_ids = (data.get("active_feature_upgrade_ids", {}) as Dictionary).duplicate(true)
	result.body_transition_history = _string_name_array(data.get("body_transition_history", []))
	result.active_companion_id = StringName(data.get("active_companion_id", ""))
	result.legacy_progression_exception = bool(data.get("legacy_progression_exception", false))
	result.migration_warnings = _string_array(data.get("migration_warnings", []))
	result.health_initialized = bool(data.get(
		"health_initialized",
		data.has("current_hp") or data.has("nonlethal_damage")
	))
	result.current_hp = int(data.get("current_hp", 0))
	result.nonlethal_damage = maxi(0, int(data.get("nonlethal_damage", 0)))
	result.lethal_recovery_units = maxi(0, int(data.get("lethal_recovery_units", 0)))
	result.nonlethal_recovery_units = maxi(0, int(data.get("nonlethal_recovery_units", 0)))
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
	result.selected_talent_ids = _string_name_array(data.get("selected_talent_ids", []))
	result.preferred_loadout_template_id = StringName(data.get("preferred_loadout_template_id", ""))
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


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for entry: Variant in value as Array:
		var parsed := StringName(entry)
		if not parsed.is_empty():
			result.append(parsed)
	return result


static func _grant_array(value: Variant) -> Array[CharacterPermanentGrantState]:
	var result: Array[CharacterPermanentGrantState] = []
	if not value is Array:
		return result
	for raw: Variant in value as Array:
		if raw is Dictionary:
			var grant := CharacterPermanentGrantState.from_dictionary(raw as Dictionary)
			if not grant.grant_id.is_empty():
				result.append(grant)
	return result


static func _grant_dictionaries(value: Array[CharacterPermanentGrantState]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for grant: CharacterPermanentGrantState in value:
		if grant != null:
			result.append(grant.to_dictionary())
	return result


static func _string_name_to_string_array(value: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for entry: StringName in value:
		result.append(String(entry))
	return result
