class_name StatModifierLine
extends RefCounted

var source_id: StringName
var label: String
var value: int
var category: StringName


func _init() -> void:
	pass


func configure(
		source_id_value: StringName = &"",
		label_value: String = "Modifier",
		value_value: int = 0,
		category_value: StringName = &"misc"
) -> void:
	source_id = source_id_value
	label = label_value
	value = value_value
	category = category_value


func formatted_value() -> String:
	return "%+d" % value
