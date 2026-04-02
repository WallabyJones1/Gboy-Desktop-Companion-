extends Area2D
class_name AbilityPickup

## Ability unlock item - found in special rooms
## Each ability is tied to a lore location in the MITER-Corp facility

@export var ability_name: String = ""
@export var description: String = ""

var collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Check if already collected
	if GameManager.has_ability(ability_name):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not collected:
		collected = true
		GameManager.unlock_ability(ability_name)
		# Dramatic pickup effect
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(2, 2), 0.3)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
		await tween.finished
		queue_free()
