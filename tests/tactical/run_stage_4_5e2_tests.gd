extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage45E2CombatFeedbackTests.run(self)
	if failures.is_empty():
		print("Stage 4.5e2 Immediate Combat Feedback tests passed.")
		quit(0)
		return
	print("Stage 4.5e2 Immediate Combat Feedback tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
