class_name TacticalCharacterSheetState
extends RefCounted

var level: int = 1
var class_name_text: String = "Unassigned"
var archetype_name: String = "None"
var troop_type: String = "Individual"

var ability_scores: Dictionary = {
    "STR": 10,
    "DEX": 10,
    "CON": 10,
    "INT": 10,
    "WIS": 10,
    "CHA": 10,
}

var fortitude_save: int = 0
var reflex_save: int = 0
var will_save: int = 0
var initiative_bonus: int = 0
var passive_perception: int = 10

var attack_entries: Array[String] = []
var defence_entries: Array[String] = []
var ability_entries: Array[String] = []
var condition_entries: Array[String] = []
var injury_entries: Array[String] = []
var skill_entries: Array[String] = []


func ability_modifier(score: int) -> int:
    return int(floor((score - 10) / 2.0))


func ability_line(abbreviation: String) -> String:
    var score := int(ability_scores.get(abbreviation, 10))
    var modifier := ability_modifier(score)
    return "%s  %d  (%+d)" % [abbreviation, score, modifier]


func list_or_none(entries: Array[String], empty_text: String = "None") -> String:
    if entries.is_empty():
        return empty_text
    return "\n".join(PackedStringArray(entries))
