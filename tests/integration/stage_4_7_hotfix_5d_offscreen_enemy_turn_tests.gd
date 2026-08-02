class_name Stage47Hotfix5dOffscreenEnemyTurnTests
extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const VISIBILITY_UNOBSERVED: int = 0
const VISIBILITY_PARTIAL: int = 1


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var player: TacticalUnitState = state.get_unit(TacticalSandboxFactory.MARAUDER_ID)
	var enemy: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_ID)
	var enemy_two: TacticalUnitState = state.get_unit(TacticalSandboxFactory.ENEMY_TWO_ID)
	if player == null or enemy == null or enemy_two == null:
		failures.append("The Hotfix 5d tactical fixture is incomplete.")
		return failures

	state.set_unit_position(player.unit_id, Vector2i(2, 2), session.map_definition, false)
	state.set_unit_position(enemy.unit_id, Vector2i(40, 40), session.map_definition, false)
	state.set_unit_position(enemy_two.unit_id, Vector2i(42, 40), session.map_definition, false)
	session.visibility_service.call("recalculate_all_teams")

	var screen = SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	tree.root.add_child(screen)
	await tree.process_frame

	var hidden_event: Dictionary = {
		"unit_id": enemy.unit_id,
		"path": [Vector2i(40, 40), Vector2i(41, 40)],
		"dragged_body_cells_before": {},
		"reaction_events": [],
	}
	_expect(
		int(screen.call("_ai_movement_event_visibility", hidden_event))
		== VISIBILITY_UNOBSERVED,
		"A route entirely outside player sight must be classified as unobserved.",
		failures
	)
	var hidden_segment: Array = screen.call(
		"_observable_ai_path_segment",
		hidden_event["path"]
	)
	_expect(
		hidden_segment.is_empty(),
		"An unobserved route must produce no movement-animation segment.",
		failures
	)
	_expect(
		not bool(screen.call("_unit_handoff_is_observable", enemy)),
		"A hidden AI actor must not receive a player-facing handoff.",
		failures
	)
	_expect(
		not bool(screen.call("_has_visible_enemy_turn_participant")),
		"A phase containing only hidden enemies must not require the phase cadence.",
		failures
	)

	var partial_path: Array[Vector2i] = [
		Vector2i(40, 40),
		player.grid_position,
	]
	var partial_event: Dictionary = {
		"unit_id": enemy.unit_id,
		"path": partial_path,
		"dragged_body_cells_before": {},
		"reaction_events": [],
	}
	_expect(
		int(screen.call("_ai_movement_event_visibility", partial_event))
		== VISIBILITY_PARTIAL,
		"A hidden route entering a visible tile must become partially observed.",
		failures
	)
	var visible_segment: Array = screen.call(
		"_observable_ai_path_segment",
		partial_path
	)
	_expect(
		not visible_segment.is_empty()
		and Vector2i(visible_segment.back()) == player.grid_position,
		"Partial presentation must begin only on player-visible tiles.",
		failures
	)

	var performance: Dictionary = session.enemy_turn_handler.call(
		"performance_snapshot"
	)
	_expect(
		performance.has("activation_timing"),
		"Enemy AI performance output must expose activation timing diagnostics.",
		failures
	)

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
