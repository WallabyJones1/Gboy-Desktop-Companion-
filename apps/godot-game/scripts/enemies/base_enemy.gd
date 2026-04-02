extends CharacterBody2D
class_name BaseEnemy

## Base enemy class for MITER-Corp creatures
## Psionic experiment monsters and security drones

signal defeated(enemy: BaseEnemy)

@export var max_health: int = 3
@export var damage: int = 1
@export var speed: float = 50.0
@export var gravity_scale: float = 1.0
@export var detection_range: float = 150.0
@export var gives_psi_energy: float = 10.0

var health: int
var facing: int = -1
var is_alive: bool = true
var player_ref: Player = null
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var detection_area: Area2D = $DetectionArea


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	hitbox.add_to_group("enemy_hitbox")

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_on_floor():
		velocity.y += gravity * gravity_scale * delta

	_ai_behavior(delta)
	move_and_slide()
	_update_sprite()


func _ai_behavior(_delta: float) -> void:
	# Override in subclass
	pass


func _update_sprite() -> void:
	if sprite:
		sprite.flip_h = facing < 0


func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return

	health -= amount

	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 120

	# Flash effect
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self):
			sprite.modulate = Color.WHITE

	if health <= 0:
		die()


func die() -> void:
	is_alive = false
	defeated.emit(self)
	# Give player psi energy
	GameManager.psi_energy = min(
		GameManager.psi_energy + gives_psi_energy,
		GameManager.psi_max_energy
	)
	# Death animation
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tween.finished
	queue_free()


func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		player_ref = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body is Player:
		player_ref = null
