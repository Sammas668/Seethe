class_name Stage431aTokenStatusSquadAlertTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_generated_watch_members_share_alert(failures)
	_test_body_state_badge_changes_immediately(failures)
	_test_awareness_eye_is_enemy_only(failures)
	return failures


static func _test_generated_watch_members_share_alert(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var marauder: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var guard: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	var archer: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_TWO_ID
	)
	var dummy: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.PRACTICE_DUMMY_ID
	)
	var watch: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	var separate_squad: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_B_ID
	)
	if (
		marauder == null or guard == null or archer == null or dummy == null
		or watch == null or separate_squad == null
	):
		failures.append("The shared-squad alert fixture is incomplete.")
		return

	_expect(
		guard.squad_id == watch.squad_id
		and archer.squad_id == watch.squad_id,
		"The generated Settlement Guard and Settlement Archer must share one authored squad.",
		failures
	)
	_expect(
		watch.member_unit_ids.has(guard.unit_id)
		and watch.member_unit_ids.has(archer.unit_id),
		"Settlement Watch Squad A must contain both generated combatants.",
		failures
	)
	_expect(
		dummy.squad_id == separate_squad.squad_id,
		"The sandbox must retain a separate enemy squad for squad-limited awareness tests.",
		failures
	)

	var resolution := TacticalDetectionResolution.new()
	resolution.unit_id = marauder.unit_id
	resolution.alert_on_detection = true
	resolution.automatic_detection = true
	resolution.stealth_broken = true
	resolution.detected_observer_ids.append(guard.unit_id)
	resolution.detected_squad_ids.append(watch.squad_id)
	resolution.revealed_at_destination_squad_ids.append(watch.squad_id)
	resolution.last_seen_tile_by_squad_id[watch.squad_id] = marauder.grid_position
	var resolver := ContactInitiativeResolver.new()
	resolver.configure(
		session.state_store,
		session.combat_dice_roller as TacticalDiceRoller
	)
	# Three players plus the two members of the detecting squad.
	session.combat_dice_roller.call(
		"set_scripted_results",
		[20, 19, 18, 17, 16]
	)
	resolver.finalize_resolution(marauder, resolution)
	_expect(
		session.detection_service.apply_resolution(resolution),
		"The shared-squad alert resolution must apply.",
		failures
	)
	_expect(
		watch.is_aware(),
		"Detection by one member must make the whole authored squad Aware.",
		failures
	)
	_expect(
		not separate_squad.is_aware(),
		"An unrelated squad must remain Unaware.",
		failures
	)
	_expect(
		state.phase_state.initiative_order.has(guard.unit_id)
		and state.phase_state.initiative_order.has(archer.unit_id),
		"Every conscious member of the detecting squad must enter initiative.",
		failures
	)
	_expect(
		not state.phase_state.initiative_order.has(dummy.unit_id),
		"The unrelated squad must not be pulled into initiative.",
		failures
	)


static func _test_body_state_badge_changes_immediately(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var guard: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	if guard == null:
		failures.append("The token-status fixture is missing its guard.")
		return
	var view := TacticalUnitView.new()
	view.configure(guard, Vector2.ZERO, 28.0, Color(0.8, 0.2, 0.15, 1.0))
	view.set_aware_badge(true)
	_expect(
		view.displayed_badge_kind() == TacticalUnitView.BADGE_KIND_AWARE,
		"An active aware guard must initially show the awareness eye.",
		failures
	)

	guard.restore_damage_state(-1, 0)
	view.set_life_state(
		guard.life_state_id(),
		guard.dying_successes,
		guard.dying_failures
	)
	_expect(
		view.displayed_badge_kind() == TacticalUnitView.BADGE_KIND_DYING,
		"Entering Dying must immediately replace the awareness eye with the Dying badge.",
		failures
	)
	_expect(
		int(view.get("_dying_successes")) == 0
		and int(view.get("_dying_failures")) == 0,
		"A newly Dying unit must show an empty success/failure track until its turn.",
		failures
	)

	guard.dying_successes = 1
	view.set_life_state(
		guard.life_state_id(),
		guard.dying_successes,
		guard.dying_failures
	)
	_expect(
		int(view.get("_dying_successes")) == 1,
		"Dying pips must update when the unit's Dying check changes the track.",
		failures
	)

	guard.become_stable()
	view.set_life_state(
		guard.life_state_id(),
		guard.dying_successes,
		guard.dying_failures
	)
	_expect(
		view.displayed_badge_kind() == TacticalUnitView.BADGE_KIND_UNCONSCIOUS,
		"Stabilisation must immediately replace the Dying badge with ZZZ.",
		failures
	)

	guard.restore_damage_state(guard.death_threshold_hp(), 0)
	view.set_life_state(
		guard.life_state_id(),
		guard.dying_successes,
		guard.dying_failures
	)
	_expect(
		view.displayed_badge_kind() == TacticalUnitView.BADGE_KIND_DEAD,
		"Immediate death must replace every other badge with the Dead emblem.",
		failures
	)
	view.free()


static func _test_awareness_eye_is_enemy_only(
	failures: Array[String]
) -> void:
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var player: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var guard: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	if player == null or guard == null:
		failures.append("The enemy-only awareness badge fixture is incomplete.")
		return

	var player_view := TacticalUnitView.new()
	player_view.configure(
		player,
		Vector2.ZERO,
		28.0,
		Color(0.15, 0.48, 0.92, 1.0)
	)
	player_view.set_hidden_badge(false)
	player_view.set_aware_badge(true)
	_expect(
		player_view.displayed_badge_kind() == TacticalUnitView.BADGE_KIND_NONE,
		"Player characters must never show the enemy patrol awareness eye.",
		failures
	)

	var enemy_view := TacticalUnitView.new()
	enemy_view.configure(
		guard,
		Vector2.ZERO,
		28.0,
		Color(0.8, 0.2, 0.15, 1.0)
	)
	enemy_view.set_aware_badge(true)
	_expect(
		enemy_view.displayed_badge_kind() == TacticalUnitView.BADGE_KIND_AWARE,
		"An active aware enemy patrol member must still show the awareness eye.",
		failures
	)
	player_view.free()
	enemy_view.free()


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
