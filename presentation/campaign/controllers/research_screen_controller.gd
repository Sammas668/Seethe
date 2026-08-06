class_name ResearchScreenController
extends RefCounted


var _host
var _selected_definition_id: StringName = &""


func _init(host) -> void:
	_host = host


func build() -> void:
	var campaign: CampaignState = _host._campaign()
	if campaign == null:
		_host._workspace.add_child(_host._body_label("No campaign Research is available."))
		return
	var root: Control = _host._build_management_canvas("res://assets/strategic/storage/storage_background.svg")
	var margin: MarginContainer = _host._management_margin(root, 16, 16, 12, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var assignment: Dictionary = _host._campaign_session.research_assignment_snapshot()
	var projects: Array[Dictionary] = _host._campaign_session.research_projects()
	var running_count: int = 0
	for snapshot: Dictionary in projects:
		if not bool(snapshot.get("paused", true)):
			running_count += 1
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var heading: Label = _host._heading_label("ORGANISATIONAL RESEARCH")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var workforce := Label.new()
	workforce.text = "WORKERS %d / %d ASSIGNED    FREE %d    POSITIONS %d    RUNNING %d / %d" % [
		int(assignment.get("assigned", 0)),
		int(assignment.get("owned", 0)),
		int(assignment.get("free", 0)),
		int(assignment.get("positions", 0)),
		running_count,
		int(assignment.get("slots", 0)),
	]
	workforce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	workforce.add_theme_font_size_override("font_size", 13)
	header.add_child(workforce)
	var manage_workers := Button.new()
	manage_workers.text = "WORKFORCE"
	manage_workers.custom_minimum_size = Vector2(104, 34)
	manage_workers.pressed.connect(func() -> void:
		_host._roster_mode = &"workforce"
		_host._show_screen(&"roster")
	)
	header.add_child(manage_workers)

	var entries: Array[Dictionary] = _host._campaign_session.research_entries()
	var visible_ids: Dictionary = {}
	for entry: Dictionary in entries:
		var definition_value: ResearchProjectDefinition = entry.get("definition") as ResearchProjectDefinition
		if definition_value != null:
			visible_ids[definition_value.research_id] = true
	if _selected_definition_id.is_empty() or not visible_ids.has(_selected_definition_id):
		_selected_definition_id = &""
		for entry: Dictionary in entries:
			var definition_value: ResearchProjectDefinition = entry.get("definition") as ResearchProjectDefinition
			if definition_value != null:
				_selected_definition_id = definition_value.research_id
				break

	# Catalogue, selected-project details and the live queue share one full-height
	# row. The queue no longer sits beneath the other panels, so it remains usable
	# at the authored 1280 x 720 viewport and can hold any number of projects.
	var board := HBoxContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 10)
	column.add_child(board)

	var list_panel := PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 0.82
	list_panel.custom_minimum_size.x = 245
	board.add_child(list_panel)
	var list_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		list_margin.add_theme_constant_override("margin_" + side, 9)
	list_panel.add_child(list_margin)
	var list_column := VBoxContainer.new()
	list_column.add_theme_constant_override("separation", 6)
	list_margin.add_child(list_column)
	list_column.add_child(_host._heading_label("RESEARCH CATALOGUE"))
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_column.add_child(list_scroll)
	var project_buttons := VBoxContainer.new()
	project_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_buttons.add_theme_constant_override("separation", 5)
	list_scroll.add_child(project_buttons)
	if entries.is_empty():
		project_buttons.add_child(_host._body_label("No Research projects have been revealed."))
	for entry: Dictionary in entries:
		var definition_value: ResearchProjectDefinition = entry.get("definition") as ResearchProjectDefinition
		if definition_value == null:
			continue
		var state_text: String = "AVAILABLE"
		if bool(entry.get("completed", false)):
			state_text = "COMPLETED"
		elif entry.get("active_project") != null:
			state_text = "IN QUEUE"
		elif not bool(entry.get("available", false)):
			state_text = "LOCKED"
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = definition_value.research_id == _selected_definition_id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\n%s" % [definition_value.display_name.to_upper(), state_text]
		var selected_id: StringName = definition_value.research_id
		button.pressed.connect(func() -> void:
			_selected_definition_id = selected_id
			_host.call_deferred("_show_screen", &"research")
		)
		project_buttons.add_child(button)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 1.0
	detail_panel.custom_minimum_size.x = 300
	board.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		detail_margin.add_theme_constant_override("margin_" + side, 10)
	detail_panel.add_child(detail_margin)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(detail_scroll)
	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(detail_column)
	detail_column.add_child(_host._heading_label("SELECTED RESEARCH"))
	var selected_entry: Dictionary = {}
	for entry: Dictionary in entries:
		var definition_value: ResearchProjectDefinition = entry.get("definition") as ResearchProjectDefinition
		if definition_value != null and definition_value.research_id == _selected_definition_id:
			selected_entry = entry
			break
	if selected_entry.is_empty():
		detail_column.add_child(_host._body_label("Select a revealed Research project."))
	else:
		var definition_value: ResearchProjectDefinition = selected_entry.get("definition") as ResearchProjectDefinition
		detail_column.add_child(_host._heading_label(definition_value.display_name.to_upper()))
		detail_column.add_child(_host._body_label(definition_value.description))
		detail_column.add_child(_host._body_label("BRANCH: %s" % String(definition_value.branch_id).to_upper()))
		var requirement_lines: Array[String] = []
		for prerequisite_id: StringName in definition_value.prerequisite_research_ids:
			var prerequisite: ResearchProjectDefinition = _host._campaign_session.research_catalogue.definition(prerequisite_id)
			requirement_lines.append("Research: %s" % (prerequisite.display_name if prerequisite != null else String(prerequisite_id)))
		for raw_resource_id: Variant in definition_value.resource_costs.keys():
			requirement_lines.append("%d %s" % [int(definition_value.resource_costs[raw_resource_id]), String(raw_resource_id).capitalize()])
		requirement_lines.append("Work required: %d" % definition_value.total_work_required)
		requirement_lines.append("Research workers: %d–%d" % [definition_value.minimum_workers, definition_value.maximum_workers])
		detail_column.add_child(_host._heading_label("REQUIREMENTS"))
		detail_column.add_child(_host._body_label("\n".join(requirement_lines)))
		var unlock_lines: Array[String] = []
		for contact_id: StringName in definition_value.unlocked_contact_ids:
			unlock_lines.append("Shop contact: %s" % _host._display_id(contact_id))
		for recipe_id: StringName in definition_value.unlocked_recipe_ids:
			unlock_lines.append("Production recipe: %s" % _host._display_id(recipe_id))
		for worker_id: StringName in definition_value.unlocked_worker_definition_ids:
			var worker_definition: WorkforceDefinition = _host._campaign_session.workforce_catalogue.definition(worker_id)
			unlock_lines.append("Worker pool: %s" % (worker_definition.display_name if worker_definition != null else _host._display_id(worker_id)))
		for capability_id: StringName in definition_value.granted_capability_ids:
			unlock_lines.append("Capability: %s" % _host._display_id(capability_id))
		if not unlock_lines.is_empty():
			detail_column.add_child(_host._heading_label("UNLOCKS"))
			detail_column.add_child(_host._body_label("\n".join(unlock_lines)))
		if bool(selected_entry.get("completed", false)):
			var completed := Label.new()
			completed.text = "COMPLETED — KNOWLEDGE PERMANENTLY LEARNED"
			completed.add_theme_color_override("font_color", Color("8fc78f"))
			detail_column.add_child(completed)
		elif selected_entry.get("active_project") != null:
			detail_column.add_child(_host._body_label("This project is already in the queue."))
		else:
			var begin := Button.new()
			begin.text = "ADD TO RESEARCH QUEUE"
			begin.disabled = not bool(selected_entry.get("available", false))
			begin.tooltip_text = String(selected_entry.get("reason", ""))
			var research_id: StringName = definition_value.research_id
			begin.pressed.connect(func() -> void: _request_begin_research(research_id))
			detail_column.add_child(begin)
			if begin.disabled:
				var reason := Label.new()
				reason.text = "UNAVAILABLE: %s" % String(selected_entry.get("reason", "Unavailable"))
				reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				reason.add_theme_color_override("font_color", Color("d97868"))
				detail_column.add_child(reason)

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
	var queue_title: Label = _host._heading_label("RESEARCH QUEUE")
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
		queue_list.add_child(_host._body_label("No Research projects are queued. Select a project and add it to the queue."))
	for snapshot: Dictionary in projects:
		_build_research_project_row(queue_list, snapshot)



func _build_research_project_row(parent: VBoxContainer, snapshot: Dictionary) -> void:
	var project: ResearchProjectState = snapshot.get("project") as ResearchProjectState
	var definition_value: ResearchProjectDefinition = snapshot.get("definition") as ResearchProjectDefinition
	if project == null or definition_value == null:
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
	name.text = definition_value.display_name.to_upper()
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
		else "The best eligible Research workers are assigned automatically."
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
		_request_set_research_workers(project_id, maxi(0, requested - 1))
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
	plus.disabled = requested >= definition_value.maximum_workers
	plus.pressed.connect(func() -> void:
		_request_set_research_workers(project_id, requested + 1)
	)
	controls.add_child(plus)
	var up := Button.new()
	up.text = "▲"
	up.custom_minimum_size = Vector2(30, 30)
	up.tooltip_text = "Move up. Higher-priority Research receives the best workers first."
	up.pressed.connect(func() -> void: _request_move_research_priority(project_id, -1))
	controls.add_child(up)
	var down := Button.new()
	down.text = "▼"
	down.custom_minimum_size = Vector2(30, 30)
	down.tooltip_text = "Move down in priority."
	down.pressed.connect(func() -> void: _request_move_research_priority(project_id, 1))
	controls.add_child(down)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(68, 30)
	cancel.add_theme_font_size_override("font_size", 12)
	cancel.pressed.connect(func() -> void: _request_cancel_research(project_id, definition_value.display_name))
	controls.add_child(cancel)



func _request_begin_research(research_id: StringName) -> void:
	var preview: OperationResult = _host._campaign_session.preview_research_project(research_id)
	if not preview.success:
		_host._show_toast(preview.message, true)
		_host._show_screen(&"research")
		return
	var definition_value: ResearchProjectDefinition = _host._campaign_session.research_catalogue.definition(research_id)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Begin Research"
	dialog.dialog_text = "Begin %s? Required resources will be reserved until completion or cancellation." % (
		definition_value.display_name if definition_value != null else "this Research project"
	)
	dialog.ok_button_text = "BEGIN"
	_host.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _host._campaign_session.begin_research_project(research_id)
		_host._show_toast(result.message, not result.success)
		_host._show_screen(&"research")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(620, 280))


func _request_set_research_workers(project_id: StringName, worker_count: int) -> void:
	var result: OperationResult = _host._campaign_session.set_research_workers(project_id, worker_count)
	_host._show_toast(result.message, not result.success)
	_host.call_deferred("_show_screen", &"research")


func _request_move_research_priority(project_id: StringName, direction: int) -> void:
	var result: OperationResult = _host._campaign_session.move_research_priority(project_id, direction)
	_host._show_toast(result.message, not result.success)
	_host.call_deferred("_show_screen", &"research")


func _request_cancel_research(project_id: StringName, project_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Cancel Research"
	dialog.dialog_text = "Cancel %s? Reserved inputs will be released, but completed work will be lost." % project_name
	dialog.ok_button_text = "CANCEL PROJECT"
	_host.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var result: OperationResult = _host._campaign_session.cancel_research_project(project_id)
		_host._show_toast(result.message, not result.success)
		_host._show_screen(&"research")
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(600, 260))


