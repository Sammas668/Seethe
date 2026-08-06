class_name Stage401TeamControlTests
extends RefCounted

const HAKON_ID: StringName = TacticalSandboxFactory.MARAUDER_ID
const ARCHER_ID: StringName = TacticalSandboxFactory.ARCHER_ID
const NEUTRAL_ID: StringName = TacticalSandboxFactory.NEUTRAL_ID
const DUMMY_ID: StringName = TacticalSandboxFactory.PRACTICE_DUMMY_ID
const AXE_ACTION_ID: StringName = &"action.raiders_axe_attack"


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_dummy_enemy_classification(failures)
	_test_team_relationship_targeting(failures)
	_test_dummy_cannot_be_player_controlled(failures)
	_test_enemy_turn_auto_pass(failures)
	return failures


static func _test_dummy_enemy_classification(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var dummy: TacticalUnitState = session.state_store.state.get_unit(DUMMY_ID)
	_expect(dummy != null, "The Training Dummy must be deployed.", failures)
	if dummy == null:
		return
	_expect(dummy.team_id == &"enemy", "The Training Dummy must belong to the enemy team.", failures)
	_expect(dummy.roster_role == &"enemy", "The Training Dummy must retain the enemy roster role.", failures)
	_expect(dummy.controller_type == TacticalUnitState.CONTROLLER_AI, "The Training Dummy must use the AI controller.", failures)
	_expect(dummy.turn_behavior == TacticalUnitState.TURN_BEHAVIOR_AUTO_PASS, "The Training Dummy must use Automatic Pass behaviour.", failures)
	_expect(dummy.participates_in_enemy_turn, "The Training Dummy must participate in the Enemy Turn.", failures)
	_expect(not dummy.counts_for_victory, "The Training Dummy must not count for mission victory.", failures)
	_expect(dummy.persistence_scope == &"mission", "The Training Dummy must remain mission-local.", failures)
	_expect(not session.player_unit_order.has(DUMMY_ID), "The Training Dummy must not appear in the player roster order.", failures)


static func _test_team_relationship_targeting(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var hostile_preview = session.screen_facade.preview_attack(
		HAKON_ID,
		DUMMY_ID,
		AXE_ACTION_ID,
		0
	)
	var allied_preview = session.screen_facade.preview_attack(
		HAKON_ID,
		ARCHER_ID,
		AXE_ACTION_ID,
		0
	)
	var neutral_preview = session.screen_facade.preview_attack(
		HAKON_ID,
		NEUTRAL_ID,
		AXE_ACTION_ID,
		0
	)
	_expect(hostile_preview != null and hostile_preview.success, "The enemy Training Dummy must be a legal hostile target.", failures)
	_expect(allied_preview != null and not allied_preview.success, "A player teammate must not be a legal Stage 4.0.1 target.", failures)
	_expect(neutral_preview != null and not neutral_preview.success, "A neutral Farmhand must not be a legal Stage 4.0.1 target.", failures)
	_expect(TacticalTeamRelations.are_hostile(&"player", &"enemy"), "Player and enemy teams must be hostile.", failures)
	_expect(TacticalTeamRelations.are_allied(&"player", &"player"), "Player teammates must be allied.", failures)
	_expect(TacticalTeamRelations.relationship(&"player", &"neutral") == TacticalTeamRelations.RELATION_NEUTRAL, "Player and neutral teams must remain neutral.", failures)


static func _test_dummy_cannot_be_player_controlled(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var dummy: TacticalUnitState = session.state_store.state.get_unit(DUMMY_ID)
	_expect(dummy != null and not dummy.is_player_controlled(), "The Training Dummy must never be player-controlled.", failures)
	var reverse_preview = session.screen_facade.preview_attack(
		DUMMY_ID,
		HAKON_ID,
		AXE_ACTION_ID,
		0
	)
	_expect(reverse_preview != null and not reverse_preview.success, "The player interface must not execute attacks for the Training Dummy.", failures)


static func _test_enemy_turn_auto_pass(failures: Array[String]) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var dummy: TacticalUnitState = session.state_store.state.get_unit(DUMMY_ID)
	var revision_before: int = session.state_store.state.revision
	var begin_result: OperationResult = session.screen_facade.begin_world_phase()
	_expect(begin_result.success, "Ending the Player Phase must begin the Enemy Turn.", failures)
	var enemy_result: OperationResult = session.screen_facade.resolve_enemy_turn()
	_expect(enemy_result.success, "The Enemy Turn must resolve without player input.", failures)
	_expect(dummy.action_budget.ended_activation, "The Training Dummy must automatically end its Enemy Turn activation.", failures)
	_expect(session.state_store.state.revision > revision_before, "Enemy automatic passes must commit through TacticalStateStore.", failures)

	var events_value: Variant = session.event_journal.call("events", &"events", true)
	var events: Array = events_value if events_value is Array else []
	var saw_dummy_turn: bool = false
	var saw_dummy_pass: bool = false
	for event_value: Variant in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value as Dictionary
		if StringName(event.get("source_actor_id", &"")) != DUMMY_ID:
			continue
		var event_type: StringName = StringName(event.get("event_type", &""))
		if event_type == &"unit_turn_started":
			saw_dummy_turn = true
		elif event_type == &"unit_passed":
			saw_dummy_pass = true
	_expect(saw_dummy_turn, "The combat journal must record the Training Dummy's Enemy Turn activation.", failures)
	_expect(saw_dummy_pass, "The combat journal must record the Training Dummy's automatic pass.", failures)

	var complete_result: OperationResult = session.screen_facade.complete_world_phase()
	_expect(complete_result.success, "The Enemy Turn must return control to the next Player Phase.", failures)
	_expect(session.state_store.state.phase_state.is_player_phase(), "Control must return to the Player Phase after enemy passes.", failures)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
