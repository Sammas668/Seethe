class_name Stage44e3b1StealthCoverPriorityTests
extends RefCounted


static func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var board := TacticalBoardView.new()
	var risky_tile := Vector2i(8, 9)
	var safe_tile := Vector2i(9, 9)

	_expect(
		not bool(board.call("_tile_has_detection_badge", risky_tile)),
		"A destination without a detection preview must permit its cover shield.",
		failures
	)

	var roll_preview := MovementDetectionPreview.new()
	var roll_tile := MovementDetectionTilePreview.new()
	roll_tile.tile = risky_tile
	roll_tile.requires_roll = true
	roll_tile.avoid_detection_chance_percent = 65
	roll_preview.tile_previews.append(roll_tile)
	board.set("_detection_preview", roll_preview)
	_expect(
		bool(board.call("_tile_has_detection_badge", risky_tile)),
		"A destination Stealth percentage must suppress the cover shield.",
		failures
	)
	_expect(
		not bool(board.call("_tile_has_detection_badge", safe_tile)),
		"A different destination without Stealth risk must retain its cover shield.",
		failures
	)

	var unknown_preview := MovementDetectionPreview.new()
	var unknown_tile := MovementDetectionTilePreview.new()
	unknown_tile.tile = risky_tile
	unknown_tile.requires_roll = true
	unknown_tile.has_unknown_observers = true
	unknown_preview.tile_previews.append(unknown_tile)
	board.set("_detection_preview", unknown_preview)
	_expect(
		bool(board.call("_tile_has_detection_badge", risky_tile)),
		"An unknown-risk question mark must suppress the cover shield.",
		failures
	)

	var automatic_preview := MovementDetectionPreview.new()
	var automatic_tile := MovementDetectionTilePreview.new()
	automatic_tile.tile = risky_tile
	automatic_tile.automatic_detection = true
	automatic_tile.avoid_detection_chance_percent = 0
	automatic_preview.tile_previews.append(automatic_tile)
	board.set("_detection_preview", automatic_preview)
	_expect(
		bool(board.call("_tile_has_detection_badge", risky_tile)),
		"A certain-detection 0% badge must suppress the cover shield.",
		failures
	)

	var inert_preview := MovementDetectionPreview.new()
	var inert_tile := MovementDetectionTilePreview.new()
	inert_tile.tile = risky_tile
	inert_preview.tile_previews.append(inert_tile)
	board.set("_detection_preview", inert_preview)
	_expect(
		not bool(board.call("_tile_has_detection_badge", risky_tile)),
		"A tile record without actual detection risk must not hide the cover shield.",
		failures
	)

	board.free()
	return failures


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
