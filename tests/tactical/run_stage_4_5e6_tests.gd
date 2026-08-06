extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage45E6IncrementalVisibilityFogTests.run(self)
	if failures.is_empty():
		print("Stage 4.5e6 Incremental Visibility and Fog tests passed.")
		quit(0)
		return
	print("Stage 4.5e6 Incremental Visibility and Fog tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
