extends BaseEnemy
class_name PatrolDrone

## MITER-Corp Security Drone
## Patrols back and forth, charges at player when detected

@export var patrol_speed: float = 40.0
@export var charge_speed: float = 100.0
@export var patrol_distance: float = 80.0

var start_x: float = 0.0
var is_charging: bool = false
var charge_timer: float = 0.0


func _ready() -> void:
	super._ready()
	start_x = global_position.x
	speed = patrol_speed
	max_health = 2
	health = max_health


func _ai_behavior(delta: float) -> void:
	if player_ref and is_instance_valid(player_ref):
		# Chase player
		is_charging = true
		var dir = sign(player_ref.global_position.x - global_position.x)
		facing = int(dir)
		velocity.x = dir * charge_speed
	else:
		is_charging = false
		# Patrol
		velocity.x = facing * patrol_speed
		if abs(global_position.x - start_x) > patrol_distance:
			facing *= -1
