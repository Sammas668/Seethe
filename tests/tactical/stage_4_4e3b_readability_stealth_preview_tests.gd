class_name Stage44e3bReadabilityStealthPreviewTests
extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const NONE_INTENT: int = 0
const MOVE_PREVIEW_INTENT: int = 1
const CADENCE_NONE: int = 0
const CADENCE_ACTIVATION_HANDOFF: int = 1
const CADENCE_AI_MOVE_TO_ATTACK: int = 2
const CADENCE_PHASE_HANDOFF: int = 3
const CADENCE_ENEMY_REVEALED: int = 4
const CADENCE_ALERT_TRIGGERED: int = 5


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var state: TacticalState = session.state_store.state
	var facade = session.screen_facade
	var marauder: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	var guard_a: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_ID
	)
	var guard_b: TacticalUnitState = state.get_unit(
		TacticalSandboxFactory.ENEMY_TWO_ID
	)
	if marauder == null or guard_a == null or guard_b == null:
		failures.append("The Stage 4.4e3b Stealth-preview fixture is incomplete.")
		return failures

	state.set_unit_position(
		marauder.unit_id,
		Vector2i(10, 20),
		session.map_definition,
		false
	)
	state.set_unit_position(
		guard_a.unit_id,
		Vector2i(20, 25),
		session.map_definition,
		false
	)
	state.set_unit_position(
		guard_b.unit_id,
		Vector2i(40, 40),
		session.map_definition,
		false
	)
	guard_a.set_facing(Vector2i(0, -1))
	guard_b.set_facing(Vector2i(1, 0))
	session.visibility_service.call("recalculate_all_teams")
	var stealth_result: OperationResult = facade.enter_stealth(marauder.unit_id)
	_expect(
		stealth_result.success,
		"The Stage 4.4e3b route fixture must enter Stealth.",
		failures
	)

	var screen = SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	tree.root.add_child(screen)
	await tree.process_frame
	screen.call("_select_unit", marauder.unit_id)
	screen.set("_hover_preview_build_count", 0)
	screen.set("_movement_detection_preview_query_count", 0)

	var risky_destination := Vector2i(20, 20)
	var replacement_destination := Vector2i(19, 20)

	# Hover remains cheap and supplies no route or detection data.
	screen.call("_on_board_tile_hovered", risky_destination)
	_expect(
		int(screen.get("_hover_preview_build_count")) == 0,
		"Hovering an empty tile must not build a movement path.",
		failures
	)
	_expect(
		int(screen.get("_movement_detection_preview_query_count")) == 0,
		"Hovering an empty tile must not query Stealth detection.",
		failures
	)
	_expect(
		int(screen.get("_board_intent_mode")) == NONE_INTENT,
		"Hovering must not enter movement-preview intent.",
		failures
	)

	# The first click creates one path and one matching per-tile Stealth trail.
	screen.call("_on_board_tile_left_clicked", risky_destination)
	var first_detection := screen.get("_detection_preview") as MovementDetectionPreview
	_expect(
		int(screen.get("_board_intent_mode")) == MOVE_PREVIEW_INTENT,
		"The first destination click must lock movement-preview intent.",
		failures
	)
	_expect(
		int(screen.get("_hover_preview_build_count")) == 1,
		"The first destination click must build exactly one movement preview.",
		failures
	)
	_expect(
		int(screen.get("_movement_detection_preview_query_count")) == 1,
		"The first destination click must build exactly one detection preview.",
		failures
	)
	_expect(
		first_detection != null and first_detection.tile_previews.size() >= 2,
		"The clicked Stealth route must restore percentages on its risky tiles.",
		failures
	)
	var first_signature: String = _detection_signature(first_detection)

	# Cursor movement cannot rebuild or replace the clicked route information.
	screen.call("_on_board_tile_hovered", replacement_destination)
	_expect(
		int(screen.get("_movement_detection_preview_query_count")) == 1,
		"Cursor movement after the first click must not query detection again.",
		failures
	)
	_expect(
		_detection_signature(
			screen.get("_detection_preview") as MovementDetectionPreview
		) == first_signature,
		"Cursor movement must preserve the locked per-tile Stealth trail.",
		failures
	)

	# A different click replaces both route and detection preview exactly once.
	screen.call("_on_board_tile_left_clicked", replacement_destination)
	_expect(
		Vector2i(screen.get("_planned_destination")) == replacement_destination,
		"A different destination click must replace the locked destination.",
		failures
	)
	_expect(
		int(screen.get("_movement_detection_preview_query_count")) == 2,
		"Replacing the destination must query one replacement detection preview.",
		failures
	)
	_expect(
		marauder.grid_position == Vector2i(10, 20),
		"Replacing a preview must not commit movement.",
		failures
	)

	# Cadence values are central, distinct and ordinary movement remains zero-delay.
	_expect(
		is_zero_approx(float(screen.call("_cadence_seconds", CADENCE_NONE))),
		"Ordinary movement must have no fixed post-action delay.",
		failures
	)
	_expect(
		is_equal_approx(
			float(screen.call("_cadence_seconds", CADENCE_ACTIVATION_HANDOFF)),
			0.15
		),
		"Activation handoff cadence must use the central 0.15-second value.",
		failures
	)
	_expect(
		is_equal_approx(
			float(screen.call("_cadence_seconds", CADENCE_AI_MOVE_TO_ATTACK)),
			0.18
		),
		"AI movement-to-attack cadence must use the central 0.18-second value.",
		failures
	)
	_expect(
		is_equal_approx(
			float(screen.call("_cadence_seconds", CADENCE_PHASE_HANDOFF)),
			0.25
		),
		"Phase handoff cadence must use the central 0.25-second value.",
		failures
	)
	_expect(
		is_equal_approx(
			float(screen.call("_cadence_seconds", CADENCE_ENEMY_REVEALED)),
			0.35
		),
		"Enemy-reveal cadence must use the central 0.35-second value.",
		failures
	)
	_expect(
		is_equal_approx(
			float(screen.call("_cadence_seconds", CADENCE_ALERT_TRIGGERED)),
			0.40
		),
		"Alert cadence must use the central 0.40-second value.",
		failures
	)

	# One chain retains only its highest-priority meaningful event.
	screen.set("_pending_movement_cadence_event", CADENCE_NONE)
	screen.call("_set_pending_movement_cadence", CADENCE_ACTIVATION_HANDOFF)
	screen.call("_set_pending_movement_cadence", CADENCE_AI_MOVE_TO_ATTACK)
	screen.call("_set_pending_movement_cadence", CADENCE_ALERT_TRIGGERED)
	_expect(
		int(screen.get("_pending_movement_cadence_event")) == CADENCE_ALERT_TRIGGERED,
		"A combined event chain must retain one highest-priority cadence event.",
		failures
	)

	var unit_views: Dictionary = screen.get("_unit_views")
	var marauder_view := unit_views.get(marauder.unit_id) as TacticalUnitView
	if marauder_view != null:
		marauder_view.call("play_active_handoff_pulse")
		_expect(
			float(marauder_view.get("_active_handoff_pulse_progress")) < 1.0,
			"The active-unit handoff pulse must begin without changing tactical state.",
			failures
		)

	screen.call("_on_board_right_clicked", replacement_destination)
	screen.queue_free()
	await tree.process_frame
	return failures


static func _detection_signature(preview: MovementDetectionPreview) -> String:
	if preview == null:
		return ""
	var parts: PackedStringArray = []
	for tile_preview: MovementDetectionTilePreview in preview.tile_previews:
		parts.append(
			"%d,%d:%s"
			% [
				tile_preview.tile.x,
				tile_preview.tile.y,
				tile_preview.display_percent(),
			]
		)
	return ";".join(parts)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
