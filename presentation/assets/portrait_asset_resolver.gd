class_name PortraitAssetResolver
extends RefCounted

const HAKON_RUSK: Texture2D = preload(
	"res://content/characters/reaver/portraits/hakon_rusk.png"
)

var _textures_by_id: Dictionary = {
	&"portrait.hakon_rusk": HAKON_RUSK,
	&"portrait.reaver.marauder": HAKON_RUSK,
}


func resolve(portrait_id: StringName) -> Texture2D:
	return _textures_by_id.get(portrait_id) as Texture2D


func has_portrait(portrait_id: StringName) -> bool:
	return _textures_by_id.has(portrait_id)
