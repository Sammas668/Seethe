class_name ReactionDecisionRequest
extends RefCounted

const CHOICE_USE: StringName = &"use"
const CHOICE_DECLINE: StringName = &"decline"
const CHOICE_FIRE: StringName = &"fire"
const CHOICE_HOLD: StringName = &"hold"
const CHOICE_USE_BRACE: StringName = &"use_brace"
const CHOICE_HOLD_BRACE: StringName = &"hold_brace"

var request_id: StringName = &""
var candidate: ReactionCandidate
var controller_id: StringName = &""
var reacting_unit_id: StringName = &""
var triggering_unit_id: StringName = &""
var triggering_action_name: String = "Movement"
var reaction_display_name: String = "Reaction"
var weapon_display_name: String = ""
var predicted_hit_chance: int = 0
var predicted_damage_text: String = ""
var modifier_lines: Array[String] = []
var use_label: String = "Use Reaction"
var decline_label: String = "Decline"
var use_choice: StringName = CHOICE_USE
var decline_choice: StringName = CHOICE_DECLINE
var decline_keeps_reservation: bool = false
var created_event_id: StringName = &""
var resolved: bool = false


func is_valid_choice(choice: StringName) -> bool:
	return choice == use_choice or choice == decline_choice
