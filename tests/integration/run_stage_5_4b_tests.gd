extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = Stage54BManufacturingPersonnelRepairTests.run_all()
	if failures.is_empty():
		print("Stage 5.4B Manufacturing, Personnel and Repair tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
