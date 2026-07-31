class_name DetectionPreviewQuery
extends RefCounted

const DetectionObserverQuery: Script = preload(
	"res://application/tactical/awareness/detection_observer_query.gd"
)

var _state_store: TacticalStateStore
var _observer_query: DetectionObserverQuery


func configure(
		state_store: TacticalStateStore,
		observer_query: DetectionObserverQuery
) -> void:
	_state_store = state_store
	_observer_query = observer_query


func preview_for_path(
		unit_id: StringName,
		path: Array[Vector2i]
) -> MovementDetectionPreview:
	var preview := MovementDetectionPreview.new()
	var unit: TacticalUnitState = _unit(unit_id)
	if unit == null or unit.team_id != &"player" or path.size() <= 1:
		return preview

	preview.stealth_bonus = unit.stealth_bonus()
	for index: int in range(1, path.size()):
		var tile: Vector2i = path[index]
		var exposures: Array[Dictionary] = (
			_observer_query.collect_tile_exposures(unit, tile, index)
		)
		if exposures.is_empty():
			continue
		var tile_preview: MovementDetectionTilePreview = (
			_build_tile_preview(unit, tile, index, exposures)
		)
		preview.tile_previews.append(tile_preview)
		_aggregate_tile_preview(preview, tile_preview)

	if preview.tile_previews.is_empty():
		return preview
	preview.relevant_observer_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	preview.reason = (
		"Movement crosses %d tile%s requiring Stealth checks."
		% [
			preview.tile_previews.size(),
			"" if preview.tile_previews.size() == 1 else "s",
		]
	)
	return preview


func _build_tile_preview(
		unit: TacticalUnitState,
		tile: Vector2i,
		path_index: int,
		exposures: Array[Dictionary]
) -> MovementDetectionTilePreview:
	var tile_preview := MovementDetectionTilePreview.new()
	tile_preview.tile = tile
	tile_preview.path_index = path_index
	var highest_dc: int = 1
	for exposure: Dictionary in exposures:
		var observer: TacticalUnitState = exposure.get("observer") as TacticalUnitState
		if observer == null:
			continue
		var dc: int = int(exposure.get("dc", 1))
		var observer_known: bool = _observer_query.observer_known_to_player(
			observer
		)
		if observer_known:
			_append_unique(tile_preview.relevant_observer_ids, observer.unit_id)
		else:
			tile_preview.has_unknown_observers = true
		if dc > highest_dc:
			highest_dc = dc
			tile_preview.primary_observer_id = (
				observer.unit_id if observer_known else &""
			)
		tile_preview.automatic_detection = (
			tile_preview.automatic_detection
			or bool(exposure.get("automatic", false))
		)
	tile_preview.relevant_observer_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	tile_preview.effective_detection_dc = highest_dc
	if tile_preview.automatic_detection:
		tile_preview.avoid_detection_chance_percent = 0
		return tile_preview
	tile_preview.requires_roll = true
	tile_preview.avoid_detection_chance_percent = (
		TacticalPerceptionRules.avoid_detection_chance_percent(
			unit.stealth_bonus(),
			highest_dc
		)
	)
	return tile_preview


func _aggregate_tile_preview(
		preview: MovementDetectionPreview,
		tile_preview: MovementDetectionTilePreview
) -> void:
	if preview.first_exposure_tile == Vector2i(-1, -1):
		preview.first_exposure_tile = tile_preview.tile
	preview.requires_roll = preview.requires_roll or tile_preview.requires_roll
	preview.automatic_detection = (
		preview.automatic_detection or tile_preview.automatic_detection
	)
	preview.has_unknown_observers = (
		preview.has_unknown_observers or tile_preview.has_unknown_observers
	)
	if tile_preview.effective_detection_dc > preview.effective_detection_dc:
		preview.effective_detection_dc = tile_preview.effective_detection_dc
		preview.primary_observer_id = tile_preview.primary_observer_id
	preview.avoid_detection_chance_percent = mini(
		preview.avoid_detection_chance_percent,
		tile_preview.avoid_detection_chance_percent
	)
	for observer_id: StringName in tile_preview.relevant_observer_ids:
		_append_unique(preview.relevant_observer_ids, observer_id)


func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)


func _unit(unit_id: StringName) -> TacticalUnitState:
	return (
		_state_store.state.get_unit(unit_id)
		if _state_store != null and _state_store.state != null
		else null
	)
