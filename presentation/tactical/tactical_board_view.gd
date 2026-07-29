class_name TacticalBoardView
extends Node2D

signal tile_hovered(tile: Vector2i)
signal tile_left_clicked(tile: Vector2i)
signal board_right_clicked(tile: Vector2i)

const BOARD_ORIGIN := Vector2(446.0, 48.0)
const TILE_SIZE := 28.0

const FLOOR_COLOR := Color(0.18, 0.21, 0.24, 1.0)
const ALTERNATE_FLOOR_COLOR := Color(0.205, 0.235, 0.265, 1.0)
const GRID_COLOR := Color(0.055, 0.07, 0.085, 0.88)
const BLOCKED_COLOR := Color(0.035, 0.045, 0.055, 1.0)
const DIFFICULT_COLOR := Color(0.40, 0.285, 0.16, 1.0)
const VALID_PATH_COLOR := Color(0.20, 0.76, 0.40, 0.40)
const AMBER_PATH_COLOR := Color(0.95, 0.63, 0.18, 0.42)
const SPRINT_PATH_COLOR := Color(0.78, 0.22, 0.20, 0.40)
const INVALID_PATH_COLOR := Color(0.80, 0.12, 0.13, 0.45)
const HOVER_COLOR := Color(0.94, 0.82, 0.26, 0.30)
const ITEM_COLOR := Color(0.94, 0.70, 0.20, 1.0)
const LEGAL_TARGET_COLOR := Color(0.82, 0.18, 0.16, 0.34)
const SELECTED_TARGET_COLOR := Color(1.0, 0.72, 0.14, 0.48)
const INVALID_TARGET_COLOR := Color(0.78, 0.08, 0.08, 0.50)
const TARGET_OUTLINE_COLOR := Color(1.0, 0.84, 0.32, 1.0)

var _map_definition: TacticalMapDefinition
var _facade
var _selected_unit_id: StringName = &""
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _preview_result: MovementPathResult
var _movement_mode: StringName = &"normal"
var _attack_targeting: bool = false
var _legal_attack_target_ids: Array[StringName] = []
var _selected_attack_target_id: StringName = &""
var _input_enabled: bool = true


func configure(
		map_definition: TacticalMapDefinition,
		facade
) -> void:
	_map_definition = map_definition
	_facade = facade
	queue_redraw()


func board_origin() -> Vector2:
	return BOARD_ORIGIN


func tile_size() -> float:
	return TILE_SIZE


func set_input_enabled(value: bool) -> void:
	_input_enabled = value


func update_presentation(
		selected_unit_id: StringName,
		hovered_tile: Vector2i,
		preview_result: MovementPathResult,
		movement_mode: StringName,
		attack_targeting: bool = false,
		legal_attack_target_ids: Array[StringName] = [],
		selected_attack_target_id: StringName = &""
) -> void:
	_selected_unit_id = selected_unit_id
	_hovered_tile = hovered_tile
	_preview_result = preview_result
	_movement_mode = movement_mode
	_attack_targeting = attack_targeting
	_legal_attack_target_ids = legal_attack_target_ids.duplicate()
	_selected_attack_target_id = selected_attack_target_id
	queue_redraw()


func refresh_board() -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or _map_definition == null:
		return

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		var tile := _screen_to_tile(mouse_event.position)
		if tile != _hovered_tile:
			_hovered_tile = tile
			tile_hovered.emit(tile)
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			tile_left_clicked.emit(_screen_to_tile(mouse_button.position))
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			board_right_clicked.emit(_screen_to_tile(mouse_button.position))


func _draw() -> void:
	if _map_definition == null or _facade == null:
		return
	_draw_board()
	_draw_ground_items()
	_draw_attack_targets()
	_draw_path_preview()
	_draw_selection_outline()


func _draw_board() -> void:
	for y: int in range(_map_definition.grid_size.y):
		for x: int in range(_map_definition.grid_size.x):
			var tile := Vector2i(x, y)
			var rectangle := _tile_rect(tile)
			var fill_color := (
				FLOOR_COLOR
				if (x + y) % 2 == 0
				else ALTERNATE_FLOOR_COLOR
			)

			if _map_definition.is_blocked(tile):
				fill_color = BLOCKED_COLOR
			elif _map_definition.is_difficult(tile):
				fill_color = DIFFICULT_COLOR

			draw_rect(rectangle, fill_color, true)
			draw_rect(rectangle, GRID_COLOR, false, 1.0)

	var board_size := Vector2(_map_definition.grid_size) * TILE_SIZE
	draw_rect(
		Rect2(BOARD_ORIGIN, board_size),
		Color(0.55, 0.61, 0.66, 1.0),
		false,
		2.0
	)


func _draw_ground_items() -> void:
	for item: TacticalItemInstanceState in _facade.state().get_ground_items():
		var centre := tile_to_world(item.location.map_position)
		var points := PackedVector2Array([
			centre + Vector2(0.0, -6.0),
			centre + Vector2(6.0, 0.0),
			centre + Vector2(0.0, 6.0),
			centre + Vector2(-6.0, 0.0),
		])
		draw_colored_polygon(points, ITEM_COLOR)
		draw_polyline(
			PackedVector2Array([
				points[0], points[1], points[2], points[3], points[0]
			]),
			Color(0.20, 0.12, 0.03, 1.0),
			1.5
		)


func _draw_attack_targets() -> void:
	if not _attack_targeting:
		return
	for target_id: StringName in _legal_attack_target_ids:
		var target: TacticalUnitState = _facade.state().get_unit(target_id)
		if target == null:
			continue
		var fill_color: Color = (
			SELECTED_TARGET_COLOR
			if target_id == _selected_attack_target_id
			else LEGAL_TARGET_COLOR
		)
		_draw_target_cells(target, fill_color)

	if (
		not _selected_attack_target_id.is_empty()
		and not _legal_attack_target_ids.has(_selected_attack_target_id)
	):
		var invalid_target: TacticalUnitState = _facade.state().get_unit(
			_selected_attack_target_id
		)
		if invalid_target != null:
			_draw_target_cells(invalid_target, INVALID_TARGET_COLOR)


func _draw_target_cells(unit: TacticalUnitState, fill_color: Color) -> void:
	for cell: Vector2i in _facade.state().occupied_cells_for_unit(unit):
		draw_rect(_tile_rect(cell).grow(-1.0), fill_color, true)
		draw_rect(
			_tile_rect(cell).grow(-2.0),
			TARGET_OUTLINE_COLOR,
			false,
			2.0
		)


func _draw_path_preview() -> void:
	if _attack_targeting and not _selected_attack_target_id.is_empty():
		return
	if _selected_unit_id.is_empty() or _hovered_tile.x < 0:
		return
	if not _facade.state().phase_state.is_player_phase():
		return

	if _preview_result == null or not _preview_result.success:
		if _map_definition.is_inside(_hovered_tile):
			draw_rect(_tile_rect(_hovered_tile), INVALID_PATH_COLOR, true)
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return

	var path_color := VALID_PATH_COLOR
	if _movement_mode == &"sprint":
		path_color = SPRINT_PATH_COLOR
	elif _preview_result.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		path_color = INVALID_PATH_COLOR
	else:
		var half_cost: int = _facade.half_action_cost_feet(unit.unit_id)
		var remaining_after := (
			unit.action_budget.remaining_turn_capacity_feet
			- _preview_result.cost_feet
		)
		if remaining_after < half_cost:
			path_color = AMBER_PATH_COLOR

	for index: int in range(1, _preview_result.path.size()):
		draw_rect(_tile_rect(_preview_result.path[index]), path_color, true)

	if _map_definition.is_inside(_hovered_tile):
		draw_rect(_tile_rect(_hovered_tile), HOVER_COLOR, true)


func _draw_selection_outline() -> void:
	if _selected_unit_id.is_empty():
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return

	for cell: Vector2i in _facade.state().occupied_cells_for_unit(unit):
		draw_rect(
			_tile_rect(cell).grow(-2.0),
			Color(1.0, 0.82, 0.22, 1.0),
			false,
			3.0
		)


func tile_to_world(tile: Vector2i) -> Vector2:
	return (
		BOARD_ORIGIN
		+ Vector2(tile) * TILE_SIZE
		+ Vector2.ONE * (TILE_SIZE * 0.5)
	)


func _screen_to_tile(screen_position: Vector2) -> Vector2i:
	var local_position := screen_position - BOARD_ORIGIN
	return Vector2i(
		int(floor(local_position.x / TILE_SIZE)),
		int(floor(local_position.y / TILE_SIZE))
	)


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(
		BOARD_ORIGIN + Vector2(tile) * TILE_SIZE,
		Vector2.ONE * TILE_SIZE
	)
