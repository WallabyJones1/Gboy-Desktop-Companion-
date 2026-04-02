extends Node

## Save/Load system for GBOY
## Persists game progress to disk

const SAVE_PATH = "user://gboy_save.dat"


func save_game() -> void:
	var data = GameManager.get_save_data()
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
		print("[SAVE] Game saved successfully")


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			GameManager.load_save_data(data)
			print("[SAVE] Game loaded successfully")
			return true
	return false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
