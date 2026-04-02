extends BaseEnemy
class_name PsiMoth

## Psionic Moth - Flying enemy from MITER experiments
## Floats and swoops toward player, associated with Moth badge lore

@export var float_speed: float = 30.0
@export var swoop_speed: float = 120.0
@export var swoop_cooldown: float = 2.0
@export var hover_height: float = -60.0

var home_position: Vector2
var swoop_timer: float = 0.0
var is_swooping: bool = false
var swoop_target: Vector2 = Vector2.ZERO
var time_alive: float = 0.0


func _ready() -> void:
	super._ready()
	home_position = global_position
	max_health = 2
	health = max_health
	gravity_scale = 0  # Flying enemy


func _ai_behavior(delta: float) -> void:
	time_alive += delta
	swoop_timer -= delta

	if is_swooping:
		# Swoop toward target
		var dir = (swoop_target - global_position).normalized()
		velocity = dir * swoop_speed
		if global_position.distance_to(swoop_target) < 10:
			is_swooping = false
		return

	if player_ref and is_instance_valid(player_ref) and swoop_timer <= 0:
		# Swoop at player
		is_swooping = true
		swoop_target = player_ref.global_position
		swoop_timer = swoop_cooldown
		return

	# Float around home position with sine wave
	var target = home_position + Vector2(
		sin(time_alive * 1.5) * 30,
		cos(time_alive * 2.0) * 15 + hover_height
	)
	velocity = (target - global_position).normalized() * float_speed
	facing = 1 if velocity.x > 0 else -1
