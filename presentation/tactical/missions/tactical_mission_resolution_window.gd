class_name TacticalMissionResolutionWindow
extends Control

signal cancelled
signal confirm_requested(zone_id: StringName, tactical_revision: int)
signal continue_requested

var _backdrop: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _details_label: RichTextLabel
var _cancel_button: Button
var _confirm_button: Button
var _continue_button: Button
var _zone_id: StringName = &""
var _preview_tactical_revision: int = -1
var _summary_mode: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	_build_interface()
	hide()


func show_confirmation(
		manifest: TacticalExtractionManifest,
		state: TacticalState,
		setup: MissionSetupSnapshot
) -> void:
	if manifest == null or state == null or setup == null:
		return
	_summary_mode = false
	_zone_id = manifest.zone_id
	_preview_tactical_revision = manifest.source_tactical_revision
	_title_label.text = (
		"COMPLETE MISSION"
		if manifest.required_objectives_complete
		else "CONFIRM WITHDRAWAL"
	)
	_subtitle_label.text = "%s — %s" % [
		setup.mission_display_name,
		MissionOutcome.display_name(manifest.mission_outcome),
	]
	_details_label.text = _confirmation_text(manifest, state, setup)
	_cancel_button.visible = true
	_confirm_button.visible = true
	_continue_button.visible = false
	_confirm_button.text = (
		"CONFIRM VICTORY"
		if manifest.required_objectives_complete
		else "CONFIRM WITHDRAWAL"
	)
	_confirm_button.disabled = not manifest.extraction_is_legal
	show()
	_confirm_button.grab_focus()


func show_summary(
		result: MissionResult,
		campaign: CampaignState,
		setup: MissionSetupSnapshot
) -> void:
	if result == null or setup == null:
		return
	_summary_mode = true
	_zone_id = result.extracted_zone_id
	_preview_tactical_revision = -1
	_title_label.text = MissionOutcome.display_name(result.mission_outcome).to_upper()
	_subtitle_label.text = setup.mission_display_name
	_details_label.text = _summary_text(result, campaign, setup)
	_cancel_button.visible = false
	_confirm_button.visible = false
	_continue_button.visible = true
	show()
	_continue_button.grab_focus()


func is_open() -> bool:
	return visible


func is_summary_open() -> bool:
	return visible and _summary_mode


func is_confirmation_open() -> bool:
	return visible and not _summary_mode


func current_zone_id() -> StringName:
	return _zone_id


func preview_tactical_revision() -> int:
	return _preview_tactical_revision


func close_confirmation() -> void:
	if not visible or _summary_mode:
		return
	hide()
	cancelled.emit()


func _build_interface() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.015, 0.02, 0.025, 0.84)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-340.0, -270.0)
	_panel.size = Vector2(680.0, 540.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.055, 0.068, 0.99)
	panel_style.border_color = Color(0.55, 0.43, 0.22, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.53, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", Color(0.75, 0.84, 0.9, 1.0))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle_label)

	var divider := HSeparator.new()
	column.add_child(divider)

	_details_label = RichTextLabel.new()
	_details_label.bbcode_enabled = true
	_details_label.fit_content = false
	_details_label.scroll_active = true
	_details_label.custom_minimum_size = Vector2(0.0, 390.0)
	_details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details_label.add_theme_font_size_override("normal_font_size", 13)
	_details_label.add_theme_font_size_override("bold_font_size", 14)
	column.add_child(_details_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)

	_cancel_button = Button.new()
	_cancel_button.custom_minimum_size = Vector2(120.0, 38.0)
	_cancel_button.text = "CANCEL"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(180.0, 38.0)
	_confirm_button.text = "CONFIRM"
	_confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_button)

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(150.0, 38.0)
	_continue_button.text = "CONTINUE"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	buttons.add_child(_continue_button)


func _confirmation_text(
		manifest: TacticalExtractionManifest,
		state: TacticalState,
		setup: MissionSetupSnapshot
) -> String:
	var lines: Array[String] = []
	lines.append("[b]Expected outcome[/b]")
	lines.append(MissionOutcome.display_name(manifest.mission_outcome))
	lines.append("")
	lines.append("[b]Primary objective[/b]")
	lines.append(
		"Complete — %s" % setup.primary_objective_text
		if manifest.required_objectives_complete
		else "Incomplete — %s" % setup.primary_objective_text
	)
	lines.append("")
	lines.append("[b]Leaving safely[/b]")
	_append_named_units(lines, manifest.extracted_friendly_unit_ids, state, "Ready")
	_append_named_bodies(lines, manifest.extracted_friendly_body_item_ids, state, "Body")
	_append_named_units(lines, manifest.captured_enemy_unit_ids, state, "Captive")
	if (
		manifest.extracted_friendly_unit_ids.is_empty()
		and manifest.extracted_friendly_body_item_ids.is_empty()
		and manifest.captured_enemy_unit_ids.is_empty()
	):
		lines.append("None")
	lines.append("Recovered persistent items: %d" % manifest.extracted_item_ids.size())
	lines.append("")
	lines.append("[b]Being abandoned[/b]")
	_append_named_units(lines, manifest.abandoned_friendly_unit_ids, state, "Living ally")
	_append_named_bodies(lines, manifest.abandoned_friendly_body_item_ids, state, "Body")
	if manifest.abandoned_item_ids.is_empty():
		lines.append("Persistent items: none")
	else:
		lines.append("Persistent items: %d" % manifest.abandoned_item_ids.size())
	if not manifest.warning_lines.is_empty():
		lines.append("")
		lines.append("[b]Warnings[/b]")
		for warning: String in manifest.warning_lines:
			lines.append("• %s" % warning)
	if not manifest.rejection_reasons.is_empty():
		lines.append("")
		lines.append("[b]Extraction blocked[/b]")
		for reason: String in manifest.rejection_reasons:
			lines.append("• %s" % reason)
	return "\n".join(lines)


func _summary_text(
		result: MissionResult,
		campaign: CampaignState,
		setup: MissionSetupSnapshot
) -> String:
	var lines: Array[String] = []
	lines.append("[b]Objectives[/b]")
	if result.objective_outcomes_by_id.is_empty():
		lines.append(
			"Complete — %s" % setup.primary_objective_text
			if result.completed_objective_ids.has(setup.primary_objective_id)
			else "Failed — %s" % setup.primary_objective_text
		)
	else:
		var objective_ids: Array = result.objective_outcomes_by_id.keys()
		objective_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for raw_objective_id: Variant in objective_ids:
			var entry: Dictionary = result.objective_outcomes_by_id.get(raw_objective_id, {})
			var status: String = String(entry.get("status", "active")).capitalize()
			var optional_text: String = "Optional · " if bool(entry.get("optional", false)) else "Primary · "
			lines.append("• %s%s — %s [%d/%d]" % [
				optional_text,
				String(entry.get("display_name", raw_objective_id)),
				status,
				int(entry.get("current_quantity", 0)),
				int(entry.get("required_quantity", 1)),
			])
			var failure_reason: String = String(entry.get("failure_reason", ""))
			if not failure_reason.is_empty():
				lines.append("  %s" % failure_reason)
	lines.append("")
	lines.append("[b]Personnel[/b]")
	var personnel_count: int = 0
	for character_result: MissionCharacterResult in result.get_character_results():
		if character_result.outcome_state == MissionCharacterResult.OUTCOME_CAPTURED_ENEMY:
			continue
		var source: PersistentCharacterState = setup.get_character(
			character_result.character_id
		)
		var display_name: String = (
			source.display_name if source != null else String(character_result.character_id)
		)
		lines.append("• %s — %s" % [
			display_name,
			MissionCharacterResult.outcome_display_name(character_result.outcome_state),
		])
		personnel_count += 1
	if personnel_count == 0:
		lines.append("None")
	lines.append("")
	lines.append("[b]Captives[/b]")
	var captives: Array[MissionCaptiveResult] = result.get_captive_results()
	if captives.is_empty():
		lines.append("None")
	else:
		for captive: MissionCaptiveResult in captives:
			lines.append("• %s — %s, restrained" % [
				captive.display_name,
				String(captive.condition_at_extraction).capitalize(),
			])
	lines.append("")
	lines.append("[b]Recovery[/b]")
	lines.append("Extracted item instances: %d" % result.extracted_item_entries.size())
	lines.append("Abandoned item instances: %d" % result.abandoned_item_ids.size())
	lines.append("Recovered captives: %d" % captives.size())
	lines.append("")
	lines.append("[b]Mission record[/b]")
	lines.append("Enemies killed: %d" % int(result.mission_statistics.get("enemies_killed", 0)))
	lines.append("Enemies incapacitated: %d" % int(result.mission_statistics.get("enemies_incapacitated", 0)))
	lines.append("Captives taken: %d" % int(result.mission_statistics.get("captives_taken", 0)))
	lines.append("Allies stabilised: %d" % int(result.mission_statistics.get("allies_stabilised", 0)))
	if not result.notoriety_preview_lines.is_empty():
		lines.append("")
		lines.append("[b]Notoriety preview[/b]")
		for line: String in result.notoriety_preview_lines:
			lines.append("• %s" % line)
	if campaign != null:
		lines.append("Campaign revision: %d" % campaign.revision)
	lines.append("")
	lines.append("Mission result ID: %s" % result.result_id)
	return "\n".join(lines)


func _append_named_units(
		lines: Array[String],
		unit_ids: Array[StringName],
		state: TacticalState,
		label: String
) -> void:
	for unit_id: StringName in unit_ids:
		var unit: TacticalUnitState = state.get_unit(unit_id)
		lines.append("• %s — %s" % [
			unit.display_name if unit != null else String(unit_id),
			label,
		])


func _append_named_bodies(
		lines: Array[String],
		body_ids: Array[StringName],
		state: TacticalState,
		label: String
) -> void:
	for body_id: StringName in body_ids:
		var unit: TacticalUnitState = state.body_unit_for_item(body_id)
		lines.append("• %s — %s" % [
			unit.display_name if unit != null else String(body_id),
			label,
		])


func _on_cancel_pressed() -> void:
	close_confirmation()


func _on_confirm_pressed() -> void:
	if _summary_mode or _confirm_button.disabled:
		return
	_confirm_button.disabled = true
	confirm_requested.emit(_zone_id, _preview_tactical_revision)


func _on_continue_pressed() -> void:
	continue_requested.emit()
