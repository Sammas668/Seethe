extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Stage44e3b2ImmediateHitReactionTests.run(self)
	if failures.is_empty():
		print("Stage 4.4e3b2 immediate hit-reaction timing tests passed.")
		quit(0)
		return
	print("Stage 4.4e3b2 immediate hit-reaction timing tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
