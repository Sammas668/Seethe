class_name ActionBudgetState
extends RefCounted

const REACTION_RESOURCE_STATE_SCRIPT: Script = preload(
	"res://domain/tactical/reactions/reaction_resource_state.gd"
)

var maximum_turn_capacity_feet: int
var remaining_turn_capacity_feet: int
var normal_capacity_spent_feet: int
var quick_action_available: bool
var reaction_state: StringName = ReactionResourceState.AVAILABLE
var reaction_reservation: ReactionReservationState = null
var reaction_available: bool:
	get:
		return reaction_state == ReactionResourceState.AVAILABLE
	set(value):
		reaction_state = (
			ReactionResourceState.AVAILABLE
			if value
			else ReactionResourceState.SPENT
		)
		# The compatibility boolean cannot describe a reservation. Any direct
		# legacy write therefore clears reservation metadata deliberately.
		reaction_reservation = null
# A normal attack may be used only once per activation. Remaining movement
# capacity may still be spent after that attack. Full Attack uses its own
# full-action sequence and does not consume this ordinary-attack allowance.
var ordinary_attack_available: bool
var ended_activation: bool


func _init(maximum_capacity_value: int = 30) -> void:
	maximum_turn_capacity_feet = max(5, maximum_capacity_value)
	refresh_for_new_round()


func refresh_for_new_round() -> void:
	remaining_turn_capacity_feet = maximum_turn_capacity_feet
	normal_capacity_spent_feet = 0
	quick_action_available = true
	reaction_state = ReactionResourceState.AVAILABLE
	reaction_reservation = null
	ordinary_attack_available = true
	ended_activation = false


func spend_normal_capacity(feet: int) -> void:
	var amount := clampi(feet, 0, remaining_turn_capacity_feet)
	remaining_turn_capacity_feet -= amount
	normal_capacity_spent_feet += amount


func reserve_reaction(reservation: ReactionReservationState) -> bool:
	if reservation == null or reaction_state != ReactionResourceState.AVAILABLE:
		return false
	reaction_state = ReactionResourceState.RESERVED
	reaction_reservation = reservation
	return true


func spend_reaction() -> bool:
	if reaction_state == ReactionResourceState.SPENT:
		return false
	reaction_state = ReactionResourceState.SPENT
	reaction_reservation = null
	return true


func cancel_reaction_reservation() -> bool:
	if reaction_state != ReactionResourceState.RESERVED:
		return false
	reaction_state = ReactionResourceState.AVAILABLE
	reaction_reservation = null
	return true


func reaction_label() -> String:
	if reaction_state == ReactionResourceState.RESERVED and reaction_reservation != null:
		match reaction_reservation.reaction_kind:
			ReactionReservationState.KIND_OVERWATCH:
				return "Overwatch"
			ReactionReservationState.KIND_BRACE:
				return "Brace"
	return ReactionResourceState.display_label(reaction_state)


func reaction_snapshot() -> Dictionary:
	return {
		"state": reaction_state,
		"reservation": (
			reaction_reservation.duplicate_state()
			if reaction_reservation != null
			else null
		),
	}


func restore_reaction_snapshot(snapshot: Variant) -> void:
	# Stage 4.5 migration: legacy snapshots stored a single boolean.
	if snapshot is bool:
		reaction_state = (
			ReactionResourceState.AVAILABLE
			if bool(snapshot)
			else ReactionResourceState.SPENT
		)
		reaction_reservation = null
		return
	if not (snapshot is Dictionary):
		reaction_state = ReactionResourceState.AVAILABLE
		reaction_reservation = null
		return
	var snapshot_dictionary: Dictionary = snapshot
	var restored_state := StringName(snapshot_dictionary.get(
		"state", ReactionResourceState.AVAILABLE
	))
	reaction_state = (
		restored_state
		if ReactionResourceState.is_valid(restored_state)
		else ReactionResourceState.AVAILABLE
	)
	var reservation_value: Variant = snapshot_dictionary.get("reservation")
	reaction_reservation = (
		reservation_value.duplicate_state()
		if reservation_value is ReactionReservationState
		else null
	)
	if reaction_state != ReactionResourceState.RESERVED:
		reaction_reservation = null


func spend_quick_action() -> void:
	quick_action_available = false


func spend_ordinary_attack() -> void:
	ordinary_attack_available = false


func has_spent_normal_capacity() -> bool:
	return normal_capacity_spent_feet > 0


func has_any_option_remaining() -> bool:
	return remaining_turn_capacity_feet > 0 or quick_action_available


func is_visibly_finished() -> bool:
	return ended_activation or not has_any_option_remaining()
