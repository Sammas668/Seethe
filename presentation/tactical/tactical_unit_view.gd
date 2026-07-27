class_name TacticalUnitView
extends Node2D

@export var unit_color: Color = Color(0.15, 0.48, 0.92, 1.0)
@export var unit_radius: float = 11.0

var unit_id: StringName = &""
var _selected: bool = false
var _visibly_finished: bool = false
var _tile_size: float = 32.0
var _board_origin: Vector2 = Vector2.ZERO
var _active_tween: Tween


func configure(
        unit_state: TacticalUnitState,
        board_origin: Vector2,
        tile_size: float,
        display_color: Color
) -> void:
    unit_id = unit_state.unit_id
    unit_color = display_color
    _board_origin = board_origin
    _tile_size = tile_size
    position = _tile_to_world(unit_state.grid_position)
    _visibly_finished = unit_state.action_budget.is_visibly_finished()
    queue_redraw()


func set_selected(selected: bool) -> void:
    _selected = selected
    queue_redraw()


func set_visibly_finished(finished: bool) -> void:
    _visibly_finished = finished
    queue_redraw()


func snap_to_tile(tile: Vector2i) -> void:
    if _active_tween != null and _active_tween.is_valid():
        _active_tween.kill()
    position = _tile_to_world(tile)


func animate_path(path: Array[Vector2i]) -> void:
    if path.size() <= 1:
        return

    if _active_tween != null and _active_tween.is_valid():
        _active_tween.kill()

    _active_tween = create_tween()
    _active_tween.set_trans(Tween.TRANS_SINE)
    _active_tween.set_ease(Tween.EASE_IN_OUT)

    for index: int in range(1, path.size()):
        _active_tween.tween_property(
            self,
            "position",
            _tile_to_world(path[index]),
            0.08
        )


func _draw() -> void:
    var visible_color := unit_color
    if _visibly_finished:
        visible_color = Color(
            unit_color.r * 0.42,
            unit_color.g * 0.42,
            unit_color.b * 0.42,
            0.9
        )

    draw_circle(Vector2.ZERO, unit_radius, visible_color)
    draw_arc(
        Vector2.ZERO,
        unit_radius,
        0.0,
        TAU,
        32,
        Color(0.04, 0.08, 0.13, 1.0),
        2.0,
        true
    )

    if _visibly_finished:
        draw_line(
            Vector2(-7.0, 7.0),
            Vector2(7.0, -7.0),
            Color(0.88, 0.88, 0.88, 0.9),
            2.0
        )

    if _selected:
        draw_arc(
            Vector2.ZERO,
            unit_radius + 5.0,
            0.0,
            TAU,
            40,
            Color(1.0, 0.82, 0.22, 1.0),
            3.0,
            true
        )


func _tile_to_world(tile: Vector2i) -> Vector2:
    return _board_origin + Vector2(tile) * _tile_size + Vector2.ONE * (_tile_size * 0.5)
