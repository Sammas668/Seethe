class_name Stage423VisibilityCameraTests
extends RefCounted

const BOARD_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_screen.tscn"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var session: TacticalSession = TacticalSandboxFactory.create_session(false)
	var facade = session.screen_facade
	_expect(
		session.map_definition.grid_size == Vector2i(64, 64),
		"The scalable test map must be 64×64.",
		failures
	)
	var hakon: TacticalUnitState = session.state_store.state.get_unit(
		TacticalSandboxFactory.MARAUDER_ID
	)
	_expect(hakon != null, "The visibility fixture needs Hakon.", failures)
	if hakon != null:
		_expect(
			facade.is_tile_visible_to_player(hakon.grid_position),
			"A player unit's own tile must be visible.",
			failures
		)
		_expect(
			facade.is_tile_explored_by_player(hakon.grid_position),
			"Visible player tiles must also be explored.",
			failures
		)
	_expect(
		not facade.is_tile_explored_by_player(Vector2i(63, 63)),
		"A distant untouched tile must begin unseen.",
		failures
	)
	_expect(
		facade.visible_tile_count_for_player() > 0,
		"Player visibility must reveal a non-empty area.",
		failures
	)
	return failures


static func _expect(
	condition: bool,
	message: String,
	failures: Array[String]
) -> void:
	if not condition:
		failures.append(message)
