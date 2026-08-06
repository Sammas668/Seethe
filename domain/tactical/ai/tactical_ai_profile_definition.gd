class_name TacticalAIProfileDefinition
extends Resource

const ROLE_CIVILIAN: StringName = &"civilian"
const ROLE_MELEE_DEFENDER: StringName = &"melee_defender"
const ROLE_RANGED_DEFENDER: StringName = &"ranged_defender"
const ROLE_LEADER: StringName = &"leader"
const ROLE_SUPPORT: StringName = &"support"

@export var id: StringName = &""
@export var display_name: String = "Unnamed AI Profile"
@export var role: StringName = ROLE_MELEE_DEFENDER
@export var preferred_attack_kind: StringName = &""
@export var prefers_cover: bool = false
@export var prefers_overwatch: bool = false
@export var preserves_ammunition: bool = false
@export var can_raise_alarm: bool = true
@export var can_surrender: bool = true
@export var avoids_melee: bool = false
@export var support_priority: int = 0
@export var notes: String = ""


func attack_preference_bonus(attack: AttackDefinition) -> int:
	if attack == null:
		return 0
	var result: int = 0
	if not preferred_attack_kind.is_empty() and attack.attack_kind == preferred_attack_kind:
		result += 5000
	if avoids_melee and attack.attack_kind == AttackDefinition.ATTACK_MELEE:
		result -= 2500
	if role == ROLE_CIVILIAN:
		result -= 100000
	return result


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("AI profile has an empty ID.")
	if display_name.strip_edges().is_empty():
		errors.append("AI profile %s has an empty display name." % id)
	if role not in [
		ROLE_CIVILIAN,
		ROLE_MELEE_DEFENDER,
		ROLE_RANGED_DEFENDER,
		ROLE_LEADER,
		ROLE_SUPPORT,
	]:
		errors.append("AI profile %s has unknown role %s." % [id, role])
	if preferred_attack_kind not in [
		&"",
		AttackDefinition.ATTACK_MELEE,
		AttackDefinition.ATTACK_RANGED,
	]:
		errors.append(
			"AI profile %s has invalid preferred attack kind %s."
			% [id, preferred_attack_kind]
		)
	return errors
