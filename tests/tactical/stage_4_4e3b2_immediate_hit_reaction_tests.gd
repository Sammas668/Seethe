class_name Stage44e3b2ImmediateHitReactionTests
extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const CADENCE_NONE: int = 0
const CADENCE_AI_MOVE_TO_ATTACK: int = 2


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var target: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	if target == null:
		failures.append("The Stage 4.4e3b2 damage-reaction fixture is incomplete.")
		return failures

	var screen = SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	tree.root.add_child(screen)
	await tree.process_frame

	var unit_views: Dictionary = screen.get("_unit_views")
	var target_view := unit_views.get(target.unit_id) as TacticalUnitView
	if target_view == null:
		failures.append("The target TacticalUnitView was not created.")
		screen.queue_free()
		await tree.process_frame
		return failures

	# Reset instrumentation and inject the same presentation event produced by a
	# committed damaging attack held during movement animation.
	target_view.set("_damage_reaction_progress", 1.0)
	screen.set("_last_cadence_event", CADENCE_NONE)
	screen.set("_pending_movement_cadence_event", CADENCE_AI_MOVE_TO_ATTACK)
	var deferred_events: Array[Dictionary] = [
		{"target_id": target.unit_id}
	]
	screen.set("_deferred_damage_events", deferred_events)

	# The coroutine must release the hit reaction synchronously before reaching
	# its first frame/cadence await.
	screen.call("_complete_movement_handoff_after_frame")
	var remaining_events: Array = screen.get("_deferred_damage_events")
	_expect(
		remaining_events.is_empty(),
		"Movement handoff must release deferred damage before its first await.",
		failures
	)
	_expect(
		float(target_view.get("_damage_reaction_progress")) < 1.0,
		"The crimson pulse and shake must begin before readability cadence.",
		failures
	)
	_expect(
		int(screen.get("_last_cadence_event")) == CADENCE_NONE,
		"Hit confirmation must begin before the cadence runner starts.",
		failures
	)

	# Allow the handoff coroutine and its 0.18-second cadence to complete cleanly.
	await tree.create_timer(0.24).timeout
	screen.queue_free()
	await tree.process_frame
	return failures


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
