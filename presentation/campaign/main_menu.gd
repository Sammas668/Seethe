class_name SeetheMainMenu
extends Control

signal new_campaign_requested
signal load_campaign_requested
signal region_authoring_requested

var _load_button: Button
var _status_label: Label
var _settings_panel: PanelContainer
var _display_mode_button: Button
var _new_campaign_confirmation: ConfirmationDialog
var _has_save: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()


func configure(has_save: bool, status_message: String = "") -> void:
	_has_save = has_save
	if _load_button != null:
		_load_button.disabled = not has_save
	if _status_label != null:
		_status_label.text = status_message


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var base := ColorRect.new()
	base.color = Color("090b0c")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(base)

	var background_fill := TextureRect.new()
	background_fill.texture = load("res://assets/ui/backgrounds/main_menu_background.png") as Texture2D
	background_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_fill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_fill.modulate = Color(1, 1, 1, 0.34)
	root.add_child(background_fill)

	var background_fill_shade := ColorRect.new()
	background_fill_shade.color = Color(0, 0, 0, 0.58)
	background_fill_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background_fill_shade)

	var background_art := TextureRect.new()
	background_art.texture = load("res://assets/ui/backgrounds/main_menu_background.png") as Texture2D
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_art.modulate = Color(1, 1, 1, 0.96)
	root.add_child(background_art)

	var background_art_shade := ColorRect.new()
	background_art_shade.color = Color(0, 0, 0, 0.24)
	background_art_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background_art_shade)

	var title_block := VBoxContainer.new()
	title_block.position = Vector2(90, 110)
	title_block.size = Vector2(620, 300)
	root.add_child(title_block)
	var title := Label.new()
	title.text = "SEETHE"
	title.add_theme_font_size_override("font_size", 74)
	title.add_theme_color_override("font_color", Color("c7a55b"))
	title_block.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE FIFTH RETURNS"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("8d353f"))
	title_block.add_child(subtitle)
	var line := HSeparator.new()
	line.custom_minimum_size = Vector2(480, 16)
	title_block.add_child(line)
	var quote := Label.new()
	quote.text = "Take what can be carried. End what should not endure."
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(500, 80)
	quote.add_theme_font_size_override("font_size", 18)
	quote.add_theme_color_override("font_color", Color("b9b2a1"))
	title_block.add_child(quote)

	var menu_panel := PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu_panel.position = Vector2(-410, -205)
	menu_panel.size = Vector2(330, 410)
	root.add_child(menu_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	menu_panel.add_child(menu)
	var header := Label.new()
	header.text = "CAMPAIGN"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	menu.add_child(header)
	menu.add_child(HSeparator.new())
	menu.add_child(_menu_button("NEW CAMPAIGN", _on_new_campaign))
	_load_button = _menu_button("LOAD CAMPAIGN", _on_load_campaign)
	menu.add_child(_load_button)
	menu.add_child(_menu_button("SETTINGS", _toggle_settings))
	if bool(ProjectSettings.get_setting("seethe/development/enable_region_authoring", false)):
		menu.add_child(_menu_button("REGION AUTHORING", _on_region_authoring))
	menu.add_child(_menu_button("QUIT", _on_quit))
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(290, 64)
	_status_label.add_theme_color_override("font_color", Color("c9bfa8"))
	menu.add_child(_status_label)

	_build_settings_panel(root)
	_build_new_campaign_confirmation(root)


func _menu_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(290, 48)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	return button


func _build_settings_panel(parent: Control) -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-210, -130)
	_settings_panel.size = Vector2(420, 260)
	_settings_panel.visible = false
	parent.add_child(_settings_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(content)
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	_display_mode_button = Button.new()
	_display_mode_button.pressed.connect(_toggle_display_mode)
	content.add_child(_display_mode_button)
	_update_display_mode_text()
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(_toggle_settings)
	content.add_child(close)


func _build_new_campaign_confirmation(parent: Control) -> void:
	_new_campaign_confirmation = ConfirmationDialog.new()
	_new_campaign_confirmation.title = "Replace Campaign"
	_new_campaign_confirmation.dialog_text = (
		"Creating a new campaign will replace the current campaign save. "
		+ "The previous current save will remain as the repository backup until the new campaign saves again."
	)
	_new_campaign_confirmation.confirmed.connect(_confirm_new_campaign)
	parent.add_child(_new_campaign_confirmation)


func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible


func _toggle_display_mode() -> void:
	var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	_update_display_mode_text()


func _update_display_mode_text() -> void:
	if _display_mode_button == null:
		return
	var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_display_mode_button.text = "DISPLAY: FULLSCREEN" if is_fullscreen else "DISPLAY: WINDOWED"


func _on_new_campaign() -> void:
	if _has_save and _new_campaign_confirmation != null:
		_new_campaign_confirmation.popup_centered(Vector2i(560, 220))
		return
	_confirm_new_campaign()


func _confirm_new_campaign() -> void:
	new_campaign_requested.emit()


func _on_load_campaign() -> void:
	load_campaign_requested.emit()


func _on_region_authoring() -> void:
	region_authoring_requested.emit()


func _on_quit() -> void:
	get_tree().quit()
