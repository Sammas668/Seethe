extends SceneTree

const FOUNDATION_SUITE: Script = preload(
	"res://tests/tactical/stage_3_9_invariant_tests.gd"
)
const JOURNAL_SUITE: Script = preload(
	"res://tests/tactical/stage_3_9_2_event_journal_tests.gd"
)


func _initialize() -> void:
	var failures: Array[String] = []
	failures.append_array(FOUNDATION_SUITE.run_all())
	failures.append_array(JOURNAL_SUITE.run_all())

	if failures.is_empty():
		print("Stage 3.9.2 tactical event and roll log tests passed.")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)
