extends Node2D
class_name BaseLevel

## Base level script for all game rooms
## Handles room transitions, checkpoints, collectibles

@export var level_id: String = "unnamed"
@export var level_name: String = "Unknown Area"
@export var music_track: AudioStream = null

@onready var player_spawn: Marker2D = get_node_or_null("PlayerSpawn") as Marker2D
@onready var player: Player = get_node_or_null("Player") as Player
@onready var tilemap: TileMap = get_node_or_null("TileMap") as TileMap
@onready var camera_limits: Node2D = get_node_or_null("CameraLimits") as Node2D


func _ready() -> void:
	GameManager.current_level = level_id
	GameManager.visit_room(level_id)

	# Position player at spawn or checkpoint
	if player and player_spawn:
		player.global_position = player_spawn.global_position

	# Play level music
	if music_track:
		AudioManager.play_music(music_track)

	# Setup camera limits
	_setup_camera_limits()

	# Connect door transitions
	for door in get_tree().get_nodes_in_group("doors"):
		if door.has_signal("player_entered"):
			door.player_entered.connect(_on_door_entered)

	# Connect checkpoints
	for cp in get_tree().get_nodes_in_group("checkpoints"):
		if cp.has_signal("activated"):
			cp.activated.connect(_on_checkpoint_activated)


func _setup_camera_limits() -> void:
	if not player or not player.has_node("Camera2D") or not tilemap:
		return

	var cam = player.get_node("Camera2D") as Camera2D
	if not cam:
		return

	# Use tilemap bounds or manual limits
	var rect = tilemap.get_used_rect()
	if not rect.has_area():
		return

	var tile_size = tilemap.tile_set.tile_size if tilemap.tile_set else Vector2i(16, 16)
	cam.limit_left = rect.position.x * tile_size.x
	cam.limit_top = rect.position.y * tile_size.y
	cam.limit_right = rect.end.x * tile_size.x
	cam.limit_bottom = rect.end.y * tile_size.y


func _on_door_entered(target_level: String, target_spawn: String) -> void:
	GameManager.change_level("res://scenes/levels/%s.tscn" % target_level)


func _on_checkpoint_activated(cp_id: String) -> void:
	GameManager.set_checkpoint(cp_id)
