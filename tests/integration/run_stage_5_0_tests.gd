extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage50CampaignShellTests.run()
	if failures.is_empty():
		print("Stage 5.0 Campaign Shell runtime tests passed.")
		quit(0)
		return
	print("Stage 5.0 Campaign Shell runtime tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
