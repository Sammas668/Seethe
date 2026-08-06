extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = Stage424aWallReadabilityTests.run_all()
	if failures.is_empty():
		print("Stage 4.2.4a wall readability tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
