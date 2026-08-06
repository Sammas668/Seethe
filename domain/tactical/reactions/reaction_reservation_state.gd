class_name ReactionReservationState
extends RefCounted

const KIND_OVERWATCH: StringName = &"overwatch"
const KIND_BRACE: StringName = &"brace"

var reaction_kind: StringName = &""
var reaction_definition_id: StringName = &""
var source_unit_id: StringName = &""
var controller_id: StringName = &""
var reserved_weapon_item_id: StringName = &""
var reserved_attack_action_id: StringName = &""
var covered_tiles: Array[Vector2i] = []
var direction: Vector2i = Vector2i.ZERO
var created_round: int = 0
var created_activation_id: StringName = &""
var presentation_profile_id: StringName = &""


func duplicate_state() -> ReactionReservationState:
	var copy := ReactionReservationState.new()
	copy.reaction_kind = reaction_kind
	copy.reaction_definition_id = reaction_definition_id
	copy.source_unit_id = source_unit_id
	copy.controller_id = controller_id
	copy.reserved_weapon_item_id = reserved_weapon_item_id
	copy.reserved_attack_action_id = reserved_attack_action_id
	copy.covered_tiles = covered_tiles.duplicate()
	copy.direction = direction
	copy.created_round = created_round
	copy.created_activation_id = created_activation_id
	copy.presentation_profile_id = presentation_profile_id
	return copy


func contains(tile: Vector2i) -> bool:
	return covered_tiles.has(tile)
