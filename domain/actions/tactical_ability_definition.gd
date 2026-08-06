class_name TacticalAbilityDefinition
extends ActionDefinition

const PROFILE_HEAL: StringName = &"ability.heal"
const PROFILE_SAVE_CONDITION: StringName = &"ability.save_condition"
const PROFILE_NONLETHAL_SAVE_DAMAGE: StringName = &"ability.nonlethal_save_damage"
const PROFILE_APPLY_BONUS: StringName = &"ability.apply_bonus"
const PROFILE_DETECT_POISON: StringName = &"ability.detect_poison"
const PROFILE_LIGHT: StringName = &"ability.light"

const TARGET_SELF: StringName = &"target.self"
const TARGET_TOUCH_CREATURE: StringName = &"target.touch_creature"
const TARGET_SINGLE_CREATURE: StringName = &"target.single_creature"
const TARGET_SINGLE_LIVING: StringName = &"target.single_living"
const TARGET_SINGLE_HOSTILE_LIVING: StringName = &"target.single_hostile_living"
const TARGET_SINGLE_HUMANOID: StringName = &"target.single_humanoid"
const TARGET_SINGLE_HOSTILE_HUMANOID: StringName = &"target.single_hostile_humanoid"

@export var implementation_profile_id: StringName = &""
@export var targeting_rule_id: StringName = TARGET_SINGLE_CREATURE
@export var range_feet: int = 5
@export var player_usable: bool = true
@export var ai_usable: bool = true
@export var required_feature_ids: Array[StringName] = []

@export var resource_id: StringName = &""
@export var resource_cost: int = 0
@export var spell_rank: int = 0
@export var caster_level: int = 0
@export var school_tags: Array[StringName] = []

@export var dice_count: int = 0
@export var die_size: int = 0
@export var flat_bonus: int = 0
@export var damage_channel: StringName = &""
@export var save_type: StringName = &""
@export var save_dc: int = 0
@export var half_on_save: bool = false

@export var condition_id: StringName = &""
@export var duration_rounds: int = 0
@export var concentration: bool = false
@export var bonus_value: int = 0
@export var effect_tags: Array[StringName] = []


func controller_can_use(is_ai_controller: bool) -> bool:
	return ai_usable if is_ai_controller else player_usable


func validate_definition() -> Array[String]:
	var errors: Array[String] = super.validate_definition()
	if implementation_profile_id not in [
		PROFILE_HEAL,
		PROFILE_SAVE_CONDITION,
		PROFILE_NONLETHAL_SAVE_DAMAGE,
		PROFILE_APPLY_BONUS,
		PROFILE_DETECT_POISON,
		PROFILE_LIGHT,
	]:
		errors.append("Ability %s has an unsupported implementation profile." % id)
	if targeting_rule_id not in [
		TARGET_SELF,
		TARGET_TOUCH_CREATURE,
		TARGET_SINGLE_CREATURE,
		TARGET_SINGLE_LIVING,
		TARGET_SINGLE_HOSTILE_LIVING,
		TARGET_SINGLE_HUMANOID,
		TARGET_SINGLE_HOSTILE_HUMANOID,
	]:
		errors.append("Ability %s has an unsupported targeting rule." % id)
	if range_feet < 0:
		errors.append("Ability %s has a negative range." % id)
	if resource_cost < 0:
		errors.append("Ability %s has a negative resource cost." % id)
	if resource_cost > 0 and resource_id.is_empty():
		errors.append("Ability %s spends a resource but has no resource ID." % id)
	if implementation_profile_id in [PROFILE_HEAL, PROFILE_NONLETHAL_SAVE_DAMAGE]:
		if dice_count <= 0 or die_size < 2:
			errors.append("Ability %s has invalid dice." % id)
	if implementation_profile_id in [PROFILE_SAVE_CONDITION, PROFILE_NONLETHAL_SAVE_DAMAGE]:
		if save_type not in [&"fortitude", &"reflex", &"will"] or save_dc <= 0:
			errors.append("Ability %s has an invalid saving throw." % id)
	if implementation_profile_id == PROFILE_SAVE_CONDITION and condition_id.is_empty():
		errors.append("Ability %s applies no condition." % id)
	if duration_rounds < 0:
		errors.append("Ability %s has a negative duration." % id)
	return errors
