class_name TacticalBodyStatusOverlay
extends Control

const UNCONSCIOUS_ZZZ_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/status_unconscious_zzz.svg"
)
const DYING_SKULL_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/status_dying_skull.svg"
)
const DEAD_SKULL_ICON: Texture2D = preload(
	"res://presentation/tactical/icons/status_dead_skull.svg"
)

var _snapshot: Dictionary = TacticalStatusBadgeProvider.empty_snapshot()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


func configure(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var primary_kind := StringName(_snapshot.get(
		"primary_kind",
		TacticalStatusBadgeProvider.BADGE_KIND_NONE
	))
	var restrained: bool = bool(_snapshot.get("restrained", false))
	if (
		primary_kind == TacticalStatusBadgeProvider.BADGE_KIND_NONE
		and not restrained
	):
		return

	var shorter_side: float = minf(size.x, size.y)
	var radius: float = clampf(shorter_side * 0.19, 10.0, 17.0)
	var pip_radius: float = clampf(radius * 0.13, 1.4, 2.1)
	var pip_spacing: float = pip_radius * 2.9
	var pip_offset: float = radius + pip_radius + 3.0
	var margin: float = maxf(4.0, radius * 0.32)
	var primary_centre := Vector2(
		margin + radius + pip_offset,
		size.y - margin - radius
	)

	match primary_kind:
		TacticalStatusBadgeProvider.BADGE_KIND_DEAD:
			_draw_dead_badge(primary_centre, radius)
		TacticalStatusBadgeProvider.BADGE_KIND_DYING:
			_draw_dying_badge(
				primary_centre,
				radius,
				pip_radius,
				pip_spacing,
				pip_offset
			)
		TacticalStatusBadgeProvider.BADGE_KIND_UNCONSCIOUS:
			_draw_unconscious_badge(primary_centre, radius)
			if bool(_snapshot.get("stable", false)):
				_draw_stable_marker(
					primary_centre + Vector2(radius * 0.72, radius * 0.72),
					radius * 0.42
				)

	if restrained:
		_draw_restrained_badge(
			Vector2(size.x - margin - radius * 0.72, margin + radius * 0.72),
			radius * 0.72
		)


func _draw_badge_backplate(
		centre: Vector2,
		radius: float,
		background_color: Color,
		outline_color: Color
) -> void:
	draw_circle(centre, radius, background_color)
	draw_arc(
		centre,
		radius,
		0.0,
		TAU,
		28,
		outline_color,
		maxf(1.1, radius * 0.10),
		true
	)


func _draw_unconscious_badge(centre: Vector2, radius: float) -> void:
	_draw_badge_backplate(
		centre,
		radius,
		Color(0.08, 0.075, 0.18, 0.98),
		Color(0.56, 0.70, 0.98, 1.0)
	)
	var icon_size := Vector2.ONE * radius * 1.55
	draw_texture_rect(
		UNCONSCIOUS_ZZZ_ICON,
		Rect2(centre - icon_size * 0.5, icon_size),
		false
	)


func _draw_dying_badge(
		centre: Vector2,
		radius: float,
		pip_radius: float,
		pip_spacing: float,
		pip_offset: float
) -> void:
	_draw_badge_backplate(
		centre,
		radius,
		Color(0.16, 0.025, 0.035, 0.98),
		Color(0.94, 0.28, 0.25, 1.0)
	)
	var icon_size := Vector2.ONE * radius * 1.50
	draw_texture_rect(
		DYING_SKULL_ICON,
		Rect2(centre - icon_size * 0.5, icon_size),
		false
	)
	var successes: int = clampi(int(_snapshot.get("dying_successes", 0)), 0, 3)
	var failures: int = clampi(int(_snapshot.get("dying_failures", 0)), 0, 3)
	for index: int in range(3):
		var y: float = centre.y - pip_spacing + float(index) * pip_spacing
		_draw_track_pip(
			Vector2(centre.x - pip_offset, y),
			pip_radius,
			index < successes,
			Color(0.24, 0.78, 0.35, 1.0),
			Color(0.10, 0.24, 0.13, 1.0)
		)
		_draw_track_pip(
			Vector2(centre.x + pip_offset, y),
			pip_radius,
			index < failures,
			Color(0.92, 0.16, 0.19, 1.0),
			Color(0.38, 0.10, 0.12, 1.0)
		)


func _draw_dead_badge(centre: Vector2, radius: float) -> void:
	_draw_badge_backplate(
		centre,
		radius,
		Color(0.075, 0.07, 0.08, 0.98),
		Color(0.62, 0.59, 0.58, 1.0)
	)
	var icon_size := Vector2.ONE * radius * 1.55
	draw_texture_rect(
		DEAD_SKULL_ICON,
		Rect2(centre - icon_size * 0.5, icon_size),
		false
	)


func _draw_stable_marker(centre: Vector2, radius: float) -> void:
	draw_circle(centre, radius, Color(0.055, 0.17, 0.085, 0.99))
	draw_arc(
		centre,
		radius,
		0.0,
		TAU,
		18,
		Color(0.34, 0.88, 0.48, 1.0),
		maxf(1.0, radius * 0.18),
		true
	)
	var start := centre + Vector2(-radius * 0.45, 0.0)
	var middle := centre + Vector2(-radius * 0.10, radius * 0.34)
	var finish := centre + Vector2(radius * 0.50, -radius * 0.42)
	draw_polyline(
		PackedVector2Array([start, middle, finish]),
		Color(0.72, 1.0, 0.76, 1.0),
		maxf(1.2, radius * 0.22),
		true
	)


func _draw_restrained_badge(centre: Vector2, radius: float) -> void:
	draw_circle(centre, radius, Color(0.13, 0.09, 0.04, 0.98))
	draw_arc(
		centre,
		radius,
		0.0,
		TAU,
		22,
		Color(0.86, 0.68, 0.28, 1.0),
		maxf(1.1, radius * 0.15),
		true
	)
	var loop_radius: float = radius * 0.38
	var loop_offset: float = radius * 0.27
	draw_arc(
		centre + Vector2(-loop_offset, 0.0),
		loop_radius,
		0.0,
		TAU,
		18,
		Color(0.94, 0.83, 0.48, 1.0),
		maxf(1.0, radius * 0.12),
		true
	)
	draw_arc(
		centre + Vector2(loop_offset, 0.0),
		loop_radius,
		0.0,
		TAU,
		18,
		Color(0.94, 0.83, 0.48, 1.0),
		maxf(1.0, radius * 0.12),
		true
	)


func _draw_track_pip(
		centre: Vector2,
		radius: float,
		filled: bool,
		fill_color: Color,
		empty_color: Color
) -> void:
	draw_circle(centre, radius, fill_color if filled else empty_color)
	draw_arc(
		centre,
		radius,
		0.0,
		TAU,
		12,
		Color(0.95, 0.88, 0.74, 0.90),
		maxf(0.6, radius * 0.26),
		true
	)
