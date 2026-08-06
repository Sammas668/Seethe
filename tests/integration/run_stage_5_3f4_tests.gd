extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage53F4InstantHiringMonthlyMarketTests.run_all()
	if failures.is_empty():
		print("Stage 5.3F4 instant hiring and monthly recruitment market tests passed.")
		quit(0)
		return
	print("Stage 5.3F4 instant hiring and monthly recruitment market tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
