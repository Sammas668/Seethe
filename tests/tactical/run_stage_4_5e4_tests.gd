extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage45E4ZeroDeadFrameAttackTests.run(self)
	if failures.is_empty():
		print("Stage 4.5e4 Zero-Dead-Frame Attack tests passed.")
		quit(0)
		return
	print("Stage 4.5e4 Zero-Dead-Frame Attack tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
