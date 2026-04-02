extends Area2D
class_name Checkpoint

## Save checkpoint - styled as MITER-Corp data terminals

signal activated(checkpoint_id: String)

@export var checkpoint_id: String = ""
var is_activated: bool = false


func _ready() -> void:
	add_to_group("checkpoints")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_activated:
		is_activated = true
		activated.emit(checkpoint_id)
		# Visual feedback
		modulate = Color(0.2, 1.0, 0.3)
