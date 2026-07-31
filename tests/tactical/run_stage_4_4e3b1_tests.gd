extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage44e3b1StealthCoverPriorityTests.run(self)
	if failures.is_empty():
		print("Stage 4.4e3b1 Stealth/cover display-priority tests passed.")
		quit(0)
		return
	print("Stage 4.4e3b1 Stealth/cover display-priority tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
