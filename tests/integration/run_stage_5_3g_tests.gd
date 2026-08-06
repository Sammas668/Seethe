extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = Stage53GPersistentMissionLifecycleTests.run_all()
	failures.append_array(Stage53G1RecoveryCapacityTests.run_all())
	failures.append_array(Stage53G2TransportRecoveryTests.run_all())
	if failures.is_empty():
		print("Stage 5.3G/G1/G2 persistent mission lifecycle and recovery-capacity tests passed.")
		quit(0)
		return
	print("Stage 5.3G/G1/G2 persistent mission lifecycle and recovery-capacity tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
