extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var started_usec: int = Time.get_ticks_usec()
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	if session == null:
		print("Stage 4.5g benchmark failed: sandbox session could not be created.")
		quit(1)
		return
	var creation_usec: int = Time.get_ticks_usec() - started_usec
	var validation_started: int = Time.get_ticks_usec()
	var errors: Array[String] = session.validate_session()
	var validation_usec: int = Time.get_ticks_usec() - validation_started
	var facade_snapshot: Dictionary = session.screen_facade.performance_snapshot()
	var report := {
		"session_creation_usec": creation_usec,
		"session_validation_usec": validation_usec,
		"state_revision": session.state_store.state.revision,
		"occupancy_revision": session.state_store.state.occupancy_revision,
		"visibility_blocker_revision": session.state_store.state.visibility_blocker_revision,
		"knowledge_revision": session.state_store.state.knowledge_state.revision,
		"performance": facade_snapshot,
		"validation_errors": errors,
	}
	print("STAGE_4_5G_BENCHMARK=" + JSON.stringify(report))
	if not errors.is_empty():
		print("Stage 4.5g benchmark failed validation: %s" % errors[0])
		quit(1)
		return
	quit(0)
