extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage45ReactionTests.run(self)
	if failures.is_empty():
		print("Stage 4.5 Reactions and Threatened Movement tests passed.")
		quit(0)
		return
	print("Stage 4.5 Reactions and Threatened Movement tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
