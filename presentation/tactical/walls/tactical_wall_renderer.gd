extends RefCounted

const NORTH: int = 1
const EAST: int = 2
const SOUTH: int = 4
const WEST: int = 8


func draw_wall(
	canvas: CanvasItem,
	rectangle: Rect2,
	material_definition: Resource,
	connections: int,
	zoom_level: float,
	variant_seed: int
) -> void:
	if canvas == null or material_definition == null:
		return
	var material_id: StringName = StringName(
		str(material_definition.get("material_id"))
	)
	if material_id == TacticalMapDefinition.WALL_MATERIAL_WOOD:
		_draw_wood(
			canvas,
			rectangle,
			material_definition,
			connections,
			zoom_level,
			variant_seed
		)
	else:
		_draw_stone(
			canvas,
			rectangle,
			material_definition,
			connections,
			zoom_level,
			variant_seed
		)


func _draw_stone(
	canvas: CanvasItem,
	rectangle: Rect2,
	definition: Resource,
	connections: int,
	zoom_level: float,
	variant_seed: int
) -> void:
	var base_color: Color = _definition_color(
		definition,
		"base_color",
		Color(0.29, 0.31, 0.32, 1.0)
	)
	var inset_color: Color = _definition_color(
		definition,
		"inset_color",
		Color(0.41, 0.42, 0.42, 1.0)
	)
	var outline_color: Color = _definition_color(
		definition,
		"outline_color",
		Color(0.05, 0.05, 0.05, 1.0)
	)
	var detail_color: Color = _definition_color(
		definition,
		"detail_color",
		Color(0.13, 0.14, 0.15, 1.0)
	)
	var highlight_color: Color = _definition_color(
		definition,
		"highlight_color",
		Color(0.60, 0.60, 0.58, 1.0)
	)
	var far_color: Color = _definition_color(
		definition,
		"far_color",
		base_color
	)
	var line_width: float = maxf(0.75, 1.35 / maxf(zoom_level, 0.1))
	canvas.draw_rect(
		Rect2(rectangle.position + Vector2(2.0, 3.0), rectangle.size),
		Color(0.015, 0.012, 0.01, 0.70),
		true
	)
	canvas.draw_rect(
		rectangle,
		far_color if zoom_level < 0.55 else base_color,
		true
	)
	canvas.draw_rect(rectangle.grow(-2.0), inset_color, true)
	_draw_external_edges(
		canvas,
		rectangle,
		connections,
		outline_color,
		line_width * 1.8
	)
	if zoom_level < 0.55:
		return
	var upper_y: float = rectangle.position.y + rectangle.size.y * 0.34
	var lower_y: float = rectangle.position.y + rectangle.size.y * 0.68
	canvas.draw_line(
		Vector2(rectangle.position.x + 1.5, upper_y),
		Vector2(rectangle.end.x - 1.5, upper_y),
		detail_color,
		line_width
	)
	canvas.draw_line(
		Vector2(rectangle.position.x + 1.5, lower_y),
		Vector2(rectangle.end.x - 1.5, lower_y),
		detail_color,
		line_width
	)
	var offset_a: float = 7.0 + float(variant_seed % 5)
	var offset_b: float = 16.0 + float(int(float(variant_seed) / 7.0) % 5)
	canvas.draw_line(
		Vector2(rectangle.position.x + offset_a, rectangle.position.y + 1.5),
		Vector2(rectangle.position.x + offset_a, upper_y),
		detail_color,
		line_width
	)
	canvas.draw_line(
		Vector2(rectangle.position.x + offset_b, upper_y),
		Vector2(rectangle.position.x + offset_b, lower_y),
		detail_color,
		line_width
	)
	canvas.draw_line(
		Vector2(rectangle.position.x + offset_a + 4.0, lower_y),
		Vector2(rectangle.position.x + offset_a + 4.0, rectangle.end.y - 1.5),
		detail_color,
		line_width
	)
	canvas.draw_line(
		Vector2(rectangle.position.x + 2.0, rectangle.position.y + 2.0),
		Vector2(rectangle.end.x - 2.0, rectangle.position.y + 2.0),
		highlight_color,
		maxf(0.55, line_width * 0.65)
	)
	if zoom_level >= 1.05:
		var crack_start: Vector2 = rectangle.position + Vector2(
			9.0 + float(variant_seed % 8),
			6.0 + float(int(float(variant_seed) / 11.0) % 8)
		)
		canvas.draw_polyline(
			PackedVector2Array([
				crack_start,
				crack_start + Vector2(3.0, 2.0),
				crack_start + Vector2(1.0, 5.0),
				crack_start + Vector2(5.0, 8.0),
			]),
			detail_color,
			maxf(0.55, line_width * 0.65)
		)


func _draw_wood(
	canvas: CanvasItem,
	rectangle: Rect2,
	definition: Resource,
	connections: int,
	zoom_level: float,
	variant_seed: int
) -> void:
	var base_color: Color = _definition_color(
		definition,
		"base_color",
		Color(0.29, 0.17, 0.09, 1.0)
	)
	var inset_color: Color = _definition_color(
		definition,
		"inset_color",
		Color(0.43, 0.26, 0.13, 1.0)
	)
	var outline_color: Color = _definition_color(
		definition,
		"outline_color",
		Color(0.07, 0.035, 0.02, 1.0)
	)
	var detail_color: Color = _definition_color(
		definition,
		"detail_color",
		Color(0.15, 0.075, 0.03, 1.0)
	)
	var highlight_color: Color = _definition_color(
		definition,
		"highlight_color",
		Color(0.67, 0.41, 0.20, 1.0)
	)
	var far_color: Color = _definition_color(
		definition,
		"far_color",
		base_color
	)
	var line_width: float = maxf(0.75, 1.25 / maxf(zoom_level, 0.1))
	canvas.draw_rect(
		Rect2(rectangle.position + Vector2(2.0, 3.0), rectangle.size),
		Color(0.018, 0.008, 0.003, 0.72),
		true
	)
	canvas.draw_rect(
		rectangle,
		far_color if zoom_level < 0.55 else base_color,
		true
	)
	canvas.draw_rect(rectangle.grow(-2.0), inset_color, true)
	_draw_external_edges(
		canvas,
		rectangle,
		connections,
		outline_color,
		line_width * 1.9
	)
	if zoom_level < 0.55:
		return
	var horizontal_bias: bool = (
		(connections & (EAST | WEST)) != 0
		and (connections & (NORTH | SOUTH)) == 0
	)
	if horizontal_bias:
		for index: int in range(1, 4):
			var line_y: float = (
				rectangle.position.y
				+ rectangle.size.y * float(index) / 4.0
			)
			canvas.draw_line(
				Vector2(rectangle.position.x + 1.5, line_y),
				Vector2(rectangle.end.x - 1.5, line_y),
				detail_color,
				line_width
			)
	else:
		for index: int in range(1, 4):
			var line_x: float = (
				rectangle.position.x
				+ rectangle.size.x * float(index) / 4.0
			)
			canvas.draw_line(
				Vector2(line_x, rectangle.position.y + 1.5),
				Vector2(line_x, rectangle.end.y - 1.5),
				detail_color,
				line_width
			)
	canvas.draw_line(
		Vector2(rectangle.position.x + 2.0, rectangle.position.y + 2.0),
		Vector2(rectangle.end.x - 2.0, rectangle.position.y + 2.0),
		highlight_color,
		maxf(0.55, line_width * 0.70)
	)
	if zoom_level >= 1.05:
		var grain_y: float = rectangle.position.y + 8.0 + float(variant_seed % 10)
		canvas.draw_polyline(
			PackedVector2Array([
				Vector2(rectangle.position.x + 4.0, grain_y),
				Vector2(rectangle.position.x + 10.0, grain_y - 1.5),
				Vector2(rectangle.position.x + 17.0, grain_y + 1.0),
				Vector2(rectangle.end.x - 4.0, grain_y - 0.5),
			]),
			detail_color,
			maxf(0.55, line_width * 0.60)
		)
		var peg_position: Vector2 = rectangle.position + Vector2(
			6.0 + float(variant_seed % 15),
			6.0 + float(int(float(variant_seed) / 13.0) % 15)
		)
		canvas.draw_circle(
			peg_position,
			1.3,
			outline_color
		)


func _draw_external_edges(
	canvas: CanvasItem,
	rectangle: Rect2,
	connections: int,
	color: Color,
	width: float
) -> void:
	if (connections & NORTH) == 0:
		canvas.draw_line(rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), color, width)
	if (connections & EAST) == 0:
		canvas.draw_line(Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, color, width)
	if (connections & SOUTH) == 0:
		canvas.draw_line(Vector2(rectangle.position.x, rectangle.end.y), rectangle.end, color, width)
	if (connections & WEST) == 0:
		canvas.draw_line(rectangle.position, Vector2(rectangle.position.x, rectangle.end.y), color, width)


func _definition_color(
	definition: Resource,
	property_name: String,
	fallback: Color
) -> Color:
	var value: Variant = definition.get(property_name)
	if value is Color:
		return value
	return fallback
