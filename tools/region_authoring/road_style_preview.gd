class_name RoadStylePreview
extends Control

var road_type: StringName = RegionRoadType.LOCAL_ROAD:
	set(value):
		road_type = RegionRoadType.normalize(value)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(62, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var start := Vector2(5.0, size.y * 0.5)
	var finish := Vector2(size.x - 5.0, size.y * 0.5)
	match road_type:
		RegionRoadType.PRIMARY_ROAD:
			draw_line(start, finish, Color("2a241a"), 11.0, true)
			draw_line(start, finish, Color("d9c28a"), 7.0, true)
			draw_line(start, finish, Color("f1e2b8"), 1.5, true)
		RegionRoadType.FOREST_TRACK:
			var offset := Vector2(0.0, 3.0)
			draw_line(start - offset, finish - offset, Color("2d251b"), 3.8, true)
			draw_line(start + offset, finish + offset, Color("2d251b"), 3.8, true)
			draw_line(start - offset, finish - offset, Color("7a5734"), 1.8, true)
			draw_line(start + offset, finish + offset, Color("7a5734"), 1.8, true)
		_:
			draw_line(start, finish, Color("39291c"), 8.0, true)
			draw_line(start, finish, Color("b97b43"), 5.0, true)
