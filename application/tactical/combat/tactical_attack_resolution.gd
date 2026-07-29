class_name TacticalAttackResolution
extends RefCounted

var preview
var attack_roll: int = 0
var attack_total: int = 0
var natural_one: bool = false
var natural_twenty: bool = false
var hit: bool = false
var critical_threat: bool = false
var confirmation_roll: int = 0
var confirmation_total: int = 0
var critical_confirmed: bool = false
var damage_die_results: Array[int] = []
var base_damage: int = 0
var final_damage: int = 0
var applied_damage: int = 0
var damage_channel: StringName = &"lethal"
var target_hp_before: int = 0
var target_hp_after: int = 0
var target_nonlethal_before: int = 0
var target_nonlethal_after: int = 0
var target_combat_state_before: StringName = &"active"
var target_combat_state_after: StringName = &"active"
var target_became_defeated: bool = false
var capacity_before: int = 0
var capacity_after: int = 0


func outcome_label() -> String:
	if not hit:
		return "MISS"
	if critical_confirmed:
		return "CRITICAL HIT"
	return "HIT"
