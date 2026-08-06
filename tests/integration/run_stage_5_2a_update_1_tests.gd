extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage52aUpdate1UnifiedFacilityTests.run()
	if failures.is_empty():
		print("Stage 5.2a Update 1 unified-facility runtime tests passed.")
		quit(0)
		return
	print("Stage 5.2a Update 1 runtime tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
