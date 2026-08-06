extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = Stage44e3PostMovementTurnHandoffTests.run_all()
	if failures.is_empty():
		print("Stage 4.4e3 tactical tests passed.")
		quit(0)
		return
	print("Stage 4.4e3 tactical tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
