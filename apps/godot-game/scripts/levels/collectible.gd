extends Area2D
class_name Collectible

## Collectible items: Badges (Rabbit/Moth/Snake) and Lore Fragments

enum CollectibleType { BADGE_RABBIT, BADGE_MOTH, BADGE_SNAKE, LORE_FRAGMENT, HEALTH }

@export var type: CollectibleType = CollectibleType.BADGE_RABBIT
@export var lore_id: String = ""

var bob_time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Floating bob animation
	bob_time += delta
	position.y += sin(bob_time * 3.0) * 0.3


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		match type:
			CollectibleType.BADGE_RABBIT:
				GameManager.collect_badge("rabbit")
			CollectibleType.BADGE_MOTH:
				GameManager.collect_badge("moth")
			CollectibleType.BADGE_SNAKE:
				GameManager.collect_badge("snake")
			CollectibleType.LORE_FRAGMENT:
				GameManager.find_lore_fragment(lore_id)
			CollectibleType.HEALTH:
				GameManager.heal(1)
		queue_free()
