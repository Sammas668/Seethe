extends Control

const FORMATTER_SCRIPT: Script = preload(
	"res://presentation/tactical/combat_log/tactical_event_formatter.gd"
)

const FILTER_ALL: StringName = &"all"
const FILTER_ROLLS: StringName = &"rolls"
const FILTER_COMBAT: StringName = &"combat"
const FILTER_EVENTS: StringName = &"events"

const COLLAPSED_LEFT: float = -350.0
const COLLAPSED_TOP: float = -260.0
const EXPANDED_LEFT: float = -540.0
const EXPANDED_TOP: float = -660.0
const RIGHT_OFFSET: float = -10.0
const BOTTOM_OFFSET: float = -158.0

@onready var _collapsed_panel: PanelContainer = $CollapsedPanel
@onready var _collapsed_title: Label = $CollapsedPanel/Margin/VBox/Header/Title
@onready var _expand_button: Button = $CollapsedPanel/Margin/VBox/Header/ExpandButton
@onready var _recent_entries: VBoxContainer = $CollapsedPanel/Margin/VBox/RecentEntries

@onready var _expanded_panel: PanelContainer = $ExpandedPanel
@onready var _collapse_button: Button = $ExpandedPanel/Margin/VBox/Header/CollapseButton
@onready var _all_button: Button = $ExpandedPanel/Margin/VBox/Filters/AllButton
@onready var _rolls_button: Button = $ExpandedPanel/Margin/VBox/Filters/RollsButton
@onready var _combat_button: Button = $ExpandedPanel/Margin/VBox/Filters/CombatButton
@onready var _events_button: Button = $ExpandedPanel/Margin/VBox/Filters/EventsButton
@onready var _scroll: ScrollContainer = $ExpandedPanel/Margin/VBox/Scroll
@onready var _entries: VBoxContainer = $ExpandedPanel/Margin/VBox/Scroll/Entries

var _journal: RefCounted
var _expanded: bool = false
var _filter_id: StringName = FILTER_ALL
var _unread_count: int = 0
var _pending_journal_events: Array[Dictionary] = []
var _journal_event_flush_scheduled: bool = false
var _expanded_event_ids: Dictionary = {}
var _frame_deferred_event_batches: int = 0
var _incremental_expanded_entries_added: int = 0


func _ready() -> void:
	_expand_button.pressed.connect(toggle_expanded)
	_collapse_button.pressed.connect(collapse)
	_all_button.pressed.connect(_set_filter.bind(FILTER_ALL))
	_rolls_button.pressed.connect(_set_filter.bind(FILTER_ROLLS))
	_combat_button.pressed.connect(_set_filter.bind(FILTER_COMBAT))
	_events_button.pressed.connect(_set_filter.bind(FILTER_EVENTS))
	_apply_layout()
	_refresh_all()


func configure(journal_value: RefCounted) -> void:
	var callback := Callable(self, "_on_event_added")
	if (
		_journal != null
		and _journal.has_signal("event_added")
		and _journal.is_connected("event_added", callback)
	):
		_journal.disconnect("event_added", callback)

	_journal = journal_value

	if (
		_journal != null
		and _journal.has_signal("event_added")
		and not _journal.is_connected("event_added", callback)
	):
		_journal.connect("event_added", callback)

	_unread_count = 0
	_refresh_all()


func toggle_expanded() -> void:
	if _expanded:
		collapse()
	else:
		expand()


func expand() -> void:
	_expanded = true
	_unread_count = 0
	_apply_layout()
	_refresh_all()
	call_deferred("_scroll_to_bottom")


func collapse() -> void:
	_expanded = false
	_apply_layout()
	_refresh_collapsed()


func is_expanded() -> bool:
	return _expanded


func _set_filter(filter_id: StringName) -> void:
	_filter_id = filter_id
	_refresh_filter_buttons()
	_refresh_expanded()
	call_deferred("_scroll_to_bottom")


func _on_event_added(event: Dictionary) -> void:
	# Hidden AI activity remains available to diagnostics and save/replay data,
	# but it must not create player-facing unread counts, label work or a
	# frame-deferred combat-log refresh.
	if StringName(event.get("visibility", &"player")) != &"player":
		return
	if not _expanded:
		_unread_count += 1
	_pending_journal_events.append(event.duplicate(true))
	if _journal_event_flush_scheduled:
		return
	_journal_event_flush_scheduled = true
	_flush_pending_journal_events_after_frame()


func _flush_pending_journal_events_after_frame() -> void:
	# A committed attack begins its hit pulse before journal publication. Wait for
	# one rendered frame before touching log controls so the first vibration frame
	# cannot be held behind label/panel construction.
	await get_tree().process_frame
	_journal_event_flush_scheduled = false
	if _pending_journal_events.is_empty():
		return
	_frame_deferred_event_batches += 1
	var pending: Array = _pending_journal_events.duplicate(true)
	_pending_journal_events.clear()
	_refresh_collapsed()
	if not _expanded:
		return
	for event_value: Variant in pending:
		if event_value is Dictionary:
			_append_expanded_event(event_value)
	call_deferred("_scroll_to_bottom")


func _apply_layout() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = RIGHT_OFFSET
	offset_bottom = BOTTOM_OFFSET

	if _expanded:
		offset_left = EXPANDED_LEFT
		offset_top = EXPANDED_TOP
	else:
		offset_left = COLLAPSED_LEFT
		offset_top = COLLAPSED_TOP

	_collapsed_panel.visible = not _expanded
	_expanded_panel.visible = _expanded


func _refresh_all() -> void:
	_refresh_collapsed()
	_refresh_filter_buttons()
	if _expanded:
		_refresh_expanded()


func _refresh_collapsed() -> void:
	_clear_children(_recent_entries)

	var title := "TACTICAL LOG"
	if _unread_count > 0:
		title += " · %d NEW" % _unread_count
	_collapsed_title.text = title

	var recent: Array = _journal_call(
		"recent_events",
		[3, FILTER_ALL, false],
		[]
	)

	if recent.is_empty():
		var empty_label := _new_compact_label(
			"No committed tactical events yet."
		)
		_recent_entries.add_child(empty_label)
		return

	for event_value: Variant in recent:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var label := _new_compact_label(
			FORMATTER_SCRIPT.summary_text(event)
		)
		_recent_entries.add_child(label)


func _refresh_expanded() -> void:
	_clear_children(_entries)
	_expanded_event_ids.clear()

	var events: Array = _journal_call(
		"events",
		[_filter_id, false],
		[]
	)

	if events.is_empty():
		_add_expanded_empty_label()
		return

	for event_value: Variant in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		_register_expanded_event(event)
		_entries.add_child(_build_event_entry(event))


func _append_expanded_event(event: Dictionary) -> void:
	if not _event_matches_current_filter(event):
		return
	var event_id: StringName = StringName(event.get("event_id", &""))
	if not event_id.is_empty() and _expanded_event_ids.has(event_id):
		return
	_remove_expanded_empty_label()
	_register_expanded_event(event)
	_entries.add_child(_build_event_entry(event))
	_incremental_expanded_entries_added += 1


func _register_expanded_event(event: Dictionary) -> void:
	var event_id: StringName = StringName(event.get("event_id", &""))
	if not event_id.is_empty():
		_expanded_event_ids[event_id] = true


func _event_matches_current_filter(event: Dictionary) -> bool:
	if StringName(event.get("visibility", &"player")) != &"player":
		return false
	if _filter_id == FILTER_ALL:
		return true
	var category: StringName = StringName(event.get("category", &"events"))
	if _filter_id == FILTER_ROLLS:
		var rolls: Array = event.get("roll_records", [])
		return category == FILTER_ROLLS or not rolls.is_empty()
	if _filter_id == FILTER_COMBAT:
		return category == FILTER_COMBAT
	if _filter_id == FILTER_EVENTS:
		return category == FILTER_EVENTS
	return category == _filter_id


func _add_expanded_empty_label() -> void:
	var empty_label := Label.new()
	empty_label.name = "EmptyEventLabel"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.text = "No entries match this filter."
	_entries.add_child(empty_label)


func _remove_expanded_empty_label() -> void:
	var empty_label: Node = _entries.get_node_or_null("EmptyEventLabel")
	if empty_label == null:
		return
	_entries.remove_child(empty_label)
	empty_label.queue_free()


func _build_event_entry(event: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var summary_row := HBoxContainer.new()
	summary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_theme_constant_override("separation", 6)
	box.add_child(summary_row)

	var summary_label := Label.new()
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.text = FORMATTER_SCRIPT.summary_text(event)
	summary_label.tooltip_text = summary_label.text
	summary_row.add_child(summary_label)

	var toggle_button := Button.new()
	toggle_button.custom_minimum_size = Vector2(30.0, 28.0)
	toggle_button.text = "▶"
	toggle_button.tooltip_text = "Show full roll and event details."
	summary_row.add_child(toggle_button)

	var details_label := Label.new()
	details_label.visible = false
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.79, 0.84, 1.0)
	)
	details_label.add_theme_font_size_override("font_size", 11)
	details_label.text = FORMATTER_SCRIPT.details_text(event)
	box.add_child(details_label)

	toggle_button.pressed.connect(
		_toggle_entry_details.bind(details_label, toggle_button)
	)
	return panel


func _toggle_entry_details(
		details_label: Label,
		toggle_button: Button
) -> void:
	if details_label == null or toggle_button == null:
		return
	details_label.visible = not details_label.visible
	toggle_button.text = "▼" if details_label.visible else "▶"
	toggle_button.tooltip_text = (
		"Hide full roll and event details."
		if details_label.visible
		else "Show full roll and event details."
	)
	call_deferred("_scroll_to_bottom")


func _refresh_filter_buttons() -> void:
	_all_button.button_pressed = _filter_id == FILTER_ALL
	_rolls_button.button_pressed = _filter_id == FILTER_ROLLS
	_combat_button.button_pressed = _filter_id == FILTER_COMBAT
	_events_button.button_pressed = _filter_id == FILTER_EVENTS


func _new_compact_label(label_text: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0.0, 17.0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override(
		"font_color",
		Color(0.78, 0.84, 0.88, 1.0)
	)
	label.add_theme_font_size_override("font_size", 11)
	label.text = label_text
	label.tooltip_text = label_text
	return label


func performance_snapshot() -> Dictionary:
	return {
		"pending_journal_events": _pending_journal_events.size(),
		"frame_deferred_event_batches": _frame_deferred_event_batches,
		"incremental_expanded_entries_added": (
			_incremental_expanded_entries_added
		),
	}


func _journal_call(
		method_name: String,
		arguments: Array,
		fallback: Variant
) -> Variant:
	if _journal == null or not _journal.has_method(method_name):
		return fallback
	return _journal.callv(method_name, arguments)


func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		_scroll.scroll_vertical = int(bar.max_value)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
