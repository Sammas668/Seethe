extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await Stage44e3bReadabilityStealthPreviewTests.run(self)
	if failures.is_empty():
		print("Stage 4.4e3b readability cadence and Stealth preview tests passed.")
		quit(0)
		return
	print("Stage 4.4e3b readability cadence and Stealth preview tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
