class_name Stage4254cConfirmedFacingAnimationTests
extends RefCounted


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	_test_preview_does_not_rotate_counter(failures)
	_test_cancellation_needs_no_return_animation(failures)
	_test_confirmation_starts_committed_turn_tween(failures)
	return failures


static func _test_preview_does_not_rotate_counter(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _create_view_fixture(failures)
	var view: TacticalUnitView = fixture.get("view") as TacticalUnitView
	if view == null:
		return
	var original_angle: float = float(view.get("_visual_facing_angle"))
	view.preview_facing(Vector2i(1, 0))
	_expect(
		is_equal_approx(float(view.get("_visual_facing_angle")), original_angle),
		"The first right-click preview must not rotate the counter.",
		failures
	)
	_expect(
		bool(view.get("_preview_facing_active")),
		"The view must still remember that facing preview is active.",
		failures
	)
	_expect(
		view.get("_facing_tween") == null,
		"Facing preview must not create a turn tween.",
		failures
	)
	_destroy_view_fixture(fixture)


static func _test_cancellation_needs_no_return_animation(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _create_view_fixture(failures)
	var view: TacticalUnitView = fixture.get("view") as TacticalUnitView
	if view == null:
		return
	var original_angle: float = float(view.get("_visual_facing_angle"))
	view.preview_facing(Vector2i(-1, 0))
	view.cancel_facing_preview()
	_expect(
		is_equal_approx(float(view.get("_visual_facing_angle")), original_angle),
		"Cancelling preview must leave the counter at its committed angle.",
		failures
	)
	_expect(
		not bool(view.get("_preview_facing_active")),
		"Cancelling must clear the preview-active flag.",
		failures
	)
	_expect(
		view.get("_facing_tween") == null,
		"Cancelling an unrotated preview must not create a return tween.",
		failures
	)
	_destroy_view_fixture(fixture)


static func _test_confirmation_starts_committed_turn_tween(
		failures: Array[String]
) -> void:
	var fixture: Dictionary = _create_view_fixture(failures)
	var view: TacticalUnitView = fixture.get("view") as TacticalUnitView
	if view == null:
		return
	view.preview_facing(Vector2i(1, 0))
	view.commit_facing_preview(Vector2i(1, 0))
	var tween: Tween = view.get("_facing_tween") as Tween
	_expect(
		Vector2i(view.get("_committed_facing_direction")) == Vector2i(1, 0),
		"Second-click confirmation must update the committed visual direction.",
		failures
	)
	_expect(
		not bool(view.get("_preview_facing_active")),
		"Confirmation must clear the preview-active flag.",
		failures
	)
	_expect(
		tween != null and tween.is_valid(),
		"Confirmation must create the quick committed-facing turn tween.",
		failures
	)
	_destroy_view_fixture(fixture)


static func _create_view_fixture(failures: Array[String]) -> Dictionary:
	var main_loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = main_loop as SceneTree
	if tree == null:
		failures.append("Facing-animation tests require a SceneTree.")
		return {}
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var unit: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	if unit == null:
		failures.append("The facing-animation fixture needs the Marauder.")
		return {}
	unit.set_facing(Vector2i(0, -1))
	var view := TacticalUnitView.new()
	tree.root.add_child(view)
	view.configure(unit, Vector2.ZERO, 28.0, Color.WHITE)
	return {
		"view": view,
	}


static func _destroy_view_fixture(fixture: Dictionary) -> void:
	var view: TacticalUnitView = fixture.get("view") as TacticalUnitView
	if view == null:
		return
	var tween: Tween = view.get("_facing_tween") as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	view.free()


static func _expect(
		condition: bool,
		message: String,
		failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
