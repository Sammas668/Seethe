class_name StrategicStorageDropPanel
extends PanelContainer

signal item_drop_requested(item_id: StringName)

var _saved_mouse_filters: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	# Polling is a safety net for cancelled drags so descendant controls are
	# always restored even when no successful drop occurs.
	if not _saved_mouse_filters.is_empty() and not get_viewport().gui_is_dragging():
		_restore_descendant_mouse_filters()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		# During a drag, temporarily make descendants transparent to pointer
		# targeting so the complete Available Equipment panel becomes one large
		# storage return target instead of only its empty margins.
		_saved_mouse_filters.clear()
		_capture_and_ignore_descendants(self)
	elif what == NOTIFICATION_DRAG_END:
		_restore_descendant_mouse_filters()


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var payload := data as Dictionary
	var item_id := StringName(payload.get("source_item_id", ""))
	var source_kind := StringName(payload.get("source_kind", ""))
	return not item_id.is_empty() and source_kind != &"stronghold_storage"


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var item_id := StringName((data as Dictionary).get("source_item_id", ""))
	_restore_descendant_mouse_filters()
	if not item_id.is_empty():
		item_drop_requested.emit(item_id)


func _capture_and_ignore_descendants(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			_saved_mouse_filters.append({
				"control": control,
				"mouse_filter": control.mouse_filter,
			})
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_capture_and_ignore_descendants(child)


func _restore_descendant_mouse_filters() -> void:
	for entry: Dictionary in _saved_mouse_filters:
		var control: Control = entry.get("control") as Control
		if is_instance_valid(control):
			control.mouse_filter = int(entry.get("mouse_filter", Control.MOUSE_FILTER_STOP))
	_saved_mouse_filters.clear()
