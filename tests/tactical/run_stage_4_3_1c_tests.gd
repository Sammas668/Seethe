extends SceneTree

const TACTICAL_SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var screen: Node = TACTICAL_SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	get_root().add_child(screen)
	await process_frame

	var state: TacticalState = session.state_store.state
	var guard: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	var archer: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_TWO_ID
	)
	var marauder: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var watch: TacticalSquadState = state.get_squad(
		TacticalSandboxFactory.GUARD_SQUAD_A_ID
	)
	var views_value: Variant = screen.get("_unit_views")
	var views: Dictionary = views_value if views_value is Dictionary else {}
	var guard_view: TacticalUnitView = null
	if guard != null:
		guard_view = views.get(guard.unit_id) as TacticalUnitView
	if guard == null or archer == null or marauder == null or watch == null:
		failures.append("The Stage 4.3.1c sandbox fixture is incomplete.")
	elif guard_view == null:
		failures.append("The guard token view was not created.")
	else:
		watch.make_aware()
		guard_view.set_aware_badge(true)
		guard.restore_damage_state(-1, 0)
		# No state_changed signal is emitted here. The frame-level visual
		# reconciliation must still replace the awareness eye immediately.
		await process_frame
		if (
			guard_view.displayed_badge_kind()
			!= TacticalUnitView.BADGE_KIND_DYING
		):
			failures.append(
				"A negative-HP threshold must replace the eye with the Dying badge on the next rendered frame."
			)

		guard.restore_damage_state(guard.maximum_hp, 0)
		marauder.stealth_enabled = false
		marauder.reveal_to_squad(watch.squad_id)
		watch.remember_last_seen(marauder.unit_id, marauder.grid_position)
		state.begin_initiative_combat(
			[archer.unit_id, marauder.unit_id],
			{
				archer.unit_id: 20,
				marauder.unit_id: 10,
			}
		)
		screen.call("_schedule_initiative_ai")
		await create_timer(1.5).timeout
		if (
			state.phase_state.is_initiative_combat()
			and state.phase_state.active_unit_id() == archer.unit_id
		):
			failures.append(
				"The initiative presentation must advance after the archer completes its AI activation."
			)

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("Stage 4.3.1c immediate life-state and AI handoff tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
