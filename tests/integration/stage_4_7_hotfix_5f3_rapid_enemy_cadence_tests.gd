class_name Stage47Hotfix5f3RapidEnemyCadenceTests
extends RefCounted


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var view := TacticalUnitView.new()
	view.unit_id = &"cadence_test_unit"
	tree.root.add_child(view)
	var path: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
	]
	var started_usec: int = Time.get_ticks_usec()
	_expect(
		view.animate_path(path, [], 0.12),
		"A multi-tile rapid enemy route must start a movement tween.",
		failures
	)
	if view.is_movement_animating():
		await view.movement_animation_finished
	var elapsed_usec: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_expect(
		view.position.distance_to(Vector2(112.0, 16.0)) < 0.1,
		"Continuous movement must finish on the final tile centre.",
		failures
	)
	_expect(
		elapsed_usec < 500_000,
		"The focused three-tile movement presentation must remain well below half a second.",
		failures
	)
	view.queue_free()
	return failures


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
