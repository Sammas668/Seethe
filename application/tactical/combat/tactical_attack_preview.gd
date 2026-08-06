class_name TacticalAttackPreview
extends RefCounted

var success: bool = false
var reason: String = ""
var attacker_id: StringName = &""
var target_id: StringName = &""
var action_id: StringName = &""
var source_item_id: StringName = &""
var expected_state_revision: int = 0
var expected_geometry_revision: int = 0
var power_attack_value: int = 0
var attack_bonus: int = 0
var target_armour_class: int = 10
var base_target_armour_class: int = 10
var effective_target_armour_class: int = 10
var has_line_of_sight: bool = false
var has_line_of_effect: bool = false
var cover_category: StringName = TacticalCombatGeometryResult.COVER_NONE
var cover_ac_bonus: int = 0
var cover_reflex_bonus: int = 0
var clear_exposure_samples: int = 5
var total_exposure_samples: int = 5
var primary_cover_source_id: StringName = &""
var primary_cover_source_kind: StringName = &""
var attack_origin_override: Variant = null
var target_position_override: Variant = null
var uses_automatic_lean: bool = false
var firing_origin_kind: StringName = &"centre"
var firing_edge_id: StringName = &""
var normal_origin_legal: bool = false
var normal_origin_hit_chance: int = 0
var chosen_origin_hit_chance: int = 0
var chosen_origin_cover_category: StringName = TacticalCombatGeometryResult.COVER_NONE
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
var nonproficiency_penalty: int = 0
var target_denied_dexterity: bool = false
var uncanny_dodge_retained: bool = false
var damage_notation: String = ""
var range_feet: int = 0
var range_penalty: int = 0
var action_cost_feet: int = 0
var capacity_before: int = 0
var capacity_after: int = 0
var attack_display_name: String = ""
var attacker_display_name: String = ""
var target_display_name: String = ""
# Stage 4.5 reaction context. Ordinary attacks keep these defaults.
var action_source: StringName = &"ordinary"
var reaction_kind: StringName = &""
var reaction_attack_modifier: int = 0
var reaction_context: Dictionary = {}
var provoking_reaction_summaries: Array[Dictionary] = []
var highest_provoking_reaction_hit_chance: int = 0


func reject(message: String):
	success = false
	reason = message
	return self


func accept():
	success = true
	reason = ""
	return self
