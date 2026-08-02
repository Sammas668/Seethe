class_name DebugMissionSelector
extends Control

signal launch_requested(
	mission_definition: MissionDefinition,
	selected_character_ids: Array[StringName]
)

var _selected_definition: MissionDefinition
var _character_checks: Dictionary = {}
var _mission_title: Label
var _mission_type: Label
var _briefing: RichTextLabel
var _objective_list: RichTextLabel
var _squad_list: VBoxContainer
var _status_label: Label
var _launch_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	var definitions: Array[MissionDefinition] = MissionDefinitionRegistry.all_definitions()
	if definitions.is_empty():
		_status_label.text = "No authored mission definitions were found."
		_launch_button.disabled = true
		return
	_select_definition(definitions[0])


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.02, 0.03, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	margin.add_child(row)

	var mission_panel := PanelContainer.new()
	mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mission_panel)
	var mission_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		mission_margin.add_theme_constant_override("margin_%s" % side, 24)
	mission_panel.add_child(mission_margin)
	var mission_column := VBoxContainer.new()
	mission_column.add_theme_constant_override("separation", 12)
	mission_margin.add_child(mission_column)

	var heading := Label.new()
	heading.text = "STAGE 4.6 · AUTHORED MISSION SELECTOR"
	heading.add_theme_font_size_override("font_size", 16)
	mission_column.add_child(heading)

	_mission_title = Label.new()
	_mission_title.add_theme_font_size_override("font_size", 30)
	mission_column.add_child(_mission_title)
	_mission_type = Label.new()
	mission_column.add_child(_mission_type)

	_briefing = RichTextLabel.new()
	_briefing.bbcode_enabled = true
	_briefing.fit_content = false
	_briefing.custom_minimum_size = Vector2(0, 150)
	mission_column.add_child(_briefing)

	_objective_list = RichTextLabel.new()
	_objective_list.bbcode_enabled = true
	_objective_list.fit_content = false
	_objective_list.custom_minimum_size = Vector2(0, 230)
	_objective_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission_column.add_child(_objective_list)

	var squad_panel := PanelContainer.new()
	squad_panel.custom_minimum_size = Vector2(360, 0)
	row.add_child(squad_panel)
	var squad_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		squad_margin.add_theme_constant_override("margin_%s" % side, 20)
	squad_panel.add_child(squad_margin)
	var squad_column := VBoxContainer.new()
	squad_column.add_theme_constant_override("separation", 12)
	squad_margin.add_child(squad_column)
	var squad_heading := Label.new()
	squad_heading.text = "DEPLOYMENT"
	squad_heading.add_theme_font_size_override("font_size", 22)
	squad_column.add_child(squad_heading)
	var squad_help := Label.new()
	squad_help.text = "Choose the current debug squad. The protagonist is required."
	squad_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	squad_column.add_child(squad_help)
	_squad_list = VBoxContainer.new()
	_squad_list.add_theme_constant_override("separation", 8)
	squad_column.add_child(_squad_list)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	squad_column.add_child(spacer)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	squad_column.add_child(_status_label)
	_launch_button = Button.new()
	_launch_button.text = "LAUNCH FARM RAID"
	_launch_button.custom_minimum_size = Vector2(0, 48)
	_launch_button.pressed.connect(_on_launch_pressed)
	squad_column.add_child(_launch_button)




func prepare_for_display(message: String = "") -> void:
	show()
	_validate_selection()
	if not message.is_empty():
		_status_label.text = message


func report_launch_failure(message: String) -> void:
	prepare_for_display(message)

func _select_definition(definition: MissionDefinition) -> void:
	_selected_definition = definition
	_mission_title.text = definition.display_name
	_mission_type.text = "%s · %s" % [
		String(definition.mission_type).to_upper(),
		definition.map_definition.mission_display_name,
	]
	_briefing.text = "[b]Briefing[/b]\n%s" % definition.briefing_text
	var objective_lines: Array[String] = ["[b]Primary[/b]"]
	for objective: MissionObjectiveDefinition in definition.primary_objectives:
		objective_lines.append("• %s" % objective.display_name)
	objective_lines.append("")
	objective_lines.append("[b]Optional[/b]")
	for objective: MissionObjectiveDefinition in definition.optional_objectives:
		objective_lines.append("• %s" % objective.display_name)
	objective_lines.append("")
	objective_lines.append("[i]Notoriety and XP are structured preview data in Stage 4.6.[/i]")
	_objective_list.text = "\n".join(objective_lines)
	_rebuild_squad_checks()
	_validate_selection()


func _rebuild_squad_checks() -> void:
	for child: Node in _squad_list.get_children():
		child.queue_free()
	_character_checks.clear()
	for character_id: StringName in _selected_definition.player_character_ids:
		var placement := _selected_definition.placement_for_character(character_id)
		var check := CheckBox.new()
		check.text = placement.display_name if placement != null else String(character_id)
		check.button_pressed = true
		check.disabled = character_id == _selected_definition.protagonist_character_id
		check.toggled.connect(func(_pressed: bool) -> void: _validate_selection())
		_squad_list.add_child(check)
		_character_checks[character_id] = check


func _selected_character_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_id: Variant in _character_checks.keys():
		var character_id := StringName(raw_id)
		var check := _character_checks.get(character_id) as CheckBox
		if check != null and check.button_pressed:
			result.append(character_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


func _validate_selection() -> void:
	if _selected_definition == null:
		_launch_button.disabled = true
		return
	var selected: Array[StringName] = _selected_character_ids()
	var errors: Array[String] = _selected_definition.validate_definition()
	if not selected.has(_selected_definition.protagonist_character_id):
		errors.append("The protagonist must deploy.")
	if selected.size() > _selected_definition.maximum_player_deployment:
		errors.append("The mission allows at most %d characters." % _selected_definition.maximum_player_deployment)
	_launch_button.disabled = not errors.is_empty()
	_status_label.text = (
		"Ready: %d/%d selected." % [selected.size(), _selected_definition.maximum_player_deployment]
		if errors.is_empty()
		else errors[0]
	)


func _on_launch_pressed() -> void:
	if _selected_definition == null or _launch_button.disabled:
		return
	_launch_button.disabled = true
	_status_label.text = "Finalising mission setup and assembling the authored map…"
	launch_requested.emit(_selected_definition, _selected_character_ids())
