extends RefCounted


func draw_unseen(
	canvas: CanvasItem,
	rectangle: Rect2,
	zoom_level: float,
	variant_seed: int,
	base_color: Color
) -> void:
	canvas.draw_rect(rectangle, base_color, true)
	if zoom_level < 0.80:
		return
	var wash_alpha: float = 0.018 + float(variant_seed % 3) * 0.006
	var wash_color := Color(0.20, 0.15, 0.25, wash_alpha)
	var offset: float = float(variant_seed % 8)
	canvas.draw_line(
		Vector2(rectangle.position.x - 2.0, rectangle.position.y + 8.0 + offset),
		Vector2(rectangle.end.x + 2.0, rectangle.end.y - 8.0 + offset),
		wash_color,
		1.0 / maxf(zoom_level, 0.1)
	)


func draw_explored(
	canvas: CanvasItem,
	rectangle: Rect2,
	zoom_level: float,
	variant_seed: int,
	overlay_color: Color
) -> void:
	canvas.draw_rect(rectangle, overlay_color, true)
	if zoom_level < 0.68:
		return
	var memory_wash := Color(
		0.15,
		0.18,
		0.23,
		0.035 + float(variant_seed % 2) * 0.012
	)
	canvas.draw_line(
		Vector2(rectangle.position.x, rectangle.end.y - 4.0),
		Vector2(rectangle.end.x, rectangle.position.y + 4.0),
		memory_wash,
		0.8 / maxf(zoom_level, 0.1)
	)
