extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Stage44e3aClickLockedMovementPreviewTests.run(self)
	if failures.is_empty():
		print("Stage 4.4e3a click-locked movement preview tests passed.")
		quit(0)
		return
	print("Stage 4.4e3a click-locked movement preview tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
