class_name AttackDefinition
extends ActionDefinition

const ATTACK_MELEE: StringName = &"melee"
const ATTACK_RANGED: StringName = &"ranged"

const SEQUENCE_NORMAL: StringName = &"normal"
const SEQUENCE_FULL: StringName = &"full"

@export var attack_kind: StringName = ATTACK_MELEE
@export var attack_sequence_kind: StringName = SEQUENCE_NORMAL
@export var attack_ability: StringName = &"strength"
@export var attack_bonus_modifier: int = 0
@export var damage_ability: StringName = &""
@export var damage_bonus_modifier: int = 0
@export var damage_profile: DamageProfile
@export var range_profile: RangeProfile
@export var targeting_rule_id: StringName = &"target.single_creature"
@export var critical_threat_minimum: int = 20
@export var critical_multiplier: int = 2
@export var attack_tags: Array[StringName] = []


func compact_summary() -> String:
	var damage_text := (
		damage_profile.notation()
		if damage_profile != null
		else "No damage"
	)
	var range_text := (
		range_profile.summary()
		if range_profile != null
		else "No range"
	)
	return "%s · %s · %s" % [display_name, damage_text, range_text]


func validate_definition() -> Array[String]:
	var errors := super.validate_definition()
	if attack_kind not in [ATTACK_MELEE, ATTACK_RANGED]:
		errors.append("Attack %s has an unknown attack kind." % id)
	if attack_sequence_kind not in [SEQUENCE_NORMAL, SEQUENCE_FULL]:
		errors.append("Attack %s has an unknown attack sequence kind." % id)
	if attack_ability.is_empty():
		errors.append("Attack %s has no attack ability." % id)
	if damage_profile == null:
		errors.append("Attack %s has no damage profile." % id)
	else:
		errors.append_array(damage_profile.validate_profile(id))
	if range_profile == null:
		errors.append("Attack %s has no range profile." % id)
	else:
		errors.append_array(range_profile.validate_profile(id))
	if targeting_rule_id.is_empty():
		errors.append("Attack %s has no targeting rule." % id)
	if critical_threat_minimum < 2 or critical_threat_minimum > 20:
		errors.append("Attack %s has an invalid critical threshold." % id)
	if critical_multiplier < 2:
		errors.append("Attack %s has an invalid critical multiplier." % id)
	return errors
