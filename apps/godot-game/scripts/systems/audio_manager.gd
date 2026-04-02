extends Node

## Audio Manager for GBOY
## Handles music and SFX playback

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX = 8


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	for i in range(MAX_SFX):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)


func play_music(stream: AudioStream, fade_in: float = 1.0) -> void:
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.volume_db = -80.0
	music_player.play()
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", 0.0, fade_in)


func stop_music(fade_out: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, fade_out)
	tween.tween_callback(music_player.stop)


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return
