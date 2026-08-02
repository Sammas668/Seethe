extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = (
		Stage45E7PrecomputedShadowcastVisibilityTests.run(self)
	)
	if failures.is_empty():
		print("Stage 4.5e7a Bounded Visibility Prewarm tests passed.")
		quit(0)
		return
	print("Stage 4.5e7a Bounded Visibility Prewarm tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
