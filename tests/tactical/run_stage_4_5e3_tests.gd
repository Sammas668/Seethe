extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage45E3AttackImpactCriticalPathTests.run(self)
	if failures.is_empty():
		print("Stage 4.5e3 Attack Impact Critical Path tests passed.")
		quit(0)
		return
	print("Stage 4.5e3 Attack Impact Critical Path tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
