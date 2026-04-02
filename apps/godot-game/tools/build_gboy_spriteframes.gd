extends SceneTree


const OUTPUT_PATH := "res://assets/sprites/player/gboy_sprite_frames.tres"
const FRAME_SIZE := Vector2(64, 64)
const ANIMATIONS := {
	# Core platformer
	"idle": {"frames": 8, "speed": 8.0, "loop": true, "sheet": "idle"},
	"run": {"frames": 8, "speed": 12.0, "loop": true, "sheet": "run"},
	"jump": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "jump"},
	"fall": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "fall"},
	"dash": {"frames": 4, "speed": 16.0, "loop": false, "sheet": "dash"},
	"attack": {"frames": 6, "speed": 14.0, "loop": false, "sheet": "attack"},
	"wall_slide": {"frames": 4, "speed": 8.0, "loop": true, "sheet": "wallslide"},
	# Emotions
	"happy": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "happy"},
	"angry": {"frames": 6, "speed": 7.0, "loop": true, "sheet": "angry"},
	"cry": {"frames": 6, "speed": 6.0, "loop": true, "sheet": "cry"},
	"confused": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "confused"},
	"bored": {"frames": 6, "speed": 7.0, "loop": false, "sheet": "bored"},
	"wave": {"frames": 6, "speed": 9.0, "loop": false, "sheet": "wave"},
	# Actions
	"eat": {"frames": 6, "speed": 6.0, "loop": true, "sheet": "eat"},
	"sleep": {"frames": 6, "speed": 3.0, "loop": true, "sheet": "sleep"},
	"sleep_lie": {"frames": 6, "speed": 3.0, "loop": true, "sheet": "sleep_lie"},
	"stretch": {"frames": 6, "speed": 7.0, "loop": false, "sheet": "stretch"},
	"yawn": {"frames": 6, "speed": 6.0, "loop": false, "sheet": "yawn"},
	"stumble": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "stumble"},
	"dance": {"frames": 8, "speed": 10.0, "loop": true, "sheet": "dance"},
	"headjack": {"frames": 6, "speed": 7.0, "loop": false, "sheet": "headjack"},
	"blanket_nest": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "blanket_nest"},
	# Movement
	"walk_side": {"frames": 6, "speed": 10.0, "loop": true, "sheet": "walk_side"},
	"walk_front": {"frames": 6, "speed": 10.0, "loop": true, "sheet": "walk_front"},
	"walk_back": {"frames": 6, "speed": 10.0, "loop": true, "sheet": "walk_back"},
	"walk_left": {"frames": 6, "speed": 10.0, "loop": true, "sheet": "walk_left"},
	"walk_right": {"frames": 6, "speed": 10.0, "loop": true, "sheet": "walk_right"},
	"run_left": {"frames": 6, "speed": 12.0, "loop": true, "sheet": "run_left"},
	"run_right": {"frames": 6, "speed": 12.0, "loop": true, "sheet": "run_right"},
	"sneak": {"frames": 8, "speed": 9.0, "loop": true, "sheet": "sneak"},
	"skateboard": {"frames": 8, "speed": 12.0, "loop": true, "sheet": "skateboard"},
	"drop": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "drop"},
	"jump_side": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "jump_side"},
	# Cape / special
	"cape_flutter": {"frames": 6, "speed": 10.0, "loop": true, "sheet": "cape_flutter"},
	"tongue": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "tongue"},
	"laser": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "laser"},
	"portal": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "portal"},
	"vanish": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "vanish"},
	"glitch": {"frames": 8, "speed": 12.0, "loop": false, "sheet": "glitch"},
	"hide": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "hide"},
	# Directional idles
	"idle_front": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "idle_front"},
	"idle_back": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "idle_back"},
	"idle_left": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "idle_left"},
	"idle_right": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "idle_right"},
	# Climbing / wall
	"climb_side": {"frames": 6, "speed": 9.0, "loop": true, "sheet": "climb_side"},
	"climb_right": {"frames": 6, "speed": 9.0, "loop": true, "sheet": "climb_right"},
	"climb_back": {"frames": 6, "speed": 9.0, "loop": true, "sheet": "climb_back"},
	"wall_sit": {"frames": 6, "speed": 6.0, "loop": true, "sheet": "wall_sit"},
	"peek_left": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "peek_left"},
	"peek_right": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "peek_right"},
	# Look
	"look_left": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "look_left"},
	"look_right": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "look_right"},
	"look_up": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "look_up"},
	"look_down": {"frames": 6, "speed": 10.0, "loop": false, "sheet": "look_down"},
	# Seated pose
	"sit_cross": {"frames": 6, "speed": 6.0, "loop": true, "sheet": "sit_cross"},
	"throne": {"frames": 6, "speed": 6.0, "loop": true, "sheet": "throne"},
	# Graffiti / rebellion
	"graffiti_bloc": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "graffiti_bloc"},
	"graffiti_was_here": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "graffiti_was_here"},
	"spray_tag": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "spray_tag"},
	"sticker_slap": {"frames": 6, "speed": 9.0, "loop": false, "sheet": "sticker_slap"},
	# Activities
	"tv_flip": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "tv_flip"},
	"handheld_game": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "handheld_game"},
	"cook_meal": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "cook_meal"},
	"noodle_eat": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "noodle_eat"},
	"evidence_hack": {"frames": 6, "speed": 8.0, "loop": true, "sheet": "evidence_hack"},
	"computer_idle": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "computer_idle"},
	"terminal_type": {"frames": 6, "speed": 6.0, "loop": true, "sheet": "terminal_type"},
	"crt_watch": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "crt_watch"},
	"radio_listen": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "radio_listen"},
	"desk_noodles": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "desk_noodles"},
	"desk_sketch": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "desk_sketch"},
	"file_sort": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "file_sort"},
	"mug_sip": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "mug_sip"},
	"file_scan": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "file_scan"},
	"zine_read": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "zine_read"},
	"pinboard_plot": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "pinboard_plot"},
	"monitor_lurk": {"frames": 6, "speed": 5.0, "loop": true, "sheet": "monitor_lurk"},
	"fridge_open": {"frames": 6, "speed": 8.0, "loop": false, "sheet": "fridge_open"},
	# Surveillance
	"bug_sweep": {"frames": 6, "speed": 7.0, "loop": true, "sheet": "bug_sweep"},
	# New 8-frame animations
	"spin": {"frames": 8, "speed": 12.0, "loop": false, "sheet": "spin"},
	"tantrum": {"frames": 8, "speed": 10.0, "loop": true, "sheet": "tantrum"},
	"float": {"frames": 8, "speed": 6.0, "loop": true, "sheet": "float"},
	"shiver": {"frames": 8, "speed": 14.0, "loop": true, "sheet": "shiver"},
	"applaud": {"frames": 8, "speed": 10.0, "loop": true, "sheet": "applaud"},
	"dizzy": {"frames": 8, "speed": 8.0, "loop": true, "sheet": "dizzy"},
	"bow": {"frames": 8, "speed": 7.0, "loop": false, "sheet": "bow"},
	"moonwalk": {"frames": 8, "speed": 10.0, "loop": true, "sheet": "moonwalk"},
	"backflip": {"frames": 8, "speed": 12.0, "loop": false, "sheet": "backflip"},
	"typing_fast": {"frames": 8, "speed": 10.0, "loop": true, "sheet": "typing_fast"},
	"phone_call": {"frames": 8, "speed": 8.0, "loop": true, "sheet": "phone_call"},
	"umbrella": {"frames": 8, "speed": 10.0, "loop": true, "sheet": "umbrella"},
}


func _initialize() -> void:
	var frames := SpriteFrames.new()

	for animation_name in ANIMATIONS.keys():
		if frames.has_animation(animation_name):
			frames.remove_animation(animation_name)

		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, ANIMATIONS[animation_name]["speed"])
		frames.set_animation_loop(animation_name, ANIMATIONS[animation_name]["loop"])

		var texture := _load_texture("res://assets/sprites/player/%s_sheet.png" % ANIMATIONS[animation_name]["sheet"])
		if texture == null:
			push_error("Missing sheet for animation: %s" % animation_name)
			quit(1)
			return

		for frame_index in range(ANIMATIONS[animation_name]["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(frame_index * FRAME_SIZE.x, 0), FRAME_SIZE)
			frames.add_frame(animation_name, atlas, 1.0)

	var err := ResourceSaver.save(frames, OUTPUT_PATH)
	if err != OK:
		push_error("Failed to save sprite frames: %s" % error_string(err))
		quit(1)
		return

	print("Saved sprite frames to %s" % OUTPUT_PATH)
	quit()


func _load_texture(path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(global_path)
	if image == null or image.is_empty():
		var resource := load(path)
		if resource is Texture2D:
			return resource
		return null

	return ImageTexture.create_from_image(image)
