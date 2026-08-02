extends SceneTree

# Compatibility runner. Stage 4.7 now resolves through the Hotfix 1 exact-sheet
# conformance suite rather than the superseded generic-role tests.
const TESTS: Script = preload(
	"res://tests/integration/stage_4_7_character_sheet_conformance_tests.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = TESTS.run(self)
	if failures.is_empty():
		print("Stage 4.7 exact starter-content tests passed.")
		quit(0)
		return
	print("Stage 4.7 exact starter-content tests failed:")
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
