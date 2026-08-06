class_name TacticalBoardView
extends Node2D

const WALL_ADJACENCY_RESOLVER_SCRIPT: Script = preload(
	"res://presentation/tactical/walls/wall_adjacency_resolver.gd"
)
const TACTICAL_WALL_RENDERER_SCRIPT: Script = preload(
	"res://presentation/tactical/walls/tactical_wall_renderer.gd"
)
const TACTICAL_FOG_RENDERER_SCRIPT: Script = preload(
	"res://presentation/tactical/walls/tactical_fog_renderer.gd"
)
const STONE_WALL_DEFINITION: Resource = preload(
	"res://content/environment/walls/stone_wall_definition.tres"
)
const WOOD_WALL_DEFINITION: Resource = preload(
	"res://content/environment/walls/wood_wall_definition.tres"
)
const STEALTH_HOOD_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/stealth_hood_icon.svg"
)
const REACTION_AOO_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/reaction_aoo_icon.svg"
)
const REACTION_OVERWATCH_BOW_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/reaction_overwatch_bow_icon.svg"
)
const REACTION_BRACE_SPEAR_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/reaction_brace_spear_icon.svg"
)
const STATIC_BOARD_LAYER_SCRIPT: Script = preload(
	"res://presentation/tactical/tactical_static_board_layer.gd"
)
const FOG_LAYER_SCRIPT: Script = preload(
	"res://presentation/tactical/tactical_fog_layer.gd"
)

signal tile_hovered(tile: Vector2i)
signal tile_left_clicked(tile: Vector2i)
signal interaction_target_clicked(target_kind: StringName, target_id: StringName)
signal board_right_clicked(tile: Vector2i)
signal zoom_changed(zoom_percent: int)

enum OverlayMode {
	NONE,
	AUTOMATIC_PERCEPTION,
	MOVEMENT_COVER,
	ATTACK_TARGETING,
	INTERACT,
}

const BOARD_ORIGIN := Vector2.ZERO
const TILE_SIZE := 28.0

const MIN_ZOOM: float = 0.38
const MAX_ZOOM: float = 1.65
const DEFAULT_ZOOM: float = 0.78
const ZOOM_STEP: float = 1.15
const KEYBOARD_PAN_SPEED: float = 620.0
const PLAY_AREA_LEFT: float = 180.0
const PLAY_AREA_TOP: float = 48.0
const PLAY_AREA_RIGHT_MARGIN: float = 8.0
const PLAY_AREA_BOTTOM: float = 568.0

const FLOOR_COLOR := Color(0.18, 0.21, 0.24, 1.0)
const ALTERNATE_FLOOR_COLOR := Color(0.205, 0.235, 0.265, 1.0)
const GRID_COLOR := Color(0.055, 0.07, 0.085, 0.88)
const BLOCKED_COLOR := Color(0.17, 0.12, 0.09, 1.0)
const DIFFICULT_COLOR := Color(0.40, 0.285, 0.16, 1.0)
const EXPLORED_OVERLAY_COLOR := Color(0.025, 0.035, 0.065, 0.62)
const UNSEEN_COLOR := Color(0.018, 0.014, 0.027, 0.98)
const FOG_EDGE_COLOR := Color(0.18, 0.22, 0.27, 0.0)
const VALID_PATH_COLOR := Color(0.20, 0.76, 0.40, 0.40)
const AMBER_PATH_COLOR := Color(0.95, 0.63, 0.18, 0.42)
const SPRINT_PATH_COLOR := Color(0.78, 0.22, 0.20, 0.40)
const INVALID_PATH_COLOR := Color(0.80, 0.12, 0.13, 0.45)
const HOVER_COLOR := Color(0.94, 0.82, 0.26, 0.30)
const ITEM_COLOR := Color(0.94, 0.70, 0.20, 1.0)
const LEGAL_TARGET_COLOR := Color(0.82, 0.18, 0.16, 0.34)
const SELECTED_TARGET_COLOR := Color(1.0, 0.72, 0.14, 0.48)
const INVALID_TARGET_COLOR := Color(0.78, 0.08, 0.08, 0.50)
const TARGET_OUTLINE_COLOR := Color(1.0, 0.84, 0.32, 1.0)
const FOCUSED_AWARENESS_COLOR := Color(0.95, 0.67, 0.18, 0.16)
const CLOSE_AWARENESS_COLOR := Color(1.0, 0.48, 0.10, 0.24)
const ALERTED_AWARENESS_COLOR := Color(0.92, 0.18, 0.12, 0.13)
const DETECTION_BADGE_COLOR := Color(0.08, 0.095, 0.13, 0.96)
const DETECTION_BADGE_OUTLINE := Color(0.66, 0.82, 1.0, 1.0)
const REACTION_BADGE_OUTLINE := Color(1.0, 0.52, 0.22, 1.0)
const REACTION_AREA_FILL := Color(0.92, 0.30, 0.16, 0.15)
const REACTION_AREA_BORDER := Color(1.0, 0.54, 0.24, 0.70)
const FACING_PREVIEW_COLOR := Color(0.98, 0.84, 0.28, 0.95)
const LAST_SEEN_COLOR := Color(0.78, 0.82, 0.90, 0.72)
const EXTRACTION_ZONE_COLOR := Color(0.18, 0.72, 0.76, 0.18)
const EXTRACTION_ZONE_BORDER := Color(0.32, 0.92, 0.94, 0.92)
const EXTRACTION_ZONE_BLOCKED := Color(0.82, 0.20, 0.16, 0.40)
const COVER_EXPOSED_COLOR := Color(0.90, 0.30, 0.24, 0.96)
const COVER_LIGHT_COLOR := Color(0.92, 0.72, 0.22, 0.96)
const COVER_HEAVY_COLOR := Color(0.28, 0.72, 0.92, 0.98)
const COVER_TOTAL_COLOR := Color(0.48, 0.86, 0.72, 0.98)
const COVER_BADGE_BACK := Color(0.035, 0.045, 0.065, 0.94)
const COVER_FIELD_LIGHT := Color(0.36, 0.88, 0.94, 0.13)
const COVER_FIELD_HEAVY := Color(0.30, 0.86, 0.94, 0.24)
const COVER_FIELD_TOTAL := Color(0.24, 0.82, 0.92, 0.34)
const COVER_FIELD_BORDER := Color(0.58, 0.96, 1.0, 0.78)
const BARRIER_WOOD_COLOR := Color(0.52, 0.31, 0.14, 1.0)
const BARRIER_STONE_COLOR := Color(0.48, 0.51, 0.55, 1.0)
const BARRIER_METAL_COLOR := Color(0.56, 0.64, 0.68, 1.0)
const WINDOW_COLOR := Color(0.45, 0.86, 0.96, 0.78)
const OPENING_INK_COLOR := Color(0.08, 0.055, 0.035, 0.98)
const OPENING_HIGHLIGHT := Color(1.0, 0.82, 0.26, 0.96)
const OPENING_GLASS_FILL := Color(0.42, 0.76, 0.88, 0.42)
const PEEK_EYE_COLOR := Color(0.72, 0.90, 1.0, 0.96)
const LEAN_GHOST_COLOR := Color(1.0, 0.84, 0.28, 0.72)

var _map_definition: TacticalMapDefinition
var _facade
var _selected_unit_id: StringName = &""
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _preview_result: MovementPathResult
var _detection_preview: MovementDetectionPreview
var _reaction_preview: MovementReactionPreview
var _reaction_reservation_preview_tiles: Array[Vector2i] = []
var _reaction_reservation_preview_kind: StringName = &""
var _facing_preview_direction: Vector2i = Vector2i.ZERO
var _movement_mode: StringName = &"normal"
var _attack_targeting: bool = false
var _legal_attack_target_ids: Array[StringName] = []
var _selected_attack_target_id: StringName = &""
var _cover_preview: TacticalCoverPreview
var _directional_cover_field: TacticalDirectionalCoverField
var _selected_cover_category: StringName = &"neutral"
var _selected_attack_geometry: TacticalCombatGeometryResult
var _overlay_mode: int = OverlayMode.NONE
var _selected_attack_preview: TacticalAttackPreview
var _interact_mode_active: bool = false
var _input_enabled: bool = true
var _camera_zoom: float = DEFAULT_ZOOM
var _middle_drag_active: bool = false
var _wall_diagnostic_enabled: bool = false
var _awareness_overlay_enabled: bool = false
var _wall_adjacency_resolver: RefCounted
var _wall_renderer: RefCounted
var _fog_renderer: RefCounted
var _draw_call_count: int = 0
var _last_draw_usec: int = 0
var _last_board_draw_usec: int = 0
var _dynamic_redraw_count: int = 0
var _static_layer: TacticalStaticBoardLayer
var _fog_layer: TacticalFogLayer


func configure(
	map_definition: TacticalMapDefinition,
	facade
) -> void:
	_map_definition = map_definition
	_facade = facade
	_wall_adjacency_resolver = WALL_ADJACENCY_RESOLVER_SCRIPT.new()
	_wall_renderer = TACTICAL_WALL_RENDERER_SCRIPT.new()
	_fog_renderer = TACTICAL_FOG_RENDERER_SCRIPT.new()
	_camera_zoom = DEFAULT_ZOOM
	scale = Vector2.ONE * _camera_zoom
	position = Vector2(PLAY_AREA_LEFT, PLAY_AREA_TOP)
	_static_layer = STATIC_BOARD_LAYER_SCRIPT.new() as TacticalStaticBoardLayer
	_static_layer.name = "StaticEnvironmentLayer"
	_static_layer.z_index = -20
	_static_layer.show_behind_parent = true
	add_child(_static_layer)
	_static_layer.configure(_map_definition, _facade, _camera_zoom)
	_fog_layer = FOG_LAYER_SCRIPT.new() as TacticalFogLayer
	_fog_layer.name = "FogLayer"
	_fog_layer.z_index = -10
	_fog_layer.show_behind_parent = true
	add_child(_fog_layer)
	_fog_layer.configure(_map_definition, _facade, _camera_zoom)
	if _facade != null and _facade.has_signal("visibility_delta_changed"):
		var visibility_delta_callback := Callable(
			self,
			"_on_visibility_delta_changed"
		)
		if not _facade.is_connected(
			"visibility_delta_changed",
			visibility_delta_callback
		):
			_facade.connect(
				"visibility_delta_changed",
				visibility_delta_callback
			)
	set_process(true)
	_clamp_camera()
	queue_redraw()


func board_origin() -> Vector2:
	return BOARD_ORIGIN


func tile_size() -> float:
	return TILE_SIZE


func zoom_level() -> float:
	return _camera_zoom


func set_input_enabled(value: bool) -> void:
	_input_enabled = value
	if not value:
		_middle_drag_active = false


func center_on_tile(tile: Vector2i) -> void:
	if _map_definition == null or not _map_definition.is_inside(tile):
		return
	var play_area: Rect2 = _play_area_rect()
	var local_centre: Vector2 = tile_to_world(tile)
	position = play_area.get_center() - local_centre * _camera_zoom
	_clamp_camera()


func update_presentation(
	selected_unit_id: StringName,
	hovered_tile: Vector2i,
	preview_result: MovementPathResult,
	movement_mode: StringName,
	attack_targeting: bool = false,
	legal_attack_target_ids: Array[StringName] = [],
	selected_attack_target_id: StringName = &"",
	detection_preview: MovementDetectionPreview = null,
	reaction_preview: MovementReactionPreview = null,
	facing_preview_direction: Vector2i = Vector2i.ZERO,
	cover_preview: TacticalCoverPreview = null,
	directional_cover_field: TacticalDirectionalCoverField = null,
	selected_cover_category: StringName = &"neutral",
	selected_attack_geometry: TacticalCombatGeometryResult = null,
	selected_attack_preview: TacticalAttackPreview = null,
	interact_mode_active: bool = false,
	reaction_reservation_preview_tiles: Array[Vector2i] = [],
	reaction_reservation_preview_kind: StringName = &""
) -> void:
	_selected_unit_id = selected_unit_id
	_hovered_tile = hovered_tile
	_preview_result = preview_result
	_movement_mode = movement_mode
	_attack_targeting = attack_targeting
	_legal_attack_target_ids = legal_attack_target_ids.duplicate()
	_selected_attack_target_id = selected_attack_target_id
	_detection_preview = detection_preview
	_reaction_preview = reaction_preview
	_facing_preview_direction = facing_preview_direction
	_cover_preview = cover_preview
	_directional_cover_field = directional_cover_field
	_selected_cover_category = selected_cover_category
	_selected_attack_geometry = selected_attack_geometry
	_selected_attack_preview = selected_attack_preview
	_interact_mode_active = interact_mode_active
	_reaction_reservation_preview_tiles = reaction_reservation_preview_tiles.duplicate()
	_reaction_reservation_preview_kind = reaction_reservation_preview_kind
	_overlay_mode = _resolve_overlay_mode()
	queue_redraw()


func refresh_board() -> void:
	queue_redraw()


func notify_state_changed(
		reason: StringName,
		flags: TacticalInvalidationFlags = null
) -> void:
	var refresh_environment: bool = (
		flags.geometry_changed or flags.environment_visuals_changed
		if flags != null
		else reason in [
			&"opening_state_changed",
			&"structure_state_changed",
			&"structure_attacked",
			&"environment_geometry_changed",
			&"extraction_zone_changed",
		]
	)
	if _static_layer != null and refresh_environment:
		_static_layer.refresh_environment()

	var refresh_fog: bool = (
		flags.visibility_changed or flags.exploration_changed
		if flags != null
		else reason in [
			&"runtime_spawn",
			&"unit_moved",
			&"unit_sprinted",
			&"enemy_unit_moved",
			&"character_resolved",
			&"vision_blocker_changed",
			&"environment_geometry_changed",
			&"opening_state_changed",
			&"structure_state_changed",
			&"structure_attacked",
			&"unit_removed",
		]
	)
	if _fog_layer != null and refresh_fog:
		_fog_layer.refresh_fog()


func _on_visibility_delta_changed(
		team_id: StringName,
		delta: Dictionary
) -> void:
	if team_id != &"player" or _fog_layer == null:
		return
	_fog_layer.apply_visibility_delta(delta)


func performance_snapshot() -> Dictionary:
	return {
		"draw_call_count": _draw_call_count,
		"last_draw_usec": _last_draw_usec,
		"last_board_draw_usec": _last_board_draw_usec,
		"dynamic_redraw_count": _dynamic_redraw_count,
		"static_layer": (
			_static_layer.performance_snapshot()
			if _static_layer != null else {}
		),
		"fog_layer": (
			_fog_layer.performance_snapshot()
			if _fog_layer != null else {}
		),
	}


func _process(delta: float) -> void:
	if not _input_enabled or _middle_drag_active:
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction != Vector2.ZERO:
		_pan_by_screen_delta(
			direction.normalized() * KEYBOARD_PAN_SPEED * delta * -1.0
		)


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or _map_definition == null:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_V
		):
			_awareness_overlay_enabled = not _awareness_overlay_enabled
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_F8
		):
			_wall_diagnostic_enabled = not _wall_diagnostic_enabled
			print(
				"Wall/Fog Diagnostic: %s"
				% ("ON" if _wall_diagnostic_enabled else "OFF")
			)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		if _middle_drag_active:
			_pan_by_screen_delta(mouse_event.relative)
			get_viewport().set_input_as_handled()
		var tile := _screen_to_tile(mouse_event.position)
		if tile != _hovered_tile:
			_hovered_tile = tile
			tile_hovered.emit(tile)
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_drag_active = mouse_button.pressed
			get_viewport().set_input_as_handled()
			return
		if not mouse_button.pressed:
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mouse_button.position, _camera_zoom * ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mouse_button.position, _camera_zoom / ZOOM_STEP)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if _interact_mode_active:
				var interaction_target: Dictionary = _interaction_target_at_screen_position(
					mouse_button.position
				)
				if not interaction_target.is_empty():
					interaction_target_clicked.emit(
						StringName(interaction_target.get("target_kind", &"")),
						StringName(interaction_target.get("target_id", &""))
					)
					get_viewport().set_input_as_handled()
					return
			tile_left_clicked.emit(_screen_to_tile(mouse_button.position))
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			board_right_clicked.emit(_screen_to_tile(mouse_button.position))


func _interaction_target_at_screen_position(
		screen_position: Vector2
) -> Dictionary:
	if not _interact_mode_active or _facade == null or _selected_unit_id.is_empty():
		return {}
	var local_point: Vector2 = to_local(screen_position)
	var hit_padding: float = 10.0 / maxf(_camera_zoom, 0.01)
	var best_distance: float = INF
	var best_target: Dictionary = {}
	for opening_id: StringName in _facade.adjacent_interactable_openings(_selected_unit_id):
		var opening: TacticalOpeningDefinition = _map_definition.opening_definition(opening_id)
		if opening == null:
			continue
		var endpoints: PackedVector2Array = _edge_endpoints(opening.first_tile, opening.second_tile)
		if endpoints.size() < 2:
			continue
		var distance: float = _distance_to_segment(local_point, endpoints[0], endpoints[1])
		if distance <= hit_padding and distance < best_distance:
			best_distance = distance
			best_target = {
				"target_kind": &"opening",
				"target_id": opening.opening_id,
			}
	for structure_id: StringName in _facade.adjacent_interactable_structures(_selected_unit_id):
		var structure: TacticalStructureDefinition = _map_definition.structure_definition(structure_id)
		if structure == null or structure.geometry_kind != TacticalStructureDefinition.GEOMETRY_EDGE:
			continue
		var endpoints: PackedVector2Array = _edge_endpoints(structure.first_tile, structure.second_tile)
		if endpoints.size() < 2:
			continue
		var distance: float = _distance_to_segment(local_point, endpoints[0], endpoints[1])
		if distance <= hit_padding and distance < best_distance:
			best_distance = distance
			best_target = {
				"target_kind": &"structure",
				"target_id": structure.structure_id,
			}
	return best_target


func _distance_to_segment(point: Vector2, first: Vector2, second: Vector2) -> float:
	var segment: Vector2 = second - first
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(first)
	var amount: float = clampf((point - first).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(first + segment * amount)


func _draw() -> void:
	if _map_definition == null or _facade == null:
		return
	var started_usec: int = Time.get_ticks_usec()
	if _overlay_mode == OverlayMode.AUTOMATIC_PERCEPTION:
		_draw_perception_overlays()
	elif _overlay_mode == OverlayMode.MOVEMENT_COVER:
		_draw_directional_cover_field()
	_draw_reaction_reservation_preview()
	_draw_interaction_highlights()
	_draw_last_seen_markers()
	_draw_ground_items()
	_draw_attack_targets()
	_draw_hover_highlight()
	_draw_path_preview()
	_draw_movement_ghost()
	# Stage 4.4e1: hypothetical/automatic Peek markers are not drawn during hover.
	_draw_facing_preview()
	_draw_selection_outline()
	_draw_automatic_lean_origin()
	_draw_wall_fog_diagnostic()
	_draw_call_count += 1
	_dynamic_redraw_count += 1
	_last_draw_usec = Time.get_ticks_usec() - started_usec


func _draw_board() -> void:
	var started_usec: int = Time.get_ticks_usec()
	for y: int in range(_map_definition.grid_size.y):
		for x: int in range(_map_definition.grid_size.x):
			var tile := Vector2i(x, y)
			var rectangle := _tile_rect(tile)
			var variant_seed: int = _map_definition.wall_variant_seed(tile)
			if not _facade.is_tile_explored_by_player(tile):
				_fog_renderer.call(
					"draw_unseen",
					self,
					rectangle,
					_camera_zoom,
					variant_seed,
					UNSEEN_COLOR
				)
				continue

			var fill_color := FLOOR_COLOR
			if _camera_zoom > 0.62 and (x + y) % 2 != 0:
				fill_color = ALTERNATE_FLOOR_COLOR
			if _map_definition.is_difficult(tile):
				fill_color = DIFFICULT_COLOR
			draw_rect(rectangle, fill_color, true)

			if _map_definition.is_wall(tile):
				var material_definition: Resource = _wall_definition_for_tile(tile)
				var connections: int = int(
					_wall_adjacency_resolver.call(
						"connections_for",
						_map_definition,
						tile
					)
				)
				_wall_renderer.call(
					"draw_wall",
					self,
					rectangle,
					material_definition,
					connections,
					_camera_zoom,
					variant_seed
				)
			elif _map_definition.blocked_tiles.has(tile):
				draw_rect(rectangle.grow(-2.0), BLOCKED_COLOR, true)

			if _camera_zoom >= 0.52 and not _map_definition.is_wall(tile):
				draw_rect(rectangle, GRID_COLOR, false, 1.0 / _camera_zoom)
			if not _facade.is_tile_visible_to_player(tile):
				_fog_renderer.call(
					"draw_explored",
					self,
					rectangle,
					_camera_zoom,
					variant_seed,
					EXPLORED_OVERLAY_COLOR
				)

	var board_size := Vector2(_map_definition.grid_size) * TILE_SIZE
	draw_rect(
		Rect2(BOARD_ORIGIN, board_size),
		Color(0.55, 0.61, 0.66, 1.0),
		false,
		2.0 / _camera_zoom
	)
	_last_board_draw_usec = Time.get_ticks_usec() - started_usec



func _draw_edge_geometry() -> void:
	if _map_definition == null:
		return
	for barrier: TacticalBarrierSegmentDefinition in _map_definition.edge_barriers:
		if barrier == null:
			continue
		_draw_geometry_edge(
			barrier.first_tile,
			barrier.second_tile,
			_barrier_color(barrier.material_profile_id),
			3.0 if barrier.height_profile == TacticalBarrierSegmentDefinition.HEIGHT_LOW else 5.0,
			false
		)
	var environment: TacticalEnvironmentState = _facade.state().environment_state
	for opening: TacticalOpeningDefinition in _map_definition.openings:
		if opening == null:
			continue
		var runtime: TacticalOpeningState = (
			environment.opening_state(opening.opening_id)
			if environment != null else null
		)
		_draw_opening_feature(opening, runtime)
	for structure: TacticalStructureDefinition in _map_definition.structures:
		if structure == null:
			continue
		var runtime: TacticalStructureState = (
			environment.structure_state(structure.structure_id)
			if environment != null else null
		)
		if structure.geometry_kind == TacticalStructureDefinition.GEOMETRY_EDGE:
			var broken: bool = runtime != null and runtime.integrity_state_id in [
				TacticalStructureDefinition.STATE_BREACHED,
				TacticalStructureDefinition.STATE_DESTROYED,
				TacticalStructureDefinition.STATE_CLEARED,
			]
			_draw_geometry_edge(
				structure.first_tile,
				structure.second_tile,
				_barrier_color(structure.material_profile_id),
				2.0 if broken else 6.0,
				broken
			)
			if runtime != null and runtime.integrity_state_id == TacticalStructureDefinition.STATE_DAMAGED:
				_draw_damage_crack(_edge_midpoint(structure.first_tile, structure.second_tile))
		elif runtime != null:
			for tile: Vector2i in structure.tile_coordinates:
				var rect: Rect2 = _tile_rect(tile).grow(-3.0)
				draw_rect(rect, _barrier_color(structure.material_profile_id), true)
				if runtime.integrity_state_id in [TacticalStructureDefinition.STATE_BREACHED, TacticalStructureDefinition.STATE_DESTROYED]:
					draw_line(rect.position, rect.end, Color(0.12, 0.10, 0.08, 1.0), 2.0 / _camera_zoom)


func _draw_geometry_edge(
		first: Vector2i,
		second: Vector2i,
		color: Color,
		width: float,
		broken: bool
) -> void:
	if not _facade.is_tile_explored_by_player(first) and not _facade.is_tile_explored_by_player(second):
		return
	var endpoints: PackedVector2Array = _edge_endpoints(first, second)
	if endpoints.size() < 2:
		return
	if broken:
		var middle: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		var direction: Vector2 = (endpoints[1] - endpoints[0]).normalized()
		draw_line(endpoints[0], middle - direction * 4.0, color, width / _camera_zoom, true)
		draw_line(middle + direction * 4.0, endpoints[1], color, width / _camera_zoom, true)
	else:
		draw_line(endpoints[0], endpoints[1], color, width / _camera_zoom, true)


func _draw_opening_feature(
		opening: TacticalOpeningDefinition,
		runtime: TacticalOpeningState
) -> void:
	if opening == null:
		return
	if not _facade.is_tile_explored_by_player(opening.first_tile) and not _facade.is_tile_explored_by_player(opening.second_tile):
		return
	var endpoints: PackedVector2Array = _edge_endpoints(opening.first_tile, opening.second_tile)
	if endpoints.size() < 2:
		return
	var state_id: StringName = runtime.state_id if runtime != null else opening.initial_state_id
	if opening.opening_kind == TacticalOpeningDefinition.KIND_WINDOW:
		_draw_inked_window(opening, state_id, endpoints)
	elif opening.opening_kind == TacticalOpeningDefinition.KIND_BARRED_OPENING:
		_draw_inked_barred_opening(opening, state_id, endpoints)
	else:
		_draw_inked_door(opening, state_id, endpoints)
	if runtime != null and runtime.locked:
		_draw_small_lock(_edge_midpoint(opening.first_tile, opening.second_tile))
	if state_id == TacticalOpeningDefinition.STATE_DAMAGED:
		_draw_damage_crack(_edge_midpoint(opening.first_tile, opening.second_tile))


func _draw_inked_door(
		opening: TacticalOpeningDefinition,
		state_id: StringName,
		endpoints: PackedVector2Array
) -> void:
	var tangent: Vector2 = (endpoints[1] - endpoints[0]).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var wood: Color = _barrier_color(opening.material_profile_id)
	var is_open: bool = state_id in [
		TacticalOpeningDefinition.STATE_OPEN,
		TacticalOpeningDefinition.STATE_BROKEN,
		TacticalOpeningDefinition.STATE_DESTROYED,
	]
	# Thick hand-inked frame posts remain visible in every state.
	for endpoint: Vector2 in endpoints:
		draw_line(endpoint - normal * 4.5, endpoint + normal * 4.5, OPENING_INK_COLOR, 5.5 / _camera_zoom, true)
		draw_line(endpoint - normal * 3.2, endpoint + normal * 3.2, wood.lightened(0.12), 2.8 / _camera_zoom, true)
	if not is_open:
		draw_line(endpoints[0], endpoints[1], OPENING_INK_COLOR, 10.0 / _camera_zoom, true)
		draw_line(endpoints[0], endpoints[1], wood, 6.5 / _camera_zoom, true)
		# Irregular plank divisions and short hatch strokes give the feature the
		# same inked material language as the authored wall renderer.
		for ratio: float in [0.24, 0.50, 0.76]:
			var point: Vector2 = endpoints[0].lerp(endpoints[1], ratio)
			draw_line(point - normal * 3.2, point + normal * 3.2, OPENING_INK_COLOR, 1.0 / _camera_zoom, true)
		for ratio: float in [0.15, 0.38, 0.64, 0.87]:
			var hatch: Vector2 = endpoints[0].lerp(endpoints[1], ratio)
			draw_line(hatch - tangent * 1.4 - normal * 2.0, hatch + tangent * 1.4 + normal * 2.0, OPENING_INK_COLOR, 0.8 / _camera_zoom, true)
	else:
		# The leaf swings visibly away from the edge so an open door never reads
		# as a missing or invisible object.
		var hinge: Vector2 = endpoints[0]
		var leaf_end: Vector2 = hinge + normal * 17.0 + tangent * 3.0
		draw_line(hinge, leaf_end, OPENING_INK_COLOR, 9.0 / _camera_zoom, true)
		draw_line(hinge, leaf_end, wood, 5.8 / _camera_zoom, true)
		draw_arc(hinge, 15.0, tangent.angle(), (leaf_end - hinge).angle(), 10, Color(0.16, 0.10, 0.06, 0.34), 1.0 / _camera_zoom, true)
		if state_id in [TacticalOpeningDefinition.STATE_BROKEN, TacticalOpeningDefinition.STATE_DESTROYED]:
			_draw_damage_crack((hinge + leaf_end) * 0.5)


func _draw_inked_window(
		_opening: TacticalOpeningDefinition,
		state_id: StringName,
		endpoints: PackedVector2Array
) -> void:
	var tangent: Vector2 = (endpoints[1] - endpoints[0]).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	var is_open: bool = state_id in [
		TacticalOpeningDefinition.STATE_OPEN,
		TacticalOpeningDefinition.STATE_BROKEN,
		TacticalOpeningDefinition.STATE_DESTROYED,
	]
	# Substantial dark frame with painted inner frame. It extends slightly into
	# both neighbouring tiles but remains mechanically edge-based.
	draw_line(endpoints[0], endpoints[1], OPENING_INK_COLOR, 10.0 / _camera_zoom, true)
	draw_line(endpoints[0], endpoints[1], WINDOW_COLOR.darkened(0.18), 6.5 / _camera_zoom, true)
	if not is_open:
		draw_line(endpoints[0] + tangent * 2.0, endpoints[1] - tangent * 2.0, OPENING_GLASS_FILL, 4.5 / _camera_zoom, true)
		var middle: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		draw_line(middle - normal * 4.0, middle + normal * 4.0, OPENING_INK_COLOR, 1.2 / _camera_zoom, true)
		for ratio: float in [0.30, 0.70]:
			var glint: Vector2 = endpoints[0].lerp(endpoints[1], ratio)
			draw_line(glint - tangent * 2.2 - normal * 1.4, glint + tangent * 2.2 + normal * 1.4, Color(0.82, 0.95, 1.0, 0.74), 1.0 / _camera_zoom, true)
	else:
		# Broken/open windows retain a visible frame and jagged fragments.
		var middle: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		draw_line(endpoints[0], middle - tangent * 4.0, WINDOW_COLOR, 4.5 / _camera_zoom, true)
		draw_line(middle + tangent * 4.0, endpoints[1], WINDOW_COLOR, 4.5 / _camera_zoom, true)
		if state_id == TacticalOpeningDefinition.STATE_BROKEN:
			for ratio: float in [0.18, 0.82]:
				var shard: Vector2 = endpoints[0].lerp(endpoints[1], ratio)
				draw_polyline(PackedVector2Array([shard - normal * 3.0, shard + tangent * 2.0, shard + normal * 2.0]), Color(0.74, 0.92, 1.0, 0.9), 1.2 / _camera_zoom, true)


func _draw_inked_barred_opening(
		opening: TacticalOpeningDefinition,
		_state_id: StringName,
		endpoints: PackedVector2Array
) -> void:
	var tangent: Vector2 = (endpoints[1] - endpoints[0]).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	draw_line(endpoints[0], endpoints[1], OPENING_INK_COLOR, 10.0 / _camera_zoom, true)
	draw_line(endpoints[0], endpoints[1], _barrier_color(opening.material_profile_id), 6.0 / _camera_zoom, true)
	for ratio: float in [0.18, 0.40, 0.62, 0.84]:
		var point: Vector2 = endpoints[0].lerp(endpoints[1], ratio)
		draw_line(point - normal * 5.0, point + normal * 5.0, OPENING_INK_COLOR, 2.4 / _camera_zoom, true)
		draw_line(point - normal * 4.2, point + normal * 4.2, BARRIER_METAL_COLOR, 1.2 / _camera_zoom, true)


func _edge_endpoints(first: Vector2i, second: Vector2i) -> PackedVector2Array:
	var delta: Vector2i = second - first
	if delta.x != 0:
		var x: float = float(maxi(first.x, second.x)) * TILE_SIZE
		var y0: float = float(first.y) * TILE_SIZE
		return PackedVector2Array([Vector2(x, y0 + 2.0), Vector2(x, y0 + TILE_SIZE - 2.0)])
	if delta.y != 0:
		var y: float = float(maxi(first.y, second.y)) * TILE_SIZE
		var x0: float = float(first.x) * TILE_SIZE
		return PackedVector2Array([Vector2(x0 + 2.0, y), Vector2(x0 + TILE_SIZE - 2.0, y)])
	return PackedVector2Array()


func _edge_midpoint(first: Vector2i, second: Vector2i) -> Vector2:
	var endpoints: PackedVector2Array = _edge_endpoints(first, second)
	return (endpoints[0] + endpoints[1]) * 0.5 if endpoints.size() >= 2 else tile_to_world(first)


func _barrier_color(material_id: StringName) -> Color:
	var value: String = String(material_id)
	if value.contains("stone"):
		return BARRIER_STONE_COLOR
	if value.contains("iron") or value.contains("metal"):
		return BARRIER_METAL_COLOR
	return BARRIER_WOOD_COLOR


func _draw_small_lock(centre: Vector2) -> void:
	draw_rect(Rect2(centre - Vector2(3.5, 1.0), Vector2(7.0, 6.0)), Color(0.94, 0.76, 0.22, 1.0), true)
	draw_arc(centre + Vector2(0.0, -1.0), 3.0, PI, TAU, 10, Color(0.94, 0.76, 0.22, 1.0), 1.3 / _camera_zoom, true)


func _draw_damage_crack(centre: Vector2) -> void:
	var crack := PackedVector2Array([
		centre + Vector2(-4.0, -5.0),
		centre + Vector2(-1.0, -1.0),
		centre + Vector2(-3.0, 2.0),
		centre + Vector2(4.0, 5.0),
	])
	draw_polyline(crack, Color(0.08, 0.06, 0.04, 0.95), 1.5 / _camera_zoom, true)


func _draw_destination_cover_preview() -> void:
	# Legacy Stage 4.4d markers: worst_label() and compact_breakdown().
	# Stage 4.4e replaces that text with the bottom-left shield and cyan field.
	# Legacy validator marker: _cover_preview.summary_text()
	# Stage 4.4e moves the primary read onto the movement ghost and cyan field.
	return


func _draw_selected_cover_ring() -> void:
	return


func _draw_exact_attack_cover() -> void:
	return


func _resolve_overlay_mode() -> int:
	if _attack_targeting:
		return OverlayMode.ATTACK_TARGETING
	if _interact_mode_active:
		return OverlayMode.INTERACT
	if (
		_preview_result != null
		and _preview_result.success
		and _directional_cover_field != null
	):
		return OverlayMode.MOVEMENT_COVER
	if not _selected_unit_id.is_empty():
		return OverlayMode.AUTOMATIC_PERCEPTION
	return OverlayMode.NONE


func _draw_directional_cover_field() -> void:
	if _directional_cover_field == null:
		return
	# Stage 4.4e1 deliberately avoids per-tile hatch loops. One translucent fill
	# and, for stronger categories, one border keeps the preview readable while
	# bounding draw calls during rapid destination hover.
	for tile_value: Variant in _directional_cover_field.categories_by_tile.keys():
		if not (tile_value is Vector2i):
			continue
		var tile := Vector2i(tile_value)
		var category: StringName = _directional_cover_field.category_at(tile)
		var rectangle: Rect2 = _tile_rect(tile).grow(-1.0)
		var fill: Color = COVER_FIELD_LIGHT
		if category == TacticalCombatGeometryResult.COVER_HEAVY:
			fill = COVER_FIELD_HEAVY
		elif category == TacticalCombatGeometryResult.COVER_TOTAL:
			fill = COVER_FIELD_TOTAL
		draw_rect(rectangle, fill, true)
		if category in [
			TacticalCombatGeometryResult.COVER_HEAVY,
			TacticalCombatGeometryResult.COVER_TOTAL,
		]:
			var border_alpha: float = (
				0.44
				if category == TacticalCombatGeometryResult.COVER_HEAVY
				else 0.68
			)
			draw_rect(
				rectangle,
				Color(
					COVER_FIELD_BORDER.r,
					COVER_FIELD_BORDER.g,
					COVER_FIELD_BORDER.b,
					border_alpha
				),
				false,
				1.25 / _camera_zoom
			)


func _draw_movement_ghost() -> void:
	if _preview_result == null or not _preview_result.success:
		return
	if _preview_result.path.is_empty():
		return
	var destination: Vector2i = _preview_result.path.back()
	var centre: Vector2 = tile_to_world(destination)
	draw_circle(centre, 10.5, Color(0.68, 0.92, 1.0, 0.22))
	draw_arc(centre, 10.5, 0.0, TAU, 28, Color(0.70, 0.96, 1.0, 0.82), 1.5 / _camera_zoom, true)
	var category: StringName = (
		_directional_cover_field.strongest_local_cover
		if _directional_cover_field != null
		else TacticalCombatGeometryResult.COVER_NONE
	)
	if (
		not _tile_has_detection_badge(destination)
		and not _tile_has_reaction_badge(destination)
		and category in [
			TacticalCombatGeometryResult.COVER_LIGHT,
			TacticalCombatGeometryResult.COVER_HEAVY,
		]
	):
		_draw_cover_badge(centre + Vector2(-8.0, 8.0), category, 5.0, 1)


func _tile_has_detection_badge(tile: Vector2i) -> bool:
	if _detection_preview == null:
		return false
	var tile_preview: MovementDetectionTilePreview = (
		_detection_preview.preview_for_tile(tile)
	)
	return tile_preview != null and tile_preview.has_detection_risk()


func _tile_has_reaction_badge(tile: Vector2i) -> bool:
	return (
		_reaction_preview != null
		and _reaction_preview.preview_for_tile(tile) != null
		and not _tile_has_detection_badge(tile)
	)


func _draw_cover_badge(
		centre: Vector2,
		category: StringName,
		size: float,
		count: int
) -> void:
	# Stage 4.4e1 supports only a half shield for Light and a full shield for
	# Heavy. COVER_TOTAL, COVER_NONE and &"neutral" intentionally draw nothing.
	if category not in [
		TacticalCombatGeometryResult.COVER_LIGHT,
		TacticalCombatGeometryResult.COVER_HEAVY,
	]:
		return
	draw_circle(centre, size + 2.0, COVER_BADGE_BACK)
	var color: Color = _cover_color(category)
	# Compact shield silhouette. Filled proportion distinguishes Light, Heavy and
	# Total without relying on colour alone; Exposed uses a broken slash.
	var shield := PackedVector2Array([
		centre + Vector2(-size * 0.70, -size * 0.55),
		centre + Vector2(size * 0.70, -size * 0.55),
		centre + Vector2(size * 0.58, size * 0.30),
		centre + Vector2(0.0, size),
		centre + Vector2(-size * 0.58, size * 0.30),
	])
	if category == &"neutral":
		draw_polyline(
			PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]),
			color,
			1.2 / _camera_zoom,
			true
		)
	elif category == TacticalCombatGeometryResult.COVER_NONE:
		draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), color, 1.5 / _camera_zoom, true)
		draw_line(centre + Vector2(-size * 0.6, size * 0.55), centre + Vector2(size * 0.6, -size * 0.55), color, 1.5 / _camera_zoom, true)
	elif category == TacticalCombatGeometryResult.COVER_LIGHT:
		var light_fill: Color = color
		light_fill.a = 0.28
		draw_colored_polygon(shield, light_fill)
		draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), color, 1.5 / _camera_zoom, true)
		draw_rect(Rect2(centre + Vector2(-size, 0.0), Vector2(size * 2.0, size + 1.0)), COVER_BADGE_BACK, true)
	else:
		draw_colored_polygon(shield, color)
		draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), Color.WHITE, 1.0 / _camera_zoom, true)
		if category == TacticalCombatGeometryResult.COVER_TOTAL:
			draw_line(centre + Vector2(-size * 0.5, 0.0), centre + Vector2(size * 0.5, 0.0), COVER_BADGE_BACK, 1.5 / _camera_zoom, true)
	if count > 1:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, centre + Vector2(size * 0.55, -size * 0.55), str(count), HORIZONTAL_ALIGNMENT_CENTER, 8.0, 7, Color.WHITE)


func _cover_color(category: StringName) -> Color:
	match category:
		TacticalCombatGeometryResult.COVER_LIGHT:
			return COVER_LIGHT_COLOR
		TacticalCombatGeometryResult.COVER_HEAVY:
			return COVER_HEAVY_COLOR
		TacticalCombatGeometryResult.COVER_TOTAL:
			return COVER_TOTAL_COLOR
		&"neutral":
			return Color(0.62, 0.72, 0.78, 0.72)
		_:
			return COVER_EXPOSED_COLOR


func _draw_physical_edge_cover(tile: Vector2i, destination_preview: bool) -> void:
	var edge_cover: Dictionary = _facade.physical_edge_cover(tile)
	for direction_value: Variant in edge_cover.keys():
		if not direction_value is Vector2i:
			continue
		var direction: Vector2i = Vector2i(direction_value)
		var centre: Vector2 = tile_to_world(tile) + Vector2(direction) * (TILE_SIZE * 0.47)
		_draw_edge_shield(centre, direction, StringName(edge_cover.get(direction_value)), destination_preview)


func _draw_edge_shield(
		centre: Vector2,
		direction: Vector2i,
		category: StringName,
		preview: bool
) -> void:
	var tangent: Vector2 = Vector2(-direction.y, direction.x)
	var half_length: float = 7.0 if preview else 5.5
	var thickness: float = 3.8 if category == TacticalCombatGeometryResult.COVER_LIGHT else 5.4
	if category == TacticalCombatGeometryResult.COVER_TOTAL:
		thickness = 7.0
	var color: Color = _cover_color(category)
	draw_line(centre - tangent * half_length, centre + tangent * half_length, COVER_BADGE_BACK, (thickness + 2.5) / _camera_zoom, true)
	draw_line(centre - tangent * half_length, centre + tangent * half_length, color, thickness / _camera_zoom, true)
	if category == TacticalCombatGeometryResult.COVER_LIGHT:
		draw_line(centre, centre + tangent * half_length, COVER_BADGE_BACK, 1.2 / _camera_zoom, true)


func _draw_interaction_highlights() -> void:
	if not _interact_mode_active or _selected_unit_id.is_empty():
		return
	for opening_id: StringName in _facade.adjacent_interactable_openings(_selected_unit_id):
		var opening: TacticalOpeningDefinition = _map_definition.opening_definition(opening_id)
		if opening == null:
			continue
		var endpoints: PackedVector2Array = _edge_endpoints(opening.first_tile, opening.second_tile)
		if endpoints.size() < 2:
			continue
		draw_line(endpoints[0], endpoints[1], Color(1.0, 0.82, 0.26, 0.26), 15.0 / _camera_zoom, true)
		draw_line(endpoints[0], endpoints[1], OPENING_HIGHLIGHT, 2.2 / _camera_zoom, true)
		var centre: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		draw_circle(centre, 6.5, COVER_BADGE_BACK)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, centre + Vector2(-4.0, 3.5), "I", HORIZONTAL_ALIGNMENT_CENTER, 8.0, 10, OPENING_HIGHLIGHT)
	for structure_id: StringName in _facade.adjacent_interactable_structures(_selected_unit_id):
		var structure: TacticalStructureDefinition = _map_definition.structure_definition(structure_id)
		if structure == null:
			continue
		var endpoints: PackedVector2Array = _edge_endpoints(structure.first_tile, structure.second_tile)
		if endpoints.size() < 2:
			continue
		draw_line(endpoints[0], endpoints[1], Color(1.0, 0.38, 0.20, 0.25), 15.0 / _camera_zoom, true)
		draw_line(endpoints[0], endpoints[1], Color(1.0, 0.46, 0.24, 0.96), 2.2 / _camera_zoom, true)
		var centre: Vector2 = (endpoints[0] + endpoints[1]) * 0.5
		draw_circle(centre, 6.5, COVER_BADGE_BACK)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, centre + Vector2(-4.0, 3.5), "A", HORIZONTAL_ALIGNMENT_CENTER, 8.0, 10, Color(1.0, 0.60, 0.28, 1.0))


func _draw_automatic_peek_markers() -> void:
	if _selected_unit_id.is_empty() or _facade == null:
		return
	var position_override: Variant = null
	if _cover_preview != null and _preview_result != null and _preview_result.success:
		position_override = _cover_preview.destination
	var origins: Array[TacticalObservationOrigin] = _facade.observation_origins_for_unit(
		_selected_unit_id, position_override
	)
	for origin: TacticalObservationOrigin in origins:
		if origin == null or not origin.uses_automatic_peek:
			continue
		var centre: Vector2 = origin.world_position * TILE_SIZE
		_draw_eye_marker(centre, origin.direction, position_override != null)


func _draw_eye_marker(centre: Vector2, direction: Vector2i, preview: bool) -> void:
	var tangent: Vector2 = Vector2(-direction.y, direction.x)
	var scale_value: float = 5.0 if preview else 4.0
	var eye := PackedVector2Array([
		centre - tangent * scale_value,
		centre - Vector2(direction) * 2.2,
		centre + tangent * scale_value,
		centre + Vector2(direction) * 2.2,
		centre - tangent * scale_value,
	])
	draw_polyline(eye, PEEK_EYE_COLOR, 1.3 / _camera_zoom, true)
	draw_circle(centre, 1.5, PEEK_EYE_COLOR)
	if preview:
		draw_line(centre, centre + Vector2(direction) * 10.0, Color(0.72, 0.90, 1.0, 0.28), 1.0 / _camera_zoom, true)


func _draw_automatic_lean_origin() -> void:
	if _selected_attack_preview == null or not _selected_attack_preview.uses_automatic_lean:
		return
	if not (_selected_attack_preview.attack_origin_override is Vector2):
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return
	var origin: Vector2 = Vector2(_selected_attack_preview.attack_origin_override) * TILE_SIZE
	var unit_centre: Vector2 = tile_to_world(unit.grid_position)
	draw_line(unit_centre, origin, LEAN_GHOST_COLOR, 2.0 / _camera_zoom, true)
	draw_circle(origin, 5.0, Color(0.08, 0.07, 0.05, 0.72))
	draw_circle(origin, 3.2, LEAN_GHOST_COLOR)
	var direction: Vector2 = (origin - unit_centre).normalized()
	var tangent: Vector2 = Vector2(-direction.y, direction.x)
	draw_line(origin - tangent * 4.0, origin + tangent * 4.0, Color(1.0, 0.92, 0.60, 0.92), 1.2 / _camera_zoom, true)


func _cover_danger_rank(category: StringName) -> int:
	match category:
		TacticalCombatGeometryResult.COVER_NONE:
			return 0
		TacticalCombatGeometryResult.COVER_LIGHT:
			return 1
		TacticalCombatGeometryResult.COVER_HEAVY:
			return 2
		TacticalCombatGeometryResult.COVER_TOTAL:
			return 3
		_:
			return 4


func _draw_extraction_zones() -> void:
	if _facade == null or not _facade.has_method("extraction_zone_definitions"):
		return
	var zones: Array[TacticalExtractionZoneDefinition] = (
		_facade.extraction_zone_definitions()
	)
	for zone: TacticalExtractionZoneDefinition in zones:
		if zone == null:
			continue
		var zone_state: TacticalExtractionZoneState = (
			_facade.extraction_zone_state(zone.zone_id)
		)
		var usable: bool = zone_state != null and zone_state.is_usable()
		var fill: Color = (
			EXTRACTION_ZONE_COLOR if usable else EXTRACTION_ZONE_BLOCKED
		)
		var border: Color = (
			EXTRACTION_ZONE_BORDER
			if usable
			else Color(0.96, 0.34, 0.28, 0.95)
		)
		for tile: Vector2i in zone.tile_coordinates:
			if not _map_definition.is_inside(tile):
				continue
			var rectangle: Rect2 = _tile_rect(tile).grow(-2.0)
			draw_rect(rectangle, fill, true)
			draw_rect(rectangle, border, false, 1.5 / _camera_zoom)
			var centre: Vector2 = rectangle.get_center()
			var arrow_size: float = 4.5
			var arrow := PackedVector2Array([
				centre + Vector2(-arrow_size, -arrow_size * 0.5),
				centre + Vector2(arrow_size, -arrow_size * 0.5),
				centre + Vector2(arrow_size, -arrow_size),
				centre + Vector2(arrow_size * 1.8, 0.0),
				centre + Vector2(arrow_size, arrow_size),
				centre + Vector2(arrow_size, arrow_size * 0.5),
				centre + Vector2(-arrow_size, arrow_size * 0.5),
			])
			draw_colored_polygon(arrow, border)


func _wall_definition_for_tile(tile: Vector2i) -> Resource:
	if (
		_map_definition.wall_material_id(tile)
		== TacticalMapDefinition.WALL_MATERIAL_WOOD
	):
		return WOOD_WALL_DEFINITION
	return STONE_WALL_DEFINITION


func _draw_wall_fog_diagnostic() -> void:
	if (
		not _wall_diagnostic_enabled
		or not _map_definition.is_inside(_hovered_tile)
	):
		return
	var rectangle: Rect2 = _tile_rect(_hovered_tile).grow(-2.0)
	var visibility_color := Color(0.10, 0.75, 0.35, 0.72)
	if not _facade.is_tile_explored_by_player(_hovered_tile):
		visibility_color = Color(0.22, 0.12, 0.30, 0.85)
	elif not _facade.is_tile_visible_to_player(_hovered_tile):
		visibility_color = Color(0.18, 0.42, 0.78, 0.78)
	draw_rect(rectangle, visibility_color, false, 2.0 / _camera_zoom)
	if _map_definition.is_blocked(_hovered_tile):
		draw_line(
			rectangle.position,
			rectangle.end,
			Color(0.95, 0.22, 0.18, 0.95),
			2.0 / _camera_zoom
		)
	if _map_definition.blocks_vision(_hovered_tile):
		draw_line(
			Vector2(rectangle.end.x, rectangle.position.y),
			Vector2(rectangle.position.x, rectangle.end.y),
			Color(0.20, 0.90, 0.95, 0.95),
			2.0 / _camera_zoom
		)


func _draw_ground_items() -> void:
	for item: TacticalItemInstanceState in _facade.state().get_ground_items():
		# Body items keep the linked character token; do not draw a second
		# generic ground-item diamond beneath it.
		if item.is_body():
			continue
		if not _facade.is_tile_visible_to_player(item.location.map_position):
			continue
		var centre := tile_to_world(item.location.map_position)
		var points := PackedVector2Array([
			centre + Vector2(0.0, -6.0),
			centre + Vector2(6.0, 0.0),
			centre + Vector2(0.0, 6.0),
			centre + Vector2(-6.0, 0.0),
		])
		draw_colored_polygon(points, ITEM_COLOR)
		draw_polyline(
			PackedVector2Array([
				points[0], points[1], points[2], points[3], points[0]
			]),
			Color(0.20, 0.12, 0.03, 1.0),
			1.5 / _camera_zoom
		)


func _draw_attack_targets() -> void:
	if not _attack_targeting:
		return
	for target_id: StringName in _legal_attack_target_ids:
		if not _facade.is_unit_visible_to_player(target_id):
			continue
		var target: TacticalUnitState = _facade.state().get_unit(target_id)
		if target == null:
			continue
		var fill_color: Color = (
			SELECTED_TARGET_COLOR
			if target_id == _selected_attack_target_id
			else LEGAL_TARGET_COLOR
		)
		_draw_target_cells(target, fill_color)

	if (
		not _selected_attack_target_id.is_empty()
		and not _legal_attack_target_ids.has(_selected_attack_target_id)
		and _facade.is_unit_visible_to_player(_selected_attack_target_id)
	):
		var invalid_target: TacticalUnitState = _facade.state().get_unit(
			_selected_attack_target_id
		)
		if invalid_target != null:
			_draw_target_cells(invalid_target, INVALID_TARGET_COLOR)


func _draw_target_cells(unit: TacticalUnitState, fill_color: Color) -> void:
	for cell: Vector2i in _facade.state().occupied_cells_for_unit(unit):
		draw_rect(_tile_rect(cell).grow(-1.0), fill_color, true)
		draw_rect(
			_tile_rect(cell).grow(-2.0),
			TARGET_OUTLINE_COLOR,
			false,
			2.0 / _camera_zoom
		)


func _draw_hover_highlight() -> void:
	if not _map_definition.is_inside(_hovered_tile):
		return
	draw_rect(_tile_rect(_hovered_tile), HOVER_COLOR, true)


func _draw_path_preview() -> void:
	if _attack_targeting and not _selected_attack_target_id.is_empty():
		return
	if _selected_unit_id.is_empty():
		return
	if not _facade.can_unit_act(_selected_unit_id):
		return
	if _preview_result == null or not _preview_result.success:
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return

	var cumulative_cost: int = 0
	var diagonal_parity: int = unit.diagonal_steps_used % 2
	var half_cost: int = _facade.half_action_cost_feet(unit.unit_id)
	var remaining_capacity: int = (
		unit.action_budget.remaining_turn_capacity_feet
	)

	for index: int in range(1, _preview_result.path.size()):
		var previous: Vector2i = _preview_result.path[index - 1]
		var tile: Vector2i = _preview_result.path[index]
		var delta: Vector2i = tile - previous
		var base_cost: int = 5
		if delta.x != 0 and delta.y != 0:
			base_cost = 5 if diagonal_parity == 0 else 10
			diagonal_parity = 1 - diagonal_parity
		cumulative_cost += (
			base_cost * _map_definition.movement_multiplier(tile)
		)

		var tile_color: Color = VALID_PATH_COLOR
		if _movement_mode == &"sprint":
			tile_color = SPRINT_PATH_COLOR
		elif cumulative_cost > remaining_capacity:
			tile_color = INVALID_PATH_COLOR
		elif remaining_capacity - cumulative_cost < half_cost:
			tile_color = AMBER_PATH_COLOR
		draw_rect(_tile_rect(tile), tile_color, true)

	var destination: Vector2i = _preview_result.path.back()
	draw_rect(_tile_rect(destination), HOVER_COLOR, true)
	_draw_detection_badges()
	_draw_reaction_badges()


func _draw_perception_overlays() -> void:
	var observer_ids: Array[StringName] = []
	if _awareness_overlay_enabled:
		for unit: TacticalUnitState in _facade.state().get_enemy_units():
			if _facade.is_unit_visible_to_player(unit.unit_id):
				observer_ids.append(unit.unit_id)
	var selected: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if selected != null and selected.is_player_controlled():
		observer_ids.append(selected.unit_id)
	var hovered_unit: TacticalUnitState = _facade.visible_unit_at_tile(_hovered_tile)
	if hovered_unit != null and hovered_unit.team_id == &"enemy":
		if not observer_ids.has(hovered_unit.unit_id):
			observer_ids.append(hovered_unit.unit_id)
	if _detection_preview != null:
		for observer_id: StringName in _detection_preview.relevant_observer_ids:
			if not observer_ids.has(observer_id):
				observer_ids.append(observer_id)
	for observer_id: StringName in observer_ids:
		var observer: TacticalUnitState = _facade.state().get_unit(observer_id)
		if observer == null:
			continue
		var facing_override: Vector2i = Vector2i.ZERO
		if observer_id == _selected_unit_id:
			facing_override = _facing_preview_direction
		var tiles: Dictionary = _facade.perception_tiles_for_observer(
			observer_id,
			facing_override
		)
		var focused_values: Array = tiles.get("focused", [])
		var aware_values: Array = tiles.get("aware", [])
		var close_values: Array = tiles.get("close", [])
		_draw_awareness_tiles(focused_values, FOCUSED_AWARENESS_COLOR)
		# The selected player's ordinary 40-square sight is already represented
		# by fog of war. Only focused hidden-unit perception is overlaid.
		if observer.team_id != &"player":
			_draw_awareness_tiles(aware_values, ALERTED_AWARENESS_COLOR)
		_draw_awareness_tiles(close_values, CLOSE_AWARENESS_COLOR)


func _draw_last_seen_markers() -> void:
	var positions: Dictionary = _facade.player_last_seen_positions()
	for unit_value: Variant in positions.keys():
		var unit_id := StringName(unit_value)
		if _facade.is_unit_visible_to_player(unit_id):
			continue
		var tile_value: Variant = positions[unit_value]
		if not (tile_value is Vector2i):
			continue
		var tile := Vector2i(tile_value)
		if not _map_definition.is_inside(tile):
			continue
		if not _facade.is_tile_explored_by_player(tile):
			continue
		var centre: Vector2 = tile_to_world(tile)
		draw_arc(
			centre,
			8.0,
			0.0,
			TAU,
			20,
			LAST_SEEN_COLOR,
			1.5 / _camera_zoom,
			true
		)
		draw_line(
			centre + Vector2(-4.0, -4.0),
			centre + Vector2(4.0, 4.0),
			LAST_SEEN_COLOR,
			1.2 / _camera_zoom,
			true
		)
		draw_line(
			centre + Vector2(4.0, -4.0),
			centre + Vector2(-4.0, 4.0),
			LAST_SEEN_COLOR,
			1.2 / _camera_zoom,
			true
		)


func _draw_facing_preview() -> void:
	if _selected_unit_id.is_empty():
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null or not unit.is_player_controlled():
		return
	var direction: Vector2i = _facing_preview_direction
	if direction != Vector2i.ZERO:
		_draw_direction_arrow(tile_to_world(unit.grid_position), direction, 15.0)
	if _preview_result == null or not _preview_result.success:
		return
	if _preview_result.path.size() <= 1:
		return
	var final_direction: Vector2i = TacticalPerceptionRules.normalized_facing(
		_preview_result.path.back()
		- _preview_result.path[_preview_result.path.size() - 2]
	)
	_draw_direction_arrow(
		tile_to_world(_preview_result.path.back()),
		final_direction,
		11.0
	)


func _draw_direction_arrow(
		origin: Vector2,
		direction_value: Vector2i,
		length: float
) -> void:
	var direction: Vector2 = Vector2(direction_value).normalized()
	if direction == Vector2.ZERO:
		return
	var finish: Vector2 = origin + direction * length
	draw_line(
		origin,
		finish,
		FACING_PREVIEW_COLOR,
		2.0 / _camera_zoom,
		true
	)
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([
		finish,
		finish - direction * 5.0 + side * 3.5,
		finish - direction * 5.0 - side * 3.5,
	])
	draw_colored_polygon(points, FACING_PREVIEW_COLOR)


func _draw_awareness_tiles(values: Array, color: Color) -> void:
	for value: Variant in values:
		if not (value is Vector2i):
			continue
		var tile: Vector2i = Vector2i(value)
		if not _facade.is_tile_explored_by_player(tile):
			continue
		draw_rect(_tile_rect(tile).grow(-1.0), color, true)


func _draw_reaction_reservation_preview() -> void:
	if _reaction_reservation_preview_tiles.is_empty():
		return
	for tile: Vector2i in _reaction_reservation_preview_tiles:
		if not _map_definition.is_inside(tile):
			continue
		var rectangle: Rect2 = _tile_rect(tile).grow(-1.0)
		draw_rect(rectangle, REACTION_AREA_FILL, true)
		draw_rect(rectangle, REACTION_AREA_BORDER, false, 1.2 / _camera_zoom)


func _draw_reaction_badges() -> void:
	if _reaction_preview == null or not _reaction_preview.has_reaction_risk():
		return
	for tile_preview: MovementReactionTilePreview in _reaction_preview.tile_previews:
		if _tile_has_detection_badge(tile_preview.tile):
			continue
		if not _map_definition.is_inside(tile_preview.tile):
			continue
		if not _facade.is_tile_explored_by_player(tile_preview.tile):
			continue
		_draw_reaction_tile_badge(tile_preview)


func _draw_reaction_tile_badge(tile_preview: MovementReactionTilePreview) -> void:
	var rectangle: Rect2 = _tile_rect(tile_preview.tile).grow(-1.0)
	var icon_centre: Vector2 = rectangle.position + Vector2(rectangle.size.x * 0.5, 7.5)
	draw_circle(icon_centre, 7.0, DETECTION_BADGE_COLOR)
	draw_arc(icon_centre, 7.0, 0.0, TAU, 24, REACTION_BADGE_OUTLINE, 1.15 / _camera_zoom, true)
	var icon_texture: Texture2D = _reaction_icon(tile_preview.reaction_kind)
	if icon_texture != null:
		draw_texture_rect(
			icon_texture,
			Rect2(icon_centre - Vector2(6.0, 6.0), Vector2(12.0, 12.0)),
			false
		)
	if tile_preview.reaction_count > 1:
		draw_string(
			ThemeDB.fallback_font, icon_centre + Vector2(4.0, -4.0),
			"×%d" % tile_preview.reaction_count, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7,
			Color.WHITE
		)
	var percent_strip := Rect2(
		rectangle.position + Vector2(0.0, rectangle.size.y - 10.0),
		Vector2(rectangle.size.x, 10.0)
	)
	draw_rect(percent_strip, DETECTION_BADGE_COLOR, true)
	draw_line(percent_strip.position, Vector2(percent_strip.end.x, percent_strip.position.y), REACTION_BADGE_OUTLINE, 1.0 / _camera_zoom, true)
	draw_string(
		ThemeDB.fallback_font, percent_strip.position + Vector2(0.5, 8.0),
		tile_preview.display_percent(), HORIZONTAL_ALIGNMENT_CENTER,
		percent_strip.size.x - 1.0, 9, _reaction_hit_chance_color(tile_preview.hit_chance_percent)
	)


func _reaction_icon(kind: StringName) -> Texture2D:
	match kind:
		ReactionCandidate.KIND_OVERWATCH:
			return REACTION_OVERWATCH_BOW_ICON
		ReactionCandidate.KIND_BRACE:
			return REACTION_BRACE_SPEAR_ICON
	return REACTION_AOO_ICON


func _reaction_hit_chance_color(chance: int) -> Color:
	if chance >= 70:
		return Color(1.0, 0.38, 0.28, 1.0)
	if chance >= 40:
		return Color(1.0, 0.78, 0.34, 1.0)
	return Color(0.56, 1.0, 0.66, 1.0)


func _draw_detection_badges() -> void:
	if _detection_preview == null or not _detection_preview.has_detection_risk():
		return
	for tile_preview: MovementDetectionTilePreview in _detection_preview.tile_previews:
		if not _map_definition.is_inside(tile_preview.tile):
			continue
		if not _facade.is_tile_explored_by_player(tile_preview.tile):
			continue
		_draw_detection_tile_badge(tile_preview)


func _draw_detection_tile_badge(
		tile_preview: MovementDetectionTilePreview
) -> void:
	var rectangle: Rect2 = _tile_rect(tile_preview.tile).grow(-1.0)
	var icon_centre: Vector2 = rectangle.position + Vector2(
		rectangle.size.x * 0.5,
		7.5
	)
	draw_circle(icon_centre, 7.0, DETECTION_BADGE_COLOR)
	draw_arc(
		icon_centre,
		7.0,
		0.0,
		TAU,
		24,
		DETECTION_BADGE_OUTLINE,
		1.15 / _camera_zoom,
		true
	)
	var icon_rect := Rect2(
		icon_centre - Vector2(6.0, 6.0),
		Vector2(12.0, 12.0)
	)
	draw_texture_rect(STEALTH_HOOD_ICON, icon_rect, false)
	if tile_preview.automatic_detection:
		draw_line(
			icon_rect.position,
			icon_rect.end,
			Color(1.0, 0.22, 0.16, 1.0),
			2.0 / _camera_zoom,
			true
		)

	var percent_strip := Rect2(
		rectangle.position + Vector2(0.0, rectangle.size.y - 10.0),
		Vector2(rectangle.size.x, 10.0)
	)
	draw_rect(percent_strip, DETECTION_BADGE_COLOR, true)
	draw_line(
		percent_strip.position,
		Vector2(percent_strip.end.x, percent_strip.position.y),
		DETECTION_BADGE_OUTLINE,
		1.0 / _camera_zoom,
		true
	)
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		percent_strip.position + Vector2(0.5, 8.0),
		tile_preview.display_percent(),
		HORIZONTAL_ALIGNMENT_CENTER,
		percent_strip.size.x - 1.0,
		9,
		_avoid_chance_color(tile_preview)
	)


func _avoid_chance_color(
		tile_preview: MovementDetectionTilePreview
) -> Color:
	if tile_preview == null or tile_preview.has_unknown_observers:
		return Color(0.88, 0.91, 0.96, 1.0)
	var chance: int = tile_preview.avoid_detection_chance_percent
	if chance >= 70:
		return Color(0.52, 1.0, 0.62, 1.0)
	if chance >= 40:
		return Color(1.0, 0.88, 0.45, 1.0)
	return Color(1.0, 0.42, 0.32, 1.0)


func _draw_selection_outline() -> void:
	if _selected_unit_id.is_empty():
		return
	if not _facade.is_unit_visible_to_player(_selected_unit_id):
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return
	for cell: Vector2i in _facade.state().occupied_cells_for_unit(unit):
		draw_rect(
			_tile_rect(cell).grow(-2.0),
			Color(1.0, 0.82, 0.22, 1.0),
			false,
			3.0 / _camera_zoom
		)


func tile_to_world(tile: Vector2i) -> Vector2:
	return (
		BOARD_ORIGIN
		+ Vector2(tile) * TILE_SIZE
		+ Vector2.ONE * (TILE_SIZE * 0.5)
	)


func screen_to_tile(screen_position: Vector2) -> Vector2i:
	return _screen_to_tile(screen_position)


func tile_to_screen(tile: Vector2i) -> Vector2:
	return to_global(tile_to_world(tile))


func _screen_to_tile(screen_position: Vector2) -> Vector2i:
	var local_position: Vector2 = to_local(screen_position) - BOARD_ORIGIN
	return Vector2i(
		int(floor(local_position.x / TILE_SIZE)),
		int(floor(local_position.y / TILE_SIZE))
	)


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(
		BOARD_ORIGIN + Vector2(tile) * TILE_SIZE,
		Vector2.ONE * TILE_SIZE
	)


func _zoom_at(screen_position: Vector2, requested_zoom: float) -> void:
	var clamped_zoom: float = clampf(requested_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(clamped_zoom, _camera_zoom):
		return
	var local_anchor: Vector2 = to_local(screen_position)
	_camera_zoom = clamped_zoom
	scale = Vector2.ONE * _camera_zoom
	if _static_layer != null:
		_static_layer.set_camera_zoom(_camera_zoom)
	if _fog_layer != null:
		_fog_layer.set_camera_zoom(_camera_zoom)
	var transformed_anchor: Vector2 = to_global(local_anchor)
	position += screen_position - transformed_anchor
	_clamp_camera()
	zoom_changed.emit(int(round(_camera_zoom * 100.0)))


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	position += screen_delta
	_clamp_camera()


func _clamp_camera() -> void:
	if _map_definition == null:
		return
	var play_area: Rect2 = _play_area_rect()
	var scaled_size: Vector2 = (
		Vector2(_map_definition.grid_size) * TILE_SIZE * _camera_zoom
	)
	var play_end: Vector2 = play_area.position + play_area.size

	if scaled_size.x <= play_area.size.x:
		position.x = play_area.get_center().x - scaled_size.x * 0.5
	else:
		position.x = clampf(
			position.x,
			play_end.x - scaled_size.x,
			play_area.position.x
		)
	if scaled_size.y <= play_area.size.y:
		position.y = play_area.get_center().y - scaled_size.y * 0.5
	else:
		position.y = clampf(
			position.y,
			play_end.y - scaled_size.y,
			play_area.position.y
		)


func _play_area_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Rect2(
		Vector2(PLAY_AREA_LEFT, PLAY_AREA_TOP),
		Vector2(
			maxf(1.0, viewport_size.x - PLAY_AREA_LEFT - PLAY_AREA_RIGHT_MARGIN),
			maxf(1.0, PLAY_AREA_BOTTOM - PLAY_AREA_TOP)
		)
	)
