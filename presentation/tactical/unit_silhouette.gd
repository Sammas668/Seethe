class_name UnitSilhouette
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var centre_x := size.x * 0.5
	var top := 22.0
	var head_radius := minf(30.0, size.x * 0.10)

	draw_circle(
		Vector2(centre_x, top + head_radius),
		head_radius,
		Color(0.20, 0.23, 0.25, 1.0)
	)

	var torso_top := top + head_radius * 2.0 + 9.0
	var torso_width := minf(105.0, size.x * 0.34)
	var torso_height := minf(125.0, size.y * 0.42)
	var torso := Rect2(
		Vector2(centre_x - torso_width * 0.5, torso_top),
		Vector2(torso_width, torso_height)
	)
	draw_rect(torso, Color(0.15, 0.18, 0.20, 1.0), true)

	var shoulder_y := torso_top + 18.0
	draw_line(
		Vector2(centre_x - torso_width * 0.48, shoulder_y),
		Vector2(centre_x - torso_width * 0.85, torso_top + torso_height * 0.72),
		Color(0.18, 0.21, 0.23, 1.0),
		25.0,
		true
	)
	draw_line(
		Vector2(centre_x + torso_width * 0.48, shoulder_y),
		Vector2(centre_x + torso_width * 0.85, torso_top + torso_height * 0.72),
		Color(0.18, 0.21, 0.23, 1.0),
		25.0,
		true
	)

	var hip_y := torso_top + torso_height
	draw_line(
		Vector2(centre_x - torso_width * 0.24, hip_y),
		Vector2(centre_x - torso_width * 0.30, size.y - 30.0),
		Color(0.16, 0.19, 0.21, 1.0),
		30.0,
		true
	)
	draw_line(
		Vector2(centre_x + torso_width * 0.24, hip_y),
		Vector2(centre_x + torso_width * 0.30, size.y - 30.0),
		Color(0.16, 0.19, 0.21, 1.0),
		30.0,
		true
	)
