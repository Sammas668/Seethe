class_name ProductionScreenController
extends RefCounted


var _host
var _selected_recipe_id: StringName = &""
var _quantity: int = 1


func _init(host) -> void:
	_host = host


func build() -> void:
	var campaign: CampaignState = _host._campaign()
	if campaign == null:
		_host._workspace.add_child(_host._body_label("No campaign Production is available."))
		return
	var root: Control = _host._build_management_canvas("res://assets/strategic/stronghold/facilities/workshop.svg")
	var margin: MarginContainer = _host._management_margin(root, 16, 16, 12, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var allocation: Dictionary = _host._campaign_session.workforce_assignment_snapshot()
	var personnel: Dictionary = _host._campaign_session.personnel_capacity_snapshot()
	var projects: Array[Dictionary] = _host._campaign_session.production_projects()
	var running_count: int = 0
	for snapshot: Dictionary in projects:
		if not bool(snapshot.get("paused", true)):
			running_count += 1
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var title: Label = _host._heading_label("PRODUCTION")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var workforce_summary := Label.new()
	workforce_summary.text = "WORKERS %d / %d ASSIGNED    FREE %d    POSITIONS %d    RUNNING %d / %d" % [
		int(allocation.get("assigned", 0)),
		int(allocation.get("owned", 0)),
		int(allocation.get("free", 0)),
		int(allocation.get("positions", 0)),
		running_count,
		int(allocation.get("slots", allocation.get("positions", 0))),
	]
	workforce_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	workforce_summary.add_theme_font_size_override("font_size", 13)
	header.add_child(workforce_summary)
	var personnel_label := Label.new()
	personnel_label.text = "PERSONNEL %d / %d" % [
		int(personnel.get("used", 0)),
		int(personnel.get("maximum", 0)),
	]
	personnel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	personnel_label.add_theme_font_size_override("font_size", 13)
	header.add_child(personnel_label)
	var workforce_button := Button.new()
	workforce_button.text = "WORKFORCE"
	workforce_button.custom_minimum_size = Vector2(104, 34)
	workforce_button.pressed.connect(func() -> void:
		_host._roster_mode = &"workforce"
		_host._show_screen(&"roster")
	)
	header.add_child(workforce_button)

	# The catalogue, selected recipe and project queue now share the full available
	# height. The queue is always visible and independently scrollable rather than
	# being pushed below the 720p viewport by the recipe details above it.
	var board := HBoxContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 10)
	column.add_child(board)

	var available_panel := PanelContainer.new()
	available_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	available_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	available_panel.size_flags_stretch_ratio = 0.82
	available_panel.custom_minimum_size.x = 245
	board.add_child(available_panel)
	var available_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		available_margin.add_theme_constant_override("margin_" + side, 9)
	available_panel.add_child(available_margin)
	var available_column := VBoxContainer.new()
	available_column.add_theme_constant_override("separation", 6)
	available_margin.add_child(available_column)
	available_column.add_child(_host._heading_label("PRODUCTION CATALOGUE"))
	var available_scroll := ScrollContainer.new()
	available_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	available_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	available_column.add_child(available_scroll)
	var recipe_list := VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 5)
	available_scroll.add_child(recipe_list)
	var recipe_entries: Array[Dictionary] = _host._campaign_session.production_available_recipes()
	var recipe_ids: Dictionary = {}
	for entry: Dictionary in recipe_entries:
		var known_recipe: ProductionRecipeDefinition = entry.get("recipe") as ProductionRecipeDefinition
		if known_recipe != null:
			recipe_ids[known_recipe.recipe_id] = true
	if _selected_recipe_id.is_empty() or not recipe_ids.has(_selected_recipe_id):
		_selected_recipe_id = &""
		if not recipe_entries.is_empty():
			var first_recipe: ProductionRecipeDefinition = recipe_entries[0].get("recipe") as ProductionRecipeDefinition
			if first_recipe != null:
				_selected_recipe_id = first_recipe.recipe_id
	if recipe_entries.is_empty():
		recipe_list.add_child(_host._body_label("No Production recipes are currently known."))
	for entry: Dictionary in recipe_entries:
		var recipe_value: ProductionRecipeDefinition = entry.get("recipe") as ProductionRecipeDefinition
		if recipe_value == null:
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = recipe_value.recipe_id == _selected_recipe_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\n%s" % [
			recipe_value.display_name.to_upper(),
			"AVAILABLE" if bool(entry.get("available", false)) else "LOCKED",
		]
		button.tooltip_text = String(entry.get("reason", "Available"))
		var recipe_id: StringName = recipe_value.recipe_id
		button.pressed.connect(func() -> void:
			_selected_recipe_id = recipe_id
			_quantity = 1
			_host.call_deferred("_show_screen", &"production")
		)
		recipe_list.add_child(button)

	var selected_panel := PanelContainer.new()
	selected_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selected_panel.size_flags_stretch_ratio = 1.0
	selected_panel.custom_minimum_size.x = 300
	board.add_child(selected_panel)
	var selected_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		selected_margin.add_theme_constant_override("margin_" + side, 10)
	selected_panel.add_child(selected_margin)
	var selected_scroll := ScrollContainer.new()
	selected_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selected_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selected_margin.add_child(selected_scroll)
	var selected_column := VBoxContainer.new()
	selected_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_column.add_theme_constant_override("separation", 8)
	selected_scroll.add_child(selected_column)
	selected_column.add_child(_host._heading_label("SELECTED PROJECT"))
	var selected_recipe: ProductionRecipeDefinition = (
		_host._campaign_session.production_catalogue.recipe(_selected_recipe_id)
		if _host._campaign_session != null and _host._campaign_session.production_catalogue != null
		else null
	)
	if selected_recipe == null:
		selected_column.add_child(_host._body_label("Select a manufacturing project."))
	else:
		selected_column.add_child(_host._heading_label(selected_recipe.display_name.to_upper()))
		selected_column.add_child(_host._body_label(selected_recipe.description))
		var quantity_row := HBoxContainer.new()
		quantity_row.add_theme_constant_override("separation", 5)
		selected_column.add_child(quantity_row)
		var quantity_label := Label.new()
		quantity_label.text = "QUANTITY"
		quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quantity_row.add_child(quantity_label)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(34, 34)
		minus.disabled = _quantity <= 1
		minus.pressed.connect(func() -> void:
			_quantity = maxi(1, _quantity - 1)
			_host.call_deferred("_show_screen", &"production")
		)
		quantity_row.add_child(minus)
		var quantity_value := LineEdit.new()
		quantity_value.text = str(_quantity)
		quantity_value.alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity_value.custom_minimum_size = Vector2(56, 34)
		quantity_value.max_length = 2
		quantity_value.text_submitted.connect(func(new_text: String) -> void:
			_quantity = clampi(int(new_text), 1, 99)
			_host.call_deferred("_show_screen", &"production")
		)
		quantity_value.focus_exited.connect(func() -> void:
			_quantity = clampi(int(quantity_value.text), 1, 99)
			_host.call_deferred("_show_screen", &"production")
		)
		quantity_row.add_child(quantity_value)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(34, 34)
		plus.disabled = _quantity >= 99
		plus.pressed.connect(func() -> void:
			_quantity = mini(99, _quantity + 1)
			_host.call_deferred("_show_screen", &"production")
		)
		quantity_row.add_child(plus)
		var preview: OperationResult = _host._campaign_session.preview_production_project(
			selected_recipe.recipe_id,
			_quantity,
			&""
		)
		var preview_data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
		selected_column.add_child(_host._heading_label("REQUIREMENTS"))
		var costs: Dictionary = (
			preview_data.get("resource_costs", {}) as Dictionary
			if preview.success
			else selected_recipe.scaled_resource_costs(_quantity)
		)
		var cost_lines: Array[String] = []
		for raw_resource_id: Variant in costs.keys():
			cost_lines.append("%d %s" % [int(costs[raw_resource_id]), String(raw_resource_id).capitalize()])
		cost_lines.sort()
		cost_lines.append("Operational Workshop")
		cost_lines.append("Work required: %d" % selected_recipe.scaled_work(_quantity))
		cost_lines.append("Manufacturing workers: %d–%d" % [selected_recipe.minimum_workers, selected_recipe.maximum_workers])
		selected_column.add_child(_host._body_label("\n".join(cost_lines)))
		if not preview.success:
			var unavailable := Label.new()
			unavailable.text = "UNAVAILABLE: %s" % preview.message
			unavailable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			unavailable.add_theme_color_override("font_color", Color("d97868"))
			selected_column.add_child(unavailable)
		var begin := Button.new()
		begin.text = "ADD TO PRODUCTION QUEUE"
		begin.disabled = not preview.success
		begin.tooltip_text = preview.message
		var begin_recipe_id: StringName = selected_recipe.recipe_id
		begin.pressed.connect(func() -> void:
			_request_begin_production(begin_recipe_id, _quantity)
		)
		selected_column.add_child(begin)

	var queue_panel := PanelContainer.new()
	queue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_panel.size_flags_stretch_ratio = 1.38
	queue_panel.custom_minimum_size.x = 400
	board.add_child(queue_panel)
	var queue_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		queue_margin.add_theme_constant_override("margin_" + side, 9)
	queue_panel.add_child(queue_margin)
	var queue_column := VBoxContainer.new()
	queue_column.add_theme_constant_override("separation", 6)
	queue_margin.add_child(queue_column)
	var queue_header := HBoxContainer.new()
	queue_column.add_child(queue_header)
	var queue_title: Label = _host._heading_label("PRODUCTION QUEUE")
	queue_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_header.add_child(queue_title)
	var queue_count := Label.new()
	queue_count.text = "%d PROJECT%s" % [projects.size(), "" if projects.size() == 1 else "S"]
	queue_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	queue_count.add_theme_font_size_override("font_size", 13)
	queue_header.add_child(queue_count)
	var queue_scroll := ScrollContainer.new()
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_column.add_child(queue_scroll)
	var queue_list := VBoxContainer.new()
	queue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_list.add_theme_constant_override("separation", 6)
	queue_scroll.add_child(queue_list)
	if projects.is_empty():
		queue_list.add_child(_host._body_label("No Production projects are queued. Select a recipe and add it to the queue."))
	for snapshot: Dictionary in projects:
		_build_production_project_row(queue_list, snapshot)



func _build_production_project_row(parent: VBoxContainer, snapshot: Dictionary) -> void:
	var project: ProductionProjectState = snapshot.get("project") as ProductionProjectState
	var recipe_value: ProductionRecipeDefinition = snapshot.get("recipe") as ProductionRecipeDefinition
	if project == null or recipe_value == null:
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 92
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 7)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var name_text: String = recipe_value.display_name
	if project.quantity > 1:
		name_text += " ×%d" % project.quantity
	var assigned: int = int(snapshot.get("workers_assigned", 0))
	var requested: int = project.requested_worker_count
	var paused: bool = bool(snapshot.get("paused", true))
	var time_text: String = "PAUSED"
	if not paused:
		var days: int = maxi(1, int(snapshot.get("time_remaining_days", 1)))
		time_text = "%d DAY%s" % [days, "" if days == 1 else "S"]
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	content.add_child(top_row)
	var name := Label.new()
	name.text = name_text.to_upper()
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color("c5a35b"))
	top_row.add_child(name)
	var time := Label.new()
	time.text = time_text
	time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time.add_theme_font_size_override("font_size", 15)
	time.add_theme_color_override("font_color", Color("d97868") if paused else Color("8fc78f"))
	top_row.add_child(time)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	content.add_child(controls)
	var worker_summary := Label.new()
	worker_summary.text = (
		"WORKERS %d" % assigned
		if assigned == requested
		else "WORKERS %d / %d REQUESTED" % [assigned, requested]
	)
	worker_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worker_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	worker_summary.tooltip_text = (
		String(snapshot.get("pause_reason", ""))
		if paused
		else "The best eligible Manufacturing workers are assigned automatically."
	)
	worker_summary.add_theme_font_size_override("font_size", 13)
	controls.add_child(worker_summary)
	var assign_label := Label.new()
	assign_label.text = "ASSIGN"
	assign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	assign_label.add_theme_font_size_override("font_size", 12)
	controls.add_child(assign_label)
	var project_id: StringName = project.project_id
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(30, 30)
	minus.disabled = requested <= 0
	minus.pressed.connect(func() -> void:
		_request_set_production_workers(project_id, maxi(0, requested - 1))
	)
	controls.add_child(minus)
	var requested_count := Label.new()
	requested_count.text = str(requested)
	requested_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	requested_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	requested_count.custom_minimum_size = Vector2(30, 30)
	requested_count.tooltip_text = "Requested workers. The actual assigned count is shown on the left."
	controls.add_child(requested_count)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(30, 30)
	plus.disabled = requested >= recipe_value.maximum_workers
	plus.pressed.connect(func() -> void:
		_request_set_production_workers(project_id, requested + 1)
	)
	controls.add_child(plus)
	var up := Button.new()
	up.text = "▲"
	up.custom_minimum_size = Vector2(30, 30)
	up.tooltip_text = "Move up. Higher-priority projects receive the best workers first."
	up.pressed.connect(func() -> void: _request_move_production_priority(project_id, -1))
	controls.add_child(up)
	var down := Button.new()
	down.text = "▼"
	down.custom_minimum_size = Vector2(30, 30)
	down.tooltip_text = "Move down in priority."
	down.pressed.connect(func() -> void: _request_move_production_priority(project_id, 1))
	controls.add_child(down)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(68, 30)
	cancel.add_theme_font_size_override("font_size", 12)
	cancel.pressed.connect(func() -> void: _request_cancel_production(project_id, recipe_value.display_name))
	controls.add_child(cancel)



func _request_begin_production(recipe_id: StringName, quantity: int) -> void:
	var preview: OperationResult = _host._campaign_session.preview_production_project(recipe_id, quantity, &"")
	if not preview.success:
		_host._show_toast(preview.message, true)
		_host._show_screen(&"production")
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var recipe_value: ProductionRecipeDefinition = data.get("recipe") as ProductionRecipeDefinition
	var dialog := ConfirmationDialog.new()
	dialog.title = "Begin Production"
	dialog.dialog_text = "Queue %s%s? Inputs and output Storage Space will be reserved until completion or cancellation." % [
		recipe_value.display_name if recipe_value != null else "this project",
		" ×%d" % quantity if quantity > 1 else "",
	]
	dialog.ok_button_text = "BEGIN"
	_host.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _host._campaign_session.begin_production_project(recipe_id, quantity, &"")
		_host._show_toast(result.message, not result.success)
		_host._show_screen(&"production")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(600, 280))


func _request_set_production_workers(project_id: StringName, worker_count: int) -> void:
	var result: OperationResult = _host._campaign_session.set_production_workers(project_id, worker_count)
	_host._show_toast(result.message, not result.success)
	_host.call_deferred("_show_screen", &"production")


func _request_move_production_priority(project_id: StringName, direction: int) -> void:
	var result: OperationResult = _host._campaign_session.move_production_priority(project_id, direction)
	_host._show_toast(result.message, not result.success)
	_host.call_deferred("_show_screen", &"production")


func _request_cancel_production(project_id: StringName, project_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Cancel Production"
	dialog.dialog_text = "Cancel %s? Reserved inputs and Storage Space will be released, but completed work will be lost." % project_name
	dialog.ok_button_text = "CANCEL PROJECT"
	_host.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _host._campaign_session.cancel_production_project(project_id)
		_host._show_toast(result.message, not result.success)
		_host._show_screen(&"production")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(600, 260))


func request_item_repair(item_id: StringName, recipe_id: StringName) -> void:
	var preview: OperationResult = _host._campaign_session.preview_production_project(recipe_id, 1, item_id)
	if not preview.success:
		_host._show_toast(preview.message, true)
		_host._show_screen(&"storage")
		return
	var data: Dictionary = preview.data as Dictionary if preview.data is Dictionary else {}
	var recipe_value: ProductionRecipeDefinition = data.get("recipe") as ProductionRecipeDefinition
	var dialog := ConfirmationDialog.new()
	dialog.title = "Queue Item Repair"
	dialog.dialog_text = "Queue %s? The exact destroyed item will remain reserved in Storage and the repaired result will keep the same persistent item ID." % (
		recipe_value.display_name if recipe_value != null else "this repair"
	)
	dialog.ok_button_text = "QUEUE REPAIR"
	_host.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _host._campaign_session.begin_production_project(recipe_id, 1, item_id)
		_host._show_toast(result.message, not result.success)
		if result.success:
			_host._show_screen(&"production")
		else:
			_host._show_screen(&"storage")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(640, 300))
