class_name StrategicSpatialInventoryGrid
extends SpatialInventoryGrid

var _interaction_locked: bool = false
var _lock_reason: String = ""


func set_interaction_locked(locked: bool, reason: String = "") -> void:
	_interaction_locked = locked
	_lock_reason = reason
	mouse_default_cursor_shape = (
		Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_CROSS
	)
	for item_control: SpatialInventoryItemControl in _item_controls:
		item_control.disabled = locked
		item_control.mouse_default_cursor_shape = (
			Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
		)
		if locked and not reason.is_empty():
			item_control.tooltip_text = reason
	tooltip_text = reason if locked else ""
	queue_redraw()


func render_campaign_items(
		items: Array[CampaignItemState],
		catalogue: ContentCatalogue
) -> void:
	_clear_items()
	for item: CampaignItemState in items:
		if item == null or item.location == null:
			continue
		var definition: ItemDefinition = catalogue.item_definition(item.definition_id) if catalogue != null else null
		var footprint := Vector2i.ONE
		var name: String = String(item.definition_id)
		var visual_category: StringName = &"misc"
		if definition != null:
			footprint = definition.inventory_footprint
			name = definition.display_name
			visual_category = definition.tactical_visual_category
		if item.location.is_rotated:
			footprint = Vector2i(footprint.y, footprint.x)
		_add_item_control(
			item.item_id,
			name + (" ×%d" % item.quantity if item.quantity > 1 else ""),
			footprint,
			item.location.grid_position,
			visual_category,
			&"item",
			{},
			definition.fixed_inventory_fixture if definition != null else false,
			item.location.is_rotated
		)
	set_interaction_locked(_interaction_locked, _lock_reason)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _interaction_locked:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			accept_event()
		return
	super._gui_input(event)


func _can_drop_data(local_position: Vector2, data: Variant) -> bool:
	if _interaction_locked:
		return false
	return super._can_drop_data(local_position, data)


func _drop_data(local_position: Vector2, data: Variant) -> void:
	if _interaction_locked:
		return
	super._drop_data(local_position, data)
