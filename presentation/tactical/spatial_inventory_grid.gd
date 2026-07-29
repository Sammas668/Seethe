class_name SpatialInventoryGrid
extends Control

signal item_activated(
	item_control: SpatialInventoryItemControl,
	mouse_button: int
)
signal transfer_requested(
	source_kind: StringName,
	source_item_id: StringName,
	target_kind: StringName,
	target_cell_index: int
)
signal empty_cell_activated(
	target_kind: StringName,
	target_cell_index: int
)

var container_kind: StringName = &""
var grid_width: int = 1
var grid_height: int = 1
var cell_size: Vector2 = Vector2(44.0, 44.0)
var selected_item_id: StringName = &""

var _occupied_cells: Dictionary = {}
var _item_controls: Array[SpatialInventoryItemControl] = []
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _drag_footprint: Vector2i = Vector2i.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	queue_redraw()


func configure(
		container_kind_value: StringName,
		width_value: int,
		height_value: int,
		cell_size_value: Vector2
) -> void:
	container_kind = container_kind_value
	grid_width = maxi(1, width_value)
	grid_height = maxi(1, height_value)
	cell_size = cell_size_value
	custom_minimum_size = Vector2(
		grid_width * cell_size.x,
		grid_height * cell_size.y
	)
	queue_redraw()


func render_inventory_items(
		items: Array[TacticalItemInstanceState]
) -> void:
	_clear_items()

	for item: TacticalItemInstanceState in items:
		_add_item_control(
			item.item_id,
			item.compact_display_name(),
			item.footprint,
			item.location.grid_position,
			item.definition.tactical_visual_category if item.definition != null else &"misc"
		)

	queue_redraw()


func render_ground_items(items: Array[TacticalItemInstanceState]) -> void:
	_clear_items()

	for ground_item: TacticalItemInstanceState in items:
		var position := _first_display_fit(ground_item.footprint)
		if position.x < 0:
			continue

		_add_item_control(
			ground_item.item_id,
			ground_item.compact_display_name(),
			ground_item.footprint,
			position,
			ground_item.definition.tactical_visual_category if ground_item.definition != null else &"misc"
		)

	queue_redraw()


func set_selected_item(item_id_value: StringName) -> void:
	selected_item_id = item_id_value
	for item_control: SpatialInventoryItemControl in _item_controls:
		item_control.set_selected(item_control.item_id == selected_item_id)


func _draw() -> void:
	var background := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(background, Color(0.035, 0.045, 0.055, 1.0), true)
	draw_rect(background, Color(0.25, 0.31, 0.35, 1.0), false, 2.0)

	for x: int in range(grid_width + 1):
		var x_position := x * cell_size.x
		draw_line(
			Vector2(x_position, 0.0),
			Vector2(x_position, grid_height * cell_size.y),
			Color(0.19, 0.24, 0.28, 1.0),
			1.0
		)

	for y: int in range(grid_height + 1):
		var y_position := y * cell_size.y
		draw_line(
			Vector2(0.0, y_position),
			Vector2(grid_width * cell_size.x, y_position),
			Color(0.19, 0.24, 0.28, 1.0),
			1.0
		)

	if _hover_cell.x >= 0:
		var valid := _can_fit_at(_hover_cell, _drag_footprint)
		if container_kind == &"ground":
			valid = true

		var colour := (
			Color(0.18, 0.62, 0.34, 0.30)
			if valid
			else Color(0.74, 0.20, 0.18, 0.30)
		)
		var preview_rect := Rect2(
			Vector2(
				_hover_cell.x * cell_size.x,
				_hover_cell.y * cell_size.y
			),
			Vector2(
				_drag_footprint.x * cell_size.x,
				_drag_footprint.y * cell_size.y
			)
		)
		draw_rect(preview_rect, colour, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_cell = _position_to_cell((event as InputEventMouseMotion).position)
		queue_redraw()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _position_to_cell(mouse_event.position)
			if cell.x >= 0 and not _occupied_cells.has(cell):
				empty_cell_activated.emit(
					container_kind,
					_cell_to_index(cell)
				)
				accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = Vector2i(-1, -1)
		queue_redraw()


func _can_drop_data(local_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false

	var footprint_value: Vector2i = data.get("footprint", Vector2i.ONE)
	_drag_footprint = footprint_value
	_hover_cell = _position_to_cell(local_position)
	queue_redraw()

	if container_kind == &"ground":
		return true

	var source_kind := StringName(data.get("source_kind", &""))
	var source_item_id := StringName(data.get("source_item_id", &""))
	var ignore_item_id := (
		source_item_id
		if source_kind == container_kind
		else &""
	)
	return _can_fit_at(_hover_cell, _drag_footprint, ignore_item_id)


func _drop_data(local_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return

	var cell := _position_to_cell(local_position)
	transfer_requested.emit(
		StringName(data.get("source_kind", &"")),
		StringName(data.get("source_item_id", &"")),
		container_kind,
		_cell_to_index(cell)
	)

	_hover_cell = Vector2i(-1, -1)
	queue_redraw()


func _add_item_control(
		item_id: StringName,
		item_name: String,
		footprint: Vector2i,
		grid_position: Vector2i,
		visual_category: StringName = &"misc"
) -> void:
	var item_control := SpatialInventoryItemControl.new()
	add_child(item_control)
	item_control.position = Vector2(
		grid_position.x * cell_size.x + 2.0,
		grid_position.y * cell_size.y + 2.0
	)
	item_control.size = Vector2(
		footprint.x * cell_size.x - 4.0,
		footprint.y * cell_size.y - 4.0
	)
	item_control.configure(
		container_kind,
		item_id,
		item_name,
		footprint,
		visual_category
	)
	item_control.item_activated.connect(
		func(control: SpatialInventoryItemControl, mouse_button: int) -> void:
			item_activated.emit(control, mouse_button)
	)

	_item_controls.append(item_control)
	_mark_occupied(grid_position, footprint, item_id)


func _mark_occupied(
		grid_position: Vector2i,
		footprint: Vector2i,
		item_id: StringName
) -> void:
	for y: int in range(grid_position.y, grid_position.y + footprint.y):
		for x: int in range(grid_position.x, grid_position.x + footprint.x):
			_occupied_cells[Vector2i(x, y)] = item_id


func _first_display_fit(footprint: Vector2i) -> Vector2i:
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var candidate := Vector2i(x, y)
			if _can_fit_at(candidate, footprint):
				return candidate
	return Vector2i(-1, -1)


func _can_fit_at(
		grid_position: Vector2i,
		footprint: Vector2i,
		ignore_item_id: StringName = &""
) -> bool:
	if grid_position.x < 0 or grid_position.y < 0:
		return false
	if grid_position.x + footprint.x > grid_width:
		return false
	if grid_position.y + footprint.y > grid_height:
		return false

	for y: int in range(grid_position.y, grid_position.y + footprint.y):
		for x: int in range(grid_position.x, grid_position.x + footprint.x):
			var cell := Vector2i(x, y)
			if _occupied_cells.has(cell):
				var occupying_item: StringName = _occupied_cells[cell]
				if occupying_item != ignore_item_id:
					return false
	return true


func _position_to_cell(local_position: Vector2) -> Vector2i:
	var cell := Vector2i(
		int(floor(local_position.x / cell_size.x)),
		int(floor(local_position.y / cell_size.y))
	)

	if cell.x < 0 or cell.y < 0:
		return Vector2i(-1, -1)
	if cell.x >= grid_width or cell.y >= grid_height:
		return Vector2i(-1, -1)
	return cell


func _cell_to_index(cell: Vector2i) -> int:
	if cell.x < 0:
		return -1
	return cell.y * grid_width + cell.x


func _clear_items() -> void:
	_occupied_cells.clear()
	_item_controls.clear()

	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
