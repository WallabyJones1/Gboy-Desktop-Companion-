extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/pet/desktop_pet.tscn")
	if scene == null:
		push_error("Failed to load pet scene")
		quit(1)
		return

	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	quit()
