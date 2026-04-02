extends Node

const GAME_SCENE := "res://scenes/ui/main_menu.tscn"
const PET_SCENE := "res://scenes/pet/desktop_pet.tscn"


func _ready() -> void:
	var target_scene := PET_SCENE if OS.has_feature("desktop_pet") else GAME_SCENE
	get_tree().change_scene_to_file.call_deferred(target_scene)
