class_name TacticalDestinationPreview
extends RefCounted

var unit_id: StringName = &""
var destination: Vector2i = Vector2i(-1, -1)
var movement_mode: StringName = &"normal"
var path_result: MovementPathResult
var detection_preview: MovementDetectionPreview
var reaction_preview: MovementReactionPreview
var cover_preview: TacticalCoverPreview
var cover_field: TacticalDirectionalCoverField
var local_cover_category: StringName = TacticalCombatGeometryResult.COVER_NONE
var automatic_peek_origins: Array[TacticalObservationOrigin] = []
var tactical_revision: int = 0
var geometry_revision: int = 0
var knowledge_revision: int = 0
var visibility_revision: int = 0


func is_valid_for(
		state: TacticalState,
		current_visibility_revision: int
) -> bool:
	return (
		state != null
		and tactical_revision == state.revision
		and geometry_revision == state.geometry_revision()
		and knowledge_revision == state.knowledge_state.revision
		and visibility_revision == current_visibility_revision
	)
