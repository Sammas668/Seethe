extends Node

const TACTICAL_UI_SANDBOX: PackedScene = preload(
    "res://presentation/tactical/tactical_screen.tscn"
)


func _ready() -> void:
    print("Seethe Stage 3.3 interactive hand-slot UI loaded.")
    call_deferred("_open_tactical_ui_sandbox")


func _open_tactical_ui_sandbox() -> void:
    var result := get_tree().change_scene_to_packed(TACTICAL_UI_SANDBOX)
    if result != OK:
        push_error("Could not open the tactical UI sandbox. Error code: %s" % result)
