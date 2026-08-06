extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage51aRegionTests.run()
	failures.append_array(Stage51aRegionAuthoringTests.run())
	failures.append_array(Stage50CampaignShellTests.run())
	if failures.is_empty():
		print("Stage 5.1a authored starter-region and authoring-tool runtime tests passed.")
		quit(0)
		return
	print("Stage 5.1a authored starter-region runtime tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
