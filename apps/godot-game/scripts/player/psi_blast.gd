extends Area2D
class_name PsiBlast

## Psionic blast projectile - G304's psychic attack
## Glowing energy bolt that damages enemies

@export var speed: float = 250.0
@export var damage: int = 2
@export var lifetime: float = 0.8

var direction: int = 1
var time_alive: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position.x += direction * speed * delta
	time_alive += delta

	if time_alive >= lifetime:
		_explode()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, Vector2(direction, -0.2).normalized())
		_explode()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		var parent = area.get_parent()
		if parent.has_method("take_damage"):
			parent.take_damage(damage, Vector2(direction, -0.2).normalized())
			_explode()


func _explode() -> void:
	# Quick flash and destroy
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2, 2), 0.1)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	queue_free()
