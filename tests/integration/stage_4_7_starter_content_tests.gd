class_name Stage47StarterContentTests
extends RefCounted

# Compatibility wrapper retained for older manifests and local commands.
const EXACT_TESTS: Script = preload(
	"res://tests/integration/stage_4_7_character_sheet_conformance_tests.gd"
)


static func run(tree: SceneTree) -> Array[String]:
	return EXACT_TESTS.run(tree)
