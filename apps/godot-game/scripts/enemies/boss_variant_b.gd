extends CharacterBody2D
class_name BossVariantB

## BOSS: Variant B - Failed psionic experiment from MITER-Corp
## Referenced in the 1994 video logs alongside G304
## Phases: 1) Ground pounds, 2) Teleport attacks, 3) Psionic storm

signal boss_defeated

@export var max_health: int = 20
@export var phase_2_threshold: float = 0.6
@export var phase_3_threshold: float = 0.3

var health: int
var current_phase: int = 1
var is_alive: bool = true
var player_ref: Player = null
var attack_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	health = max_health
	add_to_group("bosses")
	hitbox.add_to_group("enemy_hitbox")
	_update_health_bar()

	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	attack_timer -= delta

	# Phase management
	var health_pct = float(health) / float(max_health)
	if health_pct <= phase_3_threshold and current_phase < 3:
		current_phase = 3
		_enter_phase_3()
	elif health_pct <= phase_2_threshold and current_phase < 2:
		current_phase = 2
		_enter_phase_2()

	if attack_timer <= 0:
		_do_attack()

	move_and_slide()


func _do_attack() -> void:
	match current_phase:
		1:
			_ground_pound()
			attack_timer = 2.5
		2:
			if randf() > 0.5:
				_teleport_strike()
			else:
				_ground_pound()
			attack_timer = 2.0
		3:
			var roll = randf()
			if roll > 0.6:
				_psionic_storm()
			elif roll > 0.3:
				_teleport_strike()
			else:
				_ground_pound()
			attack_timer = 1.5


func _ground_pound() -> void:
	if not player_ref:
		return
	# Jump up and slam down
	velocity.y = -350
	var target_x = player_ref.global_position.x
	velocity.x = sign(target_x - global_position.x) * 80


func _teleport_strike() -> void:
	if not player_ref:
		return
	# Teleport near player and strike
	var offset = 60 * (1 if randf() > 0.5 else -1)
	global_position.x = player_ref.global_position.x + offset
	global_position.y = player_ref.global_position.y - 20
	velocity = Vector2(sign(player_ref.global_position.x - global_position.x) * 200, 0)


func _psionic_storm() -> void:
	# Create damaging area around boss
	# Spawn projectiles in a circle
	if not player_ref:
		return
	for i in range(8):
		var angle = i * TAU / 8
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_projectile(global_position, dir)


func _spawn_projectile(pos: Vector2, dir: Vector2) -> void:
	# Simple projectile - just a moving hitbox
	var proj = Area2D.new()
	proj.global_position = pos
	proj.add_to_group("enemy_hitbox")

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 4
	col.shape = shape
	proj.add_child(col)

	var vis = Sprite2D.new()
	# Placeholder visual
	proj.add_child(vis)

	get_parent().add_child(proj)

	# Move and auto-destroy
	var tween = proj.create_tween()
	tween.tween_property(proj, "global_position",
		pos + dir * 200, 0.8)
	tween.tween_callback(proj.queue_free)


func _enter_phase_2() -> void:
	# Speed up, flash
	if sprite:
		sprite.modulate = Color(1, 0.5, 0.5)


func _enter_phase_3() -> void:
	# Enrage
	if sprite:
		sprite.modulate = Color(1, 0.2, 0.2)


func take_damage(amount: int, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return

	health -= amount
	_update_health_bar()

	if sprite:
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(self):
			match current_phase:
				1: sprite.modulate = Color.WHITE
				2: sprite.modulate = Color(1, 0.5, 0.5)
				3: sprite.modulate = Color(1, 0.2, 0.2)

	if health <= 0:
		_die()


func _die() -> void:
	is_alive = false
	GameManager.defeat_boss("variant_b")
	boss_defeated.emit()

	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		await tween.finished
	queue_free()


func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = float(health) / float(max_health) * 100
