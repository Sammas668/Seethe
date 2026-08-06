extends SceneTree

const HOTFIX_5F4_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_hotfix_5f4_contact_transition_latency_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(await HOTFIX_5F4_TESTS.run(self))
	if failures.is_empty():
		print("Stage 4.7 Hotfix 5f4 contact-transition tests passed.")
		quit(0)
		return
	print("Stage 4.7 Hotfix 5f4 contact-transition tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
