class_name TacticalAttackPreview
extends RefCounted

var success: bool = false
var reason: String = ""
var attacker_id: StringName = &""
var target_id: StringName = &""
var action_id: StringName = &""
var source_item_id: StringName = &""
var expected_state_revision: int = 0
var power_attack_value: int = 0
var attack_bonus: int = 0
var target_armour_class: int = 10
var hit_chance_percent: int = 0
var critical_threat_minimum: int = 20
var critical_multiplier: int = 2
var damage_dice_count: int = 0
var damage_die_size: int = 0
var damage_bonus: int = 0
var damage_type: StringName = &""
var damage_channel: StringName = &"lethal"
var nonlethal_attack_penalty: int = 0
var nonlethal_penalty_ignored: bool = false
var damage_notation: String = ""
var range_feet: int = 0
var action_cost_feet: int = 0
var capacity_before: int = 0
var capacity_after: int = 0
var attack_display_name: String = ""
var attacker_display_name: String = ""
var target_display_name: String = ""


func reject(message: String):
	success = false
	reason = message
	return self


func accept():
	success = true
	reason = ""
	return self
