extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage51dMissionRoutesNotorietyTests.run()
	failures.append_array(Stage51cAgentTests.run())
	failures.append_array(Stage51aRegionTests.run())
	failures.append_array(Stage50CampaignShellTests.run())
	if failures.is_empty():
		print("Stage 5.1d mission lifecycle, route, Notoriety and retaliation runtime tests passed.")
		quit(0)
		return
	print("Stage 5.1d runtime tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
