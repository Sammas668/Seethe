extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = Stage317CombatFoundationTests.run_all()
	if failures.is_empty():
		print("Stage 3.17 combat foundation tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
