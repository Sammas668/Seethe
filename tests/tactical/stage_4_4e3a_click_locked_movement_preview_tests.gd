class_name Stage44e3aClickLockedMovementPreviewTests
extends RefCounted

const SCREEN_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)
const NONE_INTENT: int = 0
const MOVE_PREVIEW_INTENT: int = 1
const INVALID_TILE: Vector2i = Vector2i(-1, -1)


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var screen = SCREEN_SCENE.instantiate()
	screen.call("configure", session)
	tree.root.add_child(screen)
	await tree.process_frame

	var unit: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	if unit == null:
		failures.append("The click-locked movement fixture requires the Marauder.")
		screen.queue_free()
		await tree.process_frame
		return failures

	var destinations: Array[Vector2i] = _legal_nearby_destinations(session, unit, 2)
	if destinations.size() < 2:
		failures.append("The click-locked movement fixture requires two legal empty destinations.")
		screen.queue_free()
		await tree.process_frame
		return failures

	var first_destination: Vector2i = destinations[0]
	var second_destination: Vector2i = destinations[1]
	var starting_position: Vector2i = unit.grid_position
	screen.call("_select_unit", unit.unit_id)
	screen.set("_hover_preview_build_count", 0)
	screen.set("_hover_hud_refresh_count", 0)
	screen.set("_hover_board_refresh_count", 0)

	# Hover is highlight-only and state revalidation must not turn that hover into
	# a movement path.
	screen.call("_on_board_tile_hovered", first_destination)
	_expect(
		int(screen.get("_hover_preview_build_count")) == 0,
		"Hovering an empty tile must not build a movement preview.",
		failures
	)
	_expect(
		int(screen.get("_board_intent_mode")) == NONE_INTENT,
		"Hovering must not enter MOVE_PREVIEW intent.",
		failures
	)
	_expect(
		screen.get("_preview_result") == null,
		"Hovering must not display a movement path.",
		failures
	)
	_expect(
		int(screen.get("_hover_hud_refresh_count")) == 0,
		"Ordinary empty-tile hover must not rebuild the full HUD.",
		failures
	)
	_expect(
		int(screen.get("_hover_board_refresh_count")) == 1,
		"A changed hover tile should request exactly one board redraw.",
		failures
	)
	var builds_before_revalidation: int = int(
		screen.get("_hover_preview_build_count")
	)
	screen.call("_refresh_path_preview")
	_expect(
		int(screen.get("_hover_preview_build_count")) == builds_before_revalidation,
		"Path revalidation must not manufacture a preview from the hovered tile.",
		failures
	)

	# The first click builds and locks a path without moving.
	screen.call("_on_board_tile_left_clicked", first_destination)
	var first_preview := screen.get("_preview_result") as MovementPathResult
	_expect(
		int(screen.get("_board_intent_mode")) == MOVE_PREVIEW_INTENT,
		"The first left-click must enter MOVE_PREVIEW intent.",
		failures
	)
	_expect(
		Vector2i(screen.get("_planned_destination")) == first_destination,
		"The first left-click must lock the clicked destination.",
		failures
	)
	_expect(
		first_preview != null
			and first_preview.success
			and not first_preview.path.is_empty()
			and first_preview.path.back() == first_destination,
		"The first left-click must display a successful path to the clicked tile.",
		failures
	)
	_expect(
		unit.grid_position == starting_position,
		"The first left-click must not move the unit.",
		failures
	)
	var locked_path_signature: String = _path_signature(first_preview)
	var builds_after_first_click: int = int(
		screen.get("_hover_preview_build_count")
	)

	# Cursor movement cannot replace the clicked path.
	screen.call("_on_board_tile_hovered", second_destination)
	var preview_after_hover := screen.get("_preview_result") as MovementPathResult
	_expect(
		Vector2i(screen.get("_planned_destination")) == first_destination,
		"Moving the cursor must preserve the locked destination.",
		failures
	)
	_expect(
		_path_signature(preview_after_hover) == locked_path_signature,
		"Moving the cursor must preserve the locked path.",
		failures
	)
	_expect(
		int(screen.get("_hover_preview_build_count")) == builds_after_first_click,
		"Moving the cursor after the first click must not build another path.",
		failures
	)

	# A different first click replaces the preview but still does not move.
	screen.call("_on_board_tile_left_clicked", second_destination)
	_expect(
		Vector2i(screen.get("_planned_destination")) == second_destination,
		"Clicking another legal tile must replace the locked destination.",
		failures
	)
	_expect(
		unit.grid_position == starting_position,
		"Replacing the preview must not move the unit.",
		failures
	)

	# Right-click cancels without movement.
	screen.call("_on_board_right_clicked", second_destination)
	_expect(
		int(screen.get("_board_intent_mode")) == NONE_INTENT,
		"Right-click must cancel MOVE_PREVIEW intent.",
		failures
	)
	_expect(
		Vector2i(screen.get("_planned_destination")) == INVALID_TILE,
		"Cancelling must clear the planned destination.",
		failures
	)
	_expect(
		screen.get("_preview_result") == null,
		"Cancelling must clear the visible path.",
		failures
	)
	_expect(
		unit.grid_position == starting_position,
		"Cancelling must not move the unit.",
		failures
	)

	# Recreate the preview and confirm by clicking the same tile a second time.
	screen.call("_on_board_tile_left_clicked", second_destination)
	_expect(
		unit.grid_position == starting_position,
		"The replacement preview's first click must remain non-mutating.",
		failures
	)
	screen.call("_on_board_tile_left_clicked", second_destination)
	_expect(
		unit.grid_position == second_destination,
		"The second left-click on the same destination must commit movement.",
		failures
	)
	while bool(screen.get("_movement_animation_active")):
		await tree.process_frame

	screen.queue_free()
	await tree.process_frame
	return failures


static func _legal_nearby_destinations(
		session: TacticalSession,
		unit: TacticalUnitState,
		count: int
) -> Array[Vector2i]:
	# Prefer one-step destinations so the confirmation test cannot be interrupted
	# by a door, reveal boundary or other multi-tile movement event.
	var adjacent: Array[Vector2i] = _legal_destinations_with_max_path(
		session,
		unit,
		count,
		2
	)
	if adjacent.size() >= count:
		return adjacent
	return _legal_destinations_with_max_path(session, unit, count, 4)


static func _legal_destinations_with_max_path(
		session: TacticalSession,
		unit: TacticalUnitState,
		count: int,
		max_path_size: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for radius: int in range(1, 5):
		for y: int in range(unit.grid_position.y - radius, unit.grid_position.y + radius + 1):
			for x: int in range(unit.grid_position.x - radius, unit.grid_position.x + radius + 1):
				var tile := Vector2i(x, y)
				if tile == unit.grid_position or not session.map_definition.is_inside(tile):
					continue
				if session.state_store.state.get_unit_at_tile(tile, unit.unit_id) != null:
					continue
				var preview: MovementPathResult = session.screen_facade.preview_movement(
					unit.unit_id,
					tile,
					&"normal"
				)
				if (
					preview == null
					or not preview.success
					or preview.path.size() <= 1
					or preview.path.size() > max_path_size
				):
					continue
				result.append(tile)
				if result.size() >= count:
					return result
	return result


static func _path_signature(result: MovementPathResult) -> String:
	if result == null:
		return ""
	var parts: PackedStringArray = []
	for tile: Vector2i in result.path:
		parts.append("%d,%d" % [tile.x, tile.y])
	return ";".join(parts)


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
