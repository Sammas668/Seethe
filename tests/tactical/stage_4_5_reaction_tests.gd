class_name Stage45ReactionTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_reaction_resource_states(failures)
	_test_reaction_snapshot_migration(failures)
	_test_decision_choices(failures)
	_test_required_assets(failures)
	_test_locked_source_contracts(failures)
	return failures


static func _test_reaction_resource_states(failures: Array[String]) -> void:
	var budget := ActionBudgetState.new(40)
	_expect(
		budget.reaction_state == ReactionResourceState.AVAILABLE,
		"A refreshed Reaction must begin Available.",
		failures
	)
	var reservation := ReactionReservationState.new()
	reservation.reaction_kind = ReactionReservationState.KIND_OVERWATCH
	reservation.source_unit_id = &"archer"
	reservation.reserved_attack_action_id = &"attack.training_shortbow"
	reservation.covered_tiles = [Vector2i(3, 2)]
	_expect(budget.reserve_reaction(reservation), "Available must reserve.", failures)
	_expect(
		budget.reaction_state == ReactionResourceState.RESERVED,
		"A prepared Reaction must be Reserved.",
		failures
	)
	_expect(
		budget.reaction_label() == "Overwatch",
		"Reserved Overwatch must have a readable resource label.",
		failures
	)
	_expect(budget.cancel_reaction_reservation(), "Reserved must cancel.", failures)
	_expect(
		budget.reaction_state == ReactionResourceState.AVAILABLE,
		"Cancelling an unused reservation must return the Reaction to Available.",
		failures
	)
	_expect(budget.spend_reaction(), "Available must spend.", failures)
	_expect(
		budget.reaction_state == ReactionResourceState.SPENT,
		"A used Reaction must become Spent.",
		failures
	)
	budget.refresh_for_new_round()
	_expect(
		budget.reaction_state == ReactionResourceState.AVAILABLE,
		"Start-of-turn refresh must restore Available.",
		failures
	)


static func _test_reaction_snapshot_migration(failures: Array[String]) -> void:
	var budget := ActionBudgetState.new(30)
	budget.restore_reaction_snapshot(false)
	_expect(
		budget.reaction_state == ReactionResourceState.SPENT,
		"Legacy false Reaction snapshots must migrate to Spent.",
		failures
	)
	budget.restore_reaction_snapshot(true)
	_expect(
		budget.reaction_state == ReactionResourceState.AVAILABLE,
		"Legacy true Reaction snapshots must migrate to Available.",
		failures
	)
	var reservation := ReactionReservationState.new()
	reservation.reaction_kind = ReactionReservationState.KIND_BRACE
	reservation.source_unit_id = &"spear_guard"
	reservation.covered_tiles = [Vector2i(5, 5)]
	budget.reserve_reaction(reservation)
	var snapshot: Dictionary = budget.reaction_snapshot()
	budget.spend_reaction()
	budget.restore_reaction_snapshot(snapshot)
	_expect(
		budget.reaction_state == ReactionResourceState.RESERVED,
		"Rollback must restore a reserved Reaction rather than flattening it to a boolean.",
		failures
	)
	_expect(
		budget.reaction_reservation != null
		and budget.reaction_reservation.reaction_kind == ReactionReservationState.KIND_BRACE,
		"Rollback must preserve the complete reservation.",
		failures
	)


static func _test_decision_choices(failures: Array[String]) -> void:
	var request := ReactionDecisionRequest.new()
	request.use_choice = ReactionDecisionRequest.CHOICE_FIRE
	request.decline_choice = ReactionDecisionRequest.CHOICE_HOLD
	_expect(
		request.is_valid_choice(ReactionDecisionRequest.CHOICE_FIRE),
		"Overwatch must accept Fire.",
		failures
	)
	_expect(
		request.is_valid_choice(ReactionDecisionRequest.CHOICE_HOLD),
		"Overwatch must accept Hold Fire.",
		failures
	)
	_expect(
		not request.is_valid_choice(ReactionDecisionRequest.CHOICE_DECLINE),
		"A prompt must reject choices that do not belong to it.",
		failures
	)


static func _test_required_assets(failures: Array[String]) -> void:
	for path: String in [
		"res://presentation/tactical/icons/reaction_aoo_icon.svg",
		"res://presentation/tactical/icons/reaction_overwatch_bow_icon.svg",
		"res://presentation/tactical/icons/reaction_brace_spear_icon.svg",
		"res://content/actions/brace.tres",
	]:
		_expect(ResourceLoader.exists(path), "Required Stage 4.5 asset is missing: %s" % path, failures)


static func _test_locked_source_contracts(failures: Array[String]) -> void:
	var screen_text: String = _read("res://presentation/tactical/tactical_screen.gd")
	var service_text: String = _read(
		"res://application/tactical/reactions/tactical_reaction_service.gd"
	)
	var board_text: String = _read("res://presentation/tactical/tactical_board_view.gd")
	for token: String in [
		'request.use_label = "Use Reaction"',
		'request.decline_label = "Decline"',
		'request.use_label = "Fire"',
		'request.decline_label = "Hold Fire"',
		'request.use_label = "Use Brace"',
		'request.decline_label = "Hold Brace"',
	]:
		_expect(service_text.contains(token), "Decision contract missing: %s" % token, failures)
	_expect(
		screen_text.contains("KEY_ESCAPE")
		and screen_text.contains("MOUSE_BUTTON_RIGHT"),
		"Escape and right-click must provide the safe decline/hold input.",
		failures
	)
	_expect(
		board_text.contains("REACTION_OVERWATCH_ICON")
		and board_text.contains("reaction_overwatch_bow_icon.svg"),
		"Overwatch previews must use the dedicated bow icon.",
		failures
	)


static func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
