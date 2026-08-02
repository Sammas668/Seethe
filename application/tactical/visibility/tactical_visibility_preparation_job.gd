class_name TacticalVisibilityPreparationJob
extends RefCounted

var unit_id: StringName = &""
var destination: Vector2i = Vector2i(-1, -1)
var geometry_revision: int = -1
var occupied_cells: Array[Vector2i] = []
var requests: Array[Dictionary] = []
var request_index: int = 0
var result_field: TacticalVisibilityField
var started_usec: int = 0
var processing_usec: int = 0
var processing_slices: int = 0
var cache_hits: int = 0
var cache_misses: int = 0
var complete: bool = false
var valid: bool = true
var cancelled: bool = false


func configure(
	unit_id_value: StringName,
	destination_value: Vector2i,
	geometry_revision_value: int,
	occupied_cells_value: Array[Vector2i],
	requests_value: Array[Dictionary],
	field_value: TacticalVisibilityField
) -> void:
	unit_id = unit_id_value
	destination = destination_value
	geometry_revision = geometry_revision_value
	occupied_cells = occupied_cells_value.duplicate()
	requests = requests_value.duplicate(true)
	result_field = field_value
	request_index = 0
	started_usec = Time.get_ticks_usec()
	processing_usec = 0
	processing_slices = 0
	cache_hits = 0
	cache_misses = 0
	complete = false
	valid = field_value != null
	cancelled = false


func mark_complete(success: bool) -> void:
	valid = valid and success
	complete = true


func cancel() -> void:
	cancelled = true
	valid = false
	complete = true
