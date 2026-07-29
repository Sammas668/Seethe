extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = Stage314CampaignItemRegistryTests.run_all()
	if failures.is_empty():
		print("Stage 3.14 campaign item registry tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
