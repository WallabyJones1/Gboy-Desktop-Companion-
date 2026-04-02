extends BaseEnemy
class_name SnakeGuardian

## Snake Guardian - Mid-tier enemy, associated with Snake badge
## Slithers along surfaces, can climb walls, lunges at player

@export var lunge_speed: float = 180.0
@export var lunge_cooldown: float = 3.0
@export var lunge_range: float = 80.0

var lunge_timer: float = 0.0
var is_lunging: bool = false
var lunge_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	max_health = 4
	health = max_health
	speed = 35.0


func _ai_behavior(delta: float) -> void:
	lunge_timer -= delta

	if is_lunging:
		velocity.x = lunge_direction.x * lunge_speed
		if is_on_wall() or is_on_floor():
			is_lunging = false
		return

	if player_ref and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		var dir = sign(player_ref.global_position.x - global_position.x)
		facing = int(dir)

		if dist < lunge_range and lunge_timer <= 0:
			# Lunge attack
			is_lunging = true
			lunge_direction = (player_ref.global_position - global_position).normalized()
			velocity.y = -120
			lunge_timer = lunge_cooldown
		else:
			# Approach
			velocity.x = dir * speed
	else:
		# Patrol
		velocity.x = facing * speed * 0.5
		if is_on_wall():
			facing *= -1
