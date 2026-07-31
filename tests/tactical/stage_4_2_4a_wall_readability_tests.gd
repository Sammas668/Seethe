class_name Stage424aWallReadabilityTests
extends RefCounted

const MAP: TacticalMapDefinition = preload(
	"res://content/missions/farm_storehouse/movement_test_map.tres"
)
const WALL_ADJACENCY_RESOLVER_SCRIPT: Script = preload(
	"res://presentation/tactical/walls/wall_adjacency_resolver.gd"
)


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var resolver: RefCounted = WALL_ADJACENCY_RESOLVER_SCRIPT.new()

	_expect(
		MAP.validate_definition().is_empty(),
		"The authored wall map must validate.",
		failures
	)
	_expect(
		MAP.wall_material_id(Vector2i(8, 2))
		== TacticalMapDefinition.WALL_MATERIAL_STONE,
		"The storehouse must use stone walls.",
		failures
	)
	_expect(
		MAP.wall_material_id(Vector2i(15, 12))
		== TacticalMapDefinition.WALL_MATERIAL_WOOD,
		"The shed must use wooden walls.",
		failures
	)
	_expect(MAP.is_blocked(Vector2i(8, 2)), "Stone must block movement.", failures)
	_expect(MAP.blocks_vision(Vector2i(8, 2)), "Stone must block sight.", failures)
	_expect(MAP.is_blocked(Vector2i(15, 12)), "Wood must block movement.", failures)
	_expect(MAP.blocks_vision(Vector2i(15, 12)), "Wood must block sight.", failures)

	var stone_connections: int = int(
		resolver.call("connections_for", MAP, Vector2i(8, 2))
	)
	_expect(
		(stone_connections & 2) != 0,
		"Adjacent stone walls must connect east-west.",
		failures
	)
	var mixed_connections: int = int(
		resolver.call("connections_for", MAP, Vector2i(24, 29))
	)
	_expect(
		(mixed_connections & 2) == 0,
		"Stone must not visually merge into adjacent wood.",
		failures
	)
	_expect(
		MAP.wall_variant_seed(Vector2i(8, 2))
		== MAP.wall_variant_seed(Vector2i(8, 2)),
		"Wall detail variation must be deterministic.",
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
