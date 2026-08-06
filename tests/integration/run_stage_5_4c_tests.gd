extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = Stage54CResearchOrganisationalUnlocksTests.run_all()
	if failures.is_empty():
		print("Stage 5.4C Research and Organisational Unlocks tests passed.")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
