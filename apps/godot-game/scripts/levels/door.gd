extends Area2D
class_name Door

## Level transition door/gate

signal player_entered(target_level: String, target_spawn: String)

@export var target_level: String = ""
@export var target_spawn: String = "default"
@export var requires_ability: String = ""

var is_locked: bool = false


func _ready() -> void:
	add_to_group("doors")
	body_entered.connect(_on_body_entered)

	if requires_ability != "":
		is_locked = not GameManager.has_ability(requires_ability)
		GameManager.ability_unlocked.connect(_check_unlock)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_locked:
		if Input.is_action_pressed("interact") or true:  # Auto-enter for now
			player_entered.emit(target_level, target_spawn)


func _check_unlock(ability_name: String) -> void:
	if ability_name == requires_ability:
		is_locked = false
