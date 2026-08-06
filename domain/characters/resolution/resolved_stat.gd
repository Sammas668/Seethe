class_name ResolvedStat
extends RefCounted

const STAT_MODIFIER_LINE_SCRIPT: Script = preload(
	"res://domain/characters/resolution/stat_modifier_line.gd"
)

var stat_id: StringName
var display_name: String
var modifier_lines: Array = []
var final_value: int = 0


func _init() -> void:
	pass


func configure(
		stat_id_value: StringName = &"",
		display_name_value: String = "Resolved Stat"
) -> void:
	stat_id = stat_id_value
	display_name = display_name_value
	modifier_lines.clear()
	final_value = 0


func add_line(
		source_id: StringName,
		label: String,
		value: int,
		category: StringName = &"misc"
) -> void:
	var line: RefCounted = STAT_MODIFIER_LINE_SCRIPT.new() as RefCounted
	line.call("configure", source_id, label, value, category)
	modifier_lines.append(line)
	final_value += value


func breakdown_lines() -> Array[String]:
	var result: Array[String] = []
	for line in modifier_lines:
		if line == null:
			continue
		result.append(
			"%-28s %s" % [line.get("label"), line.call("formatted_value")]
		)
	return result
