extends CharacterBody2D
class_name Player

## G*BOY (G304) - Player Controller
## A psionic experiment escaping MITER-Corp
## Metroidvania movement with ability unlocks

# === SIGNALS ===
signal died
signal landed
signal wall_jumped

# === MOVEMENT CONSTANTS ===
@export_group("Movement")
@export var SPEED: float = 120.0
@export var ACCELERATION: float = 900.0
@export var FRICTION: float = 1200.0
@export var AIR_FRICTION: float = 400.0
@export var JUMP_VELOCITY: float = -280.0
@export var DOUBLE_JUMP_VELOCITY: float = -240.0
@export var WALL_JUMP_VELOCITY: Vector2 = Vector2(200, -260)
@export var WALL_SLIDE_SPEED: float = 60.0
@export var GRAVITY_SCALE: float = 1.0
@export var MAX_FALL_SPEED: float = 300.0
@export var COYOTE_TIME: float = 0.1
@export var JUMP_BUFFER_TIME: float = 0.12

@export_group("Dash")
@export var DASH_SPEED: float = 300.0
@export var DASH_DURATION: float = 0.15
@export var DASH_COOLDOWN: float = 0.6

@export_group("Combat")
@export var ATTACK_DAMAGE: int = 1
@export var PSI_BLAST_COST: float = 25.0
@export var PSI_BLAST_DAMAGE: int = 2
@export var INVINCIBILITY_TIME: float = 1.0
@export var KNOCKBACK_FORCE: Vector2 = Vector2(150, -100)

# === STATE MACHINE ===
enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	WALL_SLIDE,
	DASH,
	ATTACK,
	PSI_BLAST,
	HURT,
	DEATH,
}
var current_state: State = State.IDLE

# === NODE REFERENCES ===
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var psi_blast_scene: PackedScene = preload("res://scenes/effects/psi_blast.tscn")
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var camera: Camera2D = $Camera2D

# === STATE VARIABLES ===
var facing_direction: int = 1  # 1 = right, -1 = left
var can_double_jump: bool = false
var has_double_jumped: bool = false
var is_wall_sliding: bool = false
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var is_attacking: bool = false
var is_invincible: bool = false
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var was_on_floor: bool = false


func _ready() -> void:
	# Connect signals
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	coyote_timer.wait_time = COYOTE_TIME
	jump_buffer_timer.wait_time = JUMP_BUFFER_TIME
	dash_cooldown_timer.wait_time = DASH_COOLDOWN

	# Setup attack hitbox
	attack_hitbox.monitoring = false
	attack_hitbox.body_entered.connect(_on_attack_hit)

	# Setup hurtbox
	hurtbox.area_entered.connect(_on_hurtbox_entered)


func _physics_process(delta: float) -> void:
	# Track floor state for coyote time
	if is_on_floor():
		was_on_floor = true
		has_double_jumped = false
	elif was_on_floor:
		was_on_floor = false
		if current_state != State.JUMP:
			coyote_timer.start()

	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.RUN:
			_state_run(delta)
		State.JUMP:
			_state_jump(delta)
		State.FALL:
			_state_fall(delta)
		State.WALL_SLIDE:
			_state_wall_slide(delta)
		State.DASH:
			_state_dash(delta)
		State.ATTACK:
			_state_attack(delta)
		State.PSI_BLAST:
			_state_psi_blast(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEATH:
			pass

	move_and_slide()
	_update_sprite()


# === STATE FUNCTIONS ===

func _state_idle(delta: float) -> void:
	_apply_gravity(delta)
	_apply_friction(delta)

	if not is_on_floor():
		_change_state(State.FALL)
		return

	if _wants_jump():
		_do_jump()
		return

	if _wants_dash():
		_do_dash()
		return

	if _wants_attack():
		_do_attack()
		return

	if _wants_psi_blast():
		_do_psi_blast()
		return

	var input_dir = _get_input_direction()
	if input_dir != 0:
		_change_state(State.RUN)


func _state_run(delta: float) -> void:
	_apply_gravity(delta)

	var input_dir = _get_input_direction()
	if input_dir != 0:
		facing_direction = input_dir
		velocity.x = move_toward(velocity.x, input_dir * SPEED, ACCELERATION * delta)
	else:
		_change_state(State.IDLE)
		return

	if not is_on_floor():
		_change_state(State.FALL)
		return

	if _wants_jump():
		_do_jump()
		return

	if _wants_dash():
		_do_dash()
		return

	if _wants_attack():
		_do_attack()
		return

	if _wants_psi_blast():
		_do_psi_blast()
		return


func _state_jump(delta: float) -> void:
	_apply_gravity(delta)
	_apply_air_movement(delta)

	# Variable jump height
	if not Input.is_action_pressed("jump") and velocity.y < 0:
		velocity.y *= 0.5

	if velocity.y > 0:
		_change_state(State.FALL)
		return

	# Wall slide check
	if _check_wall_slide():
		return

	if _wants_double_jump():
		_do_double_jump()
		return

	if _wants_dash():
		_do_dash()
		return

	if _wants_attack():
		_do_attack()
		return


func _state_fall(delta: float) -> void:
	_apply_gravity(delta)
	_apply_air_movement(delta)

	if is_on_floor():
		landed.emit()
		if _get_input_direction() != 0:
			_change_state(State.RUN)
		else:
			_change_state(State.IDLE)
		return

	# Wall slide check
	if _check_wall_slide():
		return

	# Coyote time jump
	if _wants_jump() and not coyote_timer.is_stopped():
		_do_jump()
		return

	# Jump buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer.start()

	if _wants_double_jump():
		_do_double_jump()
		return

	if _wants_dash():
		_do_dash()
		return


func _state_wall_slide(delta: float) -> void:
	# Slow gravity on wall
	velocity.y = min(velocity.y + gravity * GRAVITY_SCALE * 0.3 * delta, WALL_SLIDE_SPEED)

	_apply_air_movement(delta)

	# Check if still on wall
	var on_wall = (wall_check_left.is_colliding() and _get_input_direction() < 0) or \
				  (wall_check_right.is_colliding() and _get_input_direction() > 0)

	if not on_wall or is_on_floor():
		_change_state(State.FALL)
		return

	# Wall jump
	if Input.is_action_just_pressed("jump") and GameManager.has_ability("wall_slide"):
		var wall_dir = -1 if wall_check_right.is_colliding() else 1
		velocity = Vector2(WALL_JUMP_VELOCITY.x * wall_dir, WALL_JUMP_VELOCITY.y)
		facing_direction = wall_dir
		wall_jumped.emit()
		_change_state(State.JUMP)
		return


func _state_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * DASH_SPEED

	if dash_timer <= 0:
		is_dashing = false
		if is_on_floor():
			_change_state(State.IDLE)
		else:
			_change_state(State.FALL)


func _state_attack(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, FRICTION * 0.5 * delta)

	# Attack ends when animation finishes (handled by animation signal)


func _state_psi_blast(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, FRICTION * 0.5 * delta)


func _state_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, FRICTION * 0.3 * delta)


# === ACTION FUNCTIONS ===

func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	coyote_timer.stop()
	jump_buffer_timer.stop()
	_change_state(State.JUMP)


func _do_double_jump() -> void:
	if GameManager.has_ability("double_jump") and not has_double_jumped:
		velocity.y = DOUBLE_JUMP_VELOCITY
		has_double_jumped = true
		_change_state(State.JUMP)


func _do_dash() -> void:
	if not GameManager.has_ability("dash"):
		return
	if not dash_cooldown_timer.is_stopped():
		return

	is_dashing = true
	dash_timer = DASH_DURATION
	dash_direction = Vector2(facing_direction, 0).normalized()

	# Keep dash input horizontal until vertical controls are added.
	var horizontal_input = Input.get_axis("move_left", "move_right")
	if abs(horizontal_input) > 0.1:
		dash_direction = Vector2(horizontal_input, 0).normalized()

	dash_cooldown_timer.start()
	_change_state(State.DASH)


func _do_attack() -> void:
	is_attacking = true
	attack_hitbox.monitoring = true
	# Position hitbox based on facing
	attack_hitbox.position.x = abs(attack_hitbox.position.x) * facing_direction
	_change_state(State.ATTACK)

	# Timer to end attack
	await get_tree().create_timer(0.3).timeout
	is_attacking = false
	attack_hitbox.monitoring = false
	if is_on_floor():
		_change_state(State.IDLE)
	else:
		_change_state(State.FALL)


func _do_psi_blast() -> void:
	if not GameManager.has_ability("psi_blast"):
		return
	if not GameManager.use_psi_energy(PSI_BLAST_COST):
		return

	_change_state(State.PSI_BLAST)

	# Spawn psi blast projectile
	if psi_blast_scene:
		var blast = psi_blast_scene.instantiate()
		blast.global_position = global_position + Vector2(facing_direction * 16, -4)
		blast.direction = facing_direction
		blast.damage = PSI_BLAST_DAMAGE
		get_parent().add_child(blast)

	await get_tree().create_timer(0.35).timeout
	if is_on_floor():
		_change_state(State.IDLE)
	else:
		_change_state(State.FALL)


# === HELPER FUNCTIONS ===

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * GRAVITY_SCALE * delta, MAX_FALL_SPEED)


func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, FRICTION * delta)


func _apply_air_movement(delta: float) -> void:
	var input_dir = _get_input_direction()
	if input_dir != 0:
		facing_direction = input_dir
		velocity.x = move_toward(velocity.x, input_dir * SPEED, ACCELERATION * 0.8 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)


func _get_input_direction() -> int:
	return int(Input.get_axis("move_left", "move_right"))


func _wants_jump() -> bool:
	return Input.is_action_just_pressed("jump") or not jump_buffer_timer.is_stopped()


func _wants_double_jump() -> bool:
	return Input.is_action_just_pressed("jump")


func _wants_dash() -> bool:
	return Input.is_action_just_pressed("dash")


func _wants_attack() -> bool:
	return Input.is_action_just_pressed("attack")


func _wants_psi_blast() -> bool:
	return Input.is_action_just_pressed("psionic")


func _check_wall_slide() -> bool:
	if not GameManager.has_ability("wall_slide"):
		return false

	var input_dir = _get_input_direction()
	if input_dir != 0 and velocity.y > 0:
		if (input_dir < 0 and wall_check_left.is_colliding()) or \
		   (input_dir > 0 and wall_check_right.is_colliding()):
			_change_state(State.WALL_SLIDE)
			return true
	return false


func _change_state(new_state: State) -> void:
	current_state = new_state


func _update_sprite() -> void:
	if not sprite or sprite.sprite_frames == null:
		return

	# Flip sprite based on facing direction
	sprite.flip_h = facing_direction < 0

	var animation_name := ""

	match current_state:
		State.IDLE:
			animation_name = "idle"
		State.RUN:
			animation_name = "run"
		State.JUMP:
			animation_name = "jump"
		State.FALL:
			animation_name = "fall"
		State.WALL_SLIDE:
			animation_name = "wall_slide"
		State.DASH:
			animation_name = "dash"
		State.ATTACK:
			animation_name = "attack"
		State.PSI_BLAST:
			animation_name = "attack"
		State.HURT:
			animation_name = "fall"

	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name:
			sprite.play(animation_name)
		elif not sprite.is_playing():
			sprite.play()


func take_hit(damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or current_state == State.DASH:
		return

	GameManager.take_damage(damage)
	is_invincible = true
	invincibility_timer.start(INVINCIBILITY_TIME)

	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * KNOCKBACK_FORCE
	else:
		velocity = Vector2(-facing_direction * KNOCKBACK_FORCE.x, KNOCKBACK_FORCE.y)

	if GameManager.player_health <= 0:
		_change_state(State.DEATH)
		died.emit()
	else:
		_change_state(State.HURT)
		await get_tree().create_timer(0.3).timeout
		if current_state == State.HURT:
			_change_state(State.FALL if not is_on_floor() else State.IDLE)


func _on_invincibility_timeout() -> void:
	is_invincible = false


func _on_attack_hit(body: Node2D) -> void:
	if body.has_method("take_damage"):
		var kb_dir = Vector2(facing_direction, -0.3).normalized()
		body.take_damage(ATTACK_DAMAGE, kb_dir)


func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var dir = (global_position - area.global_position).normalized()
		take_hit(1, dir)
	elif area.is_in_group("hazard"):
		take_hit(1)
