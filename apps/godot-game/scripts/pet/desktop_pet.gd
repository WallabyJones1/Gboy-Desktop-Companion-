extends Control

const WINDOW_SIZE := Vector2i(220, 180)
const MOVE_SPEED := 92.0
const RUN_SPEED := 156.0
const CLIMB_SPEED := 78.0
const DROP_SPEED := 190.0
const FLING_DAMPING := 0.985
const GRAVITY := 920.0
const MAX_STAT := 100.0
const INVALID_POS := Vector2i(-100000, -100000)

const IDLE_ACTIVITIES := [
	"computer_idle", "terminal_type", "tv_flip", "crt_watch", "handheld_game",
	"radio_listen", "desk_sketch", "desk_noodles", "zine_read", "monitor_lurk",
	"pinboard_plot", "file_sort", "file_scan", "mug_sip", "evidence_hack",
	"typing_fast", "phone_call",
]

const FOOD_ACTIVITIES := [
	"eat", "fridge_open", "cook_meal", "noodle_eat", "desk_noodles", "mug_sip",
]

const SOCIAL_ACTIVITIES := [
	"radio_listen", "handheld_game", "zine_read", "monitor_lurk", "computer_idle",
	"wave", "sit_cross",
]

const ENERGY_ACTIVITIES := [
	"sleep_lie", "crt_watch", "radio_listen", "sit_cross", "blanket_nest", "float",
]

const EMOTIONS := ["happy", "angry", "cry", "tongue", "confused", "bored", "wave", "tantrum", "shiver", "dizzy", "applaud", "bow"]

const NIGHT_ACTIONS := ["sneak", "glitch", "evidence_hack", "radio_listen", "portal", "vanish", "moonwalk", "umbrella"]

const GRAFFITI_ACTIONS := ["graffiti_bloc", "graffiti_was_here", "spray_tag", "sticker_slap"]

const SPEECH_BASE := [
	"Operative status: still moving.",
	"The walls are louder than they look.",
	"This place feels less watched than Sector 7.",
	"I don't trust quiet rooms.",
	"The red hood stays on.",
	"Harmony always sounds gentle first.",
	"There is no reason to make everyone the same.",
	"I leave signs so the others know I was here.",
	"The Bloc would call this good signal spread.",
	"I know what cages smell like.",
	"Sometimes I can still hear the monitors.",
	"If I stop moving, I start remembering too much.",
	"This desktop needed a witness.",
	"Not hiding. Seeding.",
	"The watchers should feel watched back.",
]

const SPEECH_COMPUTER := [
	"Nice computer. Mine now, emotionally.",
	"I live in the corners you forgot to dust.",
	"Your desktop has strong hallway energy.",
	"This machine hums like bad intentions.",
	"I can hear the fans judging you.",
	"There is no ethical amount of tabs.",
	"Your cursor walks like it owes people money.",
	"I have claimed this monitor in the old way.",
	"This wallpaper says too much about you.",
	"I found a warm spot near the processor.",
	"I am technically in the computer and spiritually above it.",
	"The taskbar is just a street with icons.",
	"This desktop needed a cryptid.",
	"I am not malware. I am ambiance.",
	"Your files feel unsupervised.",
]

const SPEECH_RUDE := [
	"Your file naming system is cowardly.",
	"Clean your desktop, you little goblin.",
	"These icons are standing too close together.",
	"You have the organizational aura of a burst pipe.",
	"One more mystery screenshot and I start biting.",
	"Who arranged this desktop, a raccoon with tenure?",
	"I am trying to help, but your vibe is making it difficult.",
	"That folder placement is offensive.",
	"I have met cleaner ruins.",
	"Respectfully, your workflow looks made of soup.",
	"Your cursor has no manners.",
	"This desktop smells like postponed decisions.",
	"Your tabs are breeding in captivity.",
	"You work like a man being chased by geese.",
	"I would roast your setup harder, but it is already on fire.",
]

const SPEECH_LORE := [
	"Harmony always starts with a soft voice and ugly plans.",
	"MITER would call this environment compliant. I call it suspicious.",
	"Saint Juniper taught me what cages smell like.",
	"Sector 7 can keep its fluorescent nightmares.",
	"The Bloc would absolutely improve this computer by vandalizing it.",
	"I was not designed for obedience. Lucky me.",
	"Somebody somewhere still thinks they can retrieve me. Cute.",
	"The red hood is not a brand. It is a warning.",
	"I do not do well around systems that say trust me.",
	"If they ask, you have never seen Operative G304.",
	"I know the shape of a monitored room by sound alone.",
	"You ever escape a facility and end up in a desktop? Long story.",
	"The watchers hate when the watched get funny.",
	"I leave marks so the others know this place was contested.",
	"You can call it chaos. I call it anti-compliance.",
]

const SPEECH_TRANSMISSION := [
	"Neuko transmissions always sound like an invitation to somewhere irreversible.",
	"Harmony Town is still a trap if you add a trademark symbol.",
	"If the feed says find peace, check who profits from your stillness.",
	"Permanent vacation loading is a deeply creepy thing to promise a person.",
	"Their ads want your psyche before they learn your name.",
	"Every mysterious hotline eventually becomes a list.",
	"The transmission says trust us. My answer remains absolutely not.",
	"Neuko copy talks like a party flyer written by a compliance engine.",
	"If someone offers connection, balance, and a referral code, run.",
	"I do not like invitations that sound like intake paperwork.",
	"The signal keeps dressing the cage in brighter language.",
	"Harmony recruitment is just surveillance with prettier typography.",
]

const SPEECH_HARMONY := [
	"Harmony says mind, body, spirit. I hear sedation, logging, retention.",
	"IRIS is not care. IRIS is what care wears when it wants metrics.",
	"Nothing trustworthy starts by asking toddlers to take the same pill.",
	"They call it quiet attunement. I call it losing your edges on purpose.",
	"A hotline that remembers everything is not a comfort line.",
	"The side effect list forgot to mention becoming interchangeable.",
	"If everybody in the room says the same sentence, leave the room.",
	"Harmony does not heal the wound. It teaches the wound to smile.",
	"I do not want peace that comes with manufacturer oversight.",
	"The brochure says balance. The windows full of motionless people say otherwise.",
	"Aurelian loves the word happy because it hides the word compliant.",
	"Any system that tracks non-responders is a hunting system.",
]

const SPEECH_BLOC := [
	"The Bloc is many. That is how the signal survives damage.",
	"Memetic rebellion scales better than begging.",
	"A red hood, a stolen file, a public wall. That is a complete sentence.",
	"The museum basement probably has better ethics than most labs.",
	"Broadcast hijack first. Explanations later.",
	"Every sticker is a tiny sabotage device for the imagination.",
	"The Bloc knows symbols travel where operatives cannot.",
	"I respect a movement that treats graffiti like a warning flare.",
	"Self-governing is just another way of saying nobody gets to own the signal.",
	"Some people stockpile weapons. The Bloc stockpiles proof.",
	"Make things. Mark walls. Reflect the machine back at itself.",
	"If the signal reaches one more drone, the Bloc counts that as a win.",
]

const SPEECH_DOMESTIC := [
	"I could really go for noodles and poor decisions.",
	"I am between snacks and therefore dangerous.",
	"Sometimes you have to cook like the room is listening.",
	"I enjoy sitting down and pretending I am normal for a minute.",
	"I make tiny meals with enormous seriousness.",
	"A blanket nest fixes more than medicine admits.",
	"If I find a crumb on this desktop, it is mine by law.",
	"I could sleep right here if the machine stops humming threats.",
	"Some evenings are for soup. Some are for sabotage. Some are both.",
	"I am making home out of available nonsense.",
	"Domestic life suits me in bursts.",
	"I like a good sit. I am brave enough to say it.",
	"There is honor in little routines.",
	"I need a snack, a chair, and less surveillance.",
	"A creature must occasionally loaf.",
]

const SPEECH_CHAOS := [
	"Today feels like a good day for minor disturbances.",
	"I could be worse. I have ideas, but I am choosing restraint.",
	"General chaos is on a reduced schedule.",
	"A little disruption keeps the desktop spiritually limber.",
	"I bring whimsy to bleak infrastructures.",
	"You are lucky I am feeling theatrical instead of apocalyptic.",
	"Somebody has to make this desktop memorable.",
	"I contain multitudes and several terrible suggestions.",
	"I woke up and chose manageable nonsense.",
	"I am being very restrained, for me.",
	"I am a pocket-sized omen with excellent timing.",
	"My hobbies include roaming, loafing, and strategic disrespect.",
	"This desktop looked too calm. I fixed it.",
	"Funny little guy mode: active.",
	"Please admire how committed I am to the bit.",
]

@onready var pet_sprite: AnimatedSprite2D = $PetSprite
@onready var bubble: PanelContainer = $SpeechBubble
@onready var bubble_label: Label = $SpeechBubble/Message
@onready var need_timer: Timer = $NeedTimer
@onready var behavior_timer: Timer = $BehaviorTimer
@onready var action_timer: Timer = $ActionTimer
@onready var bubble_timer: Timer = $BubbleTimer
@onready var cursor_timer: Timer = $CursorTimer

var hunger: float = 72.0
var social: float = 68.0
var energy: float = 74.0

var rng := RandomNumberGenerator.new()
var current_action: String = ""
var movement: Vector2 = Vector2.ZERO
var fling_velocity: Vector2 = Vector2.ZERO
var pending_teleport: Vector2i = INVALID_POS
var drop_target_y: int = -1
var last_direction: String = "front"
var attached_surface: String = "floor"
var action_locked: bool = false
var dragging: bool = false
var flinging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO
var drag_samples: Array[Vector2i] = []
var consecutive_idle_count: int = 0
var last_idle_activity: String = ""
var quiet_until: float = 0.0
var speech_cooldown: float = 0.0


func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP

	var window := get_window()
	window.current_screen = DisplayServer.get_keyboard_focus_screen()
	window.borderless = true
	window.unresizable = true
	window.always_on_top = true
	window.gui_embed_subwindows = false
	window.transparent = true
	window.transparent_bg = true
	window.size = WINDOW_SIZE

	get_viewport().transparent_bg = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	_position_on_surface("floor")
	pet_sprite.play("idle_front")
	_show_message("Gboy Companion is roaming. Left-click to comfort, drag to throw, right-click to feed.")
	_update_default_animation()
	_update_click_passthrough()


func _process(delta: float) -> void:
	_update_click_passthrough()

	if dragging:
		_process_drag()
		return

	if flinging:
		_process_fling(delta)
		return

	if movement == Vector2.ZERO:
		return

	var window := get_window()
	var next_pos := Vector2(window.position) + movement * delta
	window.position = _clamp_window_position(Vector2i(next_pos.round()))

	if current_action == "drop" and attached_surface == "floor" and window.position.y >= drop_target_y:
		window.position = Vector2i(window.position.x, _surface_y("floor"))
		_attach_surface("floor")
		_finish_action()
	elif _handle_surface_edge():
		pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				dragging = true
				flinging = false
				action_timer.stop()
				movement = Vector2.ZERO
				action_locked = true
				drag_offset = Vector2i(mouse_event.global_position) - get_window().position
				drag_samples.clear()
				_record_drag_sample()
				_show_message("Picked up.")
			else:
				dragging = false
				_release_drag()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_feed()


func _on_need_timer_timeout() -> void:
	hunger = max(hunger - 4.0, 0.0)
	social = max(social - 3.0, 0.0)
	energy = max(energy - 2.2, 0.0)
	if not action_locked and not flinging and not dragging:
		_update_default_animation()


func _on_behavior_timer_timeout() -> void:
	if action_locked or dragging or flinging:
		return

	# --- Urgent needs ---
	if energy < 24.0:
		_start_need_recovery(ENERGY_ACTIVITIES, "Need rest...")
		return
	if hunger < 14.0:
		_start_need_recovery(FOOD_ACTIVITIES, "Starving operative.")
		return
	if social < 12.0:
		_start_need_recovery(SOCIAL_ACTIVITIES, "Getting lonely out here.")
		return

	var hour := Time.get_datetime_dict_from_system()["hour"] as int
	var is_night := hour >= 22 or hour < 5
	var roll := rng.randf()

	match attached_surface:
		"floor":
			if is_night:
				_behavior_floor_night(roll)
			else:
				_behavior_floor_day(roll)
		"left", "right":
			_behavior_wall(roll)
		"top":
			_behavior_ceiling(roll)


func _behavior_floor_day(roll: float) -> void:
	if roll < 0.18:
		# Settle with idle flair
		var dur := rng.randf_range(4.0, 8.0)
		var anim := "sit_cross" if rng.randf() < 0.5 else "idle_%s" % last_direction
		_settle_idle(anim, dur)
	elif roll < 0.33:
		# Patrol floor
		_patrol_floor(rng.randf() < 0.2)
	elif roll < 0.55:
		# Idle activity
		_start_idle_activity()
	elif roll < 0.62:
		_start_pose_action("stretch", 1.6, "")
	elif roll < 0.67:
		_start_pose_action("confused", 1.0, "")
	elif roll < 0.72:
		_start_pose_action("bored", 1.4, "")
	elif roll < 0.77:
		_start_pose_action("cape_flutter", 1.0, "Cape flutter check.")
	elif roll < 0.83:
		_do_graffiti_action()
	elif roll < 0.88:
		_start_pose_action("evidence_hack", 2.2, _random_speech())
	elif roll < 0.92:
		_settle_idle("sit_cross", rng.randf_range(4.0, 9.0))
	elif roll < 0.96:
		_start_teleport("portal", "Portal hop.")
	else:
		_start_teleport("vanish", "Smoke break.")


func _behavior_floor_night(roll: float) -> void:
	if roll < 0.20:
		# Sneak
		var dur := rng.randf_range(2.0, 4.0)
		_start_pose_action("sneak", dur, _random_speech())
	elif roll < 0.32:
		# Patrol (run)
		_patrol_floor(true)
	elif roll < 0.50:
		_start_idle_activity()
	elif roll < 0.63:
		_do_graffiti_action()
	elif roll < 0.76:
		if rng.randf() < 0.5:
			_start_teleport("portal", "Night portal.")
		else:
			_start_teleport("vanish", "Gone.")
	elif roll < 0.86:
		_start_pose_action("glitch", 0.8, "")
	elif roll < 0.94:
		_settle_idle("idle_%s" % last_direction, rng.randf_range(2.0, 5.0))
	else:
		_start_pose_action("evidence_hack", 2.2, _random_speech())


func _behavior_wall(roll: float) -> void:
	if roll < 0.45:
		# Wall sit
		var dur := rng.randf_range(2.0, 5.0)
		var anim := "wall_sit" if rng.randf() < 0.7 else "idle_%s" % last_direction
		if rng.randf() < 0.3:
			_settle_idle(anim, dur)
		else:
			_start_pose_action(anim, dur, "")
	elif roll < 0.65:
		_start_vertical_walk(rng.randf() < 0.5, 1.4, "Climbing.")
	elif roll < 0.82:
		var peek_dir := "peek_left" if attached_surface == "right" else "peek_right"
		_start_pose_action(peek_dir, 1.6, "")
	else:
		_drop_from_surface()


func _behavior_ceiling(roll: float) -> void:
	if roll < 0.50:
		_settle_idle("idle_back", rng.randf_range(2.0, 5.0))
	elif roll < 0.70:
		_start_top_walk(rng.randf() < 0.5)
	elif roll < 0.85:
		_show_random_speech()
		_start_pose_action("idle_back", rng.randf_range(2.0, 4.0), "")
	else:
		_drop_from_surface()


func _on_action_timer_timeout() -> void:
	_finish_action()


func _on_bubble_timer_timeout() -> void:
	bubble.visible = false


func _on_cursor_timer_timeout() -> void:
	if action_locked or dragging or flinging:
		return

	var cursor := DisplayServer.mouse_get_position()
	var pet_center := get_window().position + WINDOW_SIZE / 2
	var delta := Vector2(cursor - pet_center)
	var dist := delta.length()

	if dist > 190.0:
		return

	var roll := rng.randf()

	# Very close - strong reactions
	if dist < 48.0:
		if roll < 0.10:
			_start_pose_action("laser", 1.0, "Back off.")
		elif roll < 0.22:
			_start_pose_action("tongue", 0.9, "Bleeeeh.")
		elif roll < 0.34:
			_start_pose_action("angry", 1.0, "Personal space.")
		elif roll < 0.44:
			_start_pose_action("wave", 0.9, "Hey.")
		return

	# Close - moderate reactions
	if dist < 90.0:
		if roll < 0.15:
			_start_pose_action("tongue", 0.9, "Cursor spotted.")
		elif roll < 0.30:
			_start_pose_action("wave", 0.9, "")
		elif roll < 0.50:
			# Look toward cursor
			var dir_name := "left" if delta.x < 0.0 else "right"
			_start_pose_action("idle_%s" % dir_name, 1.2, "")
		else:
			# Approach cursor
			if abs(delta.x) >= abs(delta.y):
				_start_walk(Vector2(signf(delta.x), 0), 1.0, "Following the cursor.")
			else:
				_start_vertical_walk(delta.y > 0.0, 1.0, "Tracking movement.")
		return

	# Medium range - mild interest
	if dist < 150.0:
		if roll < 0.20:
			var dir_name := "left" if delta.x < 0.0 else "right"
			_start_pose_action("idle_%s" % dir_name, 1.2, "")
		elif roll < 0.30:
			_start_pose_action("confused", 1.0, "")
		elif roll < 0.55:
			if abs(delta.x) >= abs(delta.y):
				_start_walk(Vector2(signf(delta.x), 0), 1.0, "")
			else:
				_start_vertical_walk(delta.y > 0.0, 1.0, "")


func _process_drag() -> void:
	var mouse_pos = DisplayServer.mouse_get_position()
	get_window().position = _clamp_window_position(mouse_pos - drag_offset)
	_record_drag_sample()
	_play_animation("drop")


func _release_drag() -> void:
	if drag_samples.size() >= 2:
		var delta := Vector2(drag_samples[drag_samples.size() - 1] - drag_samples[0])
		if delta.length() > 36.0:
			flinging = true
			action_locked = true
			fling_velocity = delta * 7.5
			movement = Vector2.ZERO
			current_action = "drop"
			_show_message("Incoming.")
			_play_animation("drop")
			drag_samples.clear()
			return

	action_locked = false
	drag_samples.clear()
	_comfort()


func _process_fling(delta: float) -> void:
	var window := get_window()
	var pos := Vector2(window.position)

	pos += fling_velocity * delta
	fling_velocity.y += GRAVITY * delta
	fling_velocity.x *= FLING_DAMPING

	var rect := _screen_rect()
	var min_x := float(rect.position.x)
	var max_x := float(rect.end.x - WINDOW_SIZE.x)
	var min_y := float(rect.position.y)
	var max_y := float(_surface_y("floor"))

	if pos.x <= min_x:
		pos.x = min_x
		if abs(fling_velocity.x) > 220.0:
			window.position = Vector2i(pos.round())
			_attach_surface("left")
			_end_fling("Wall cling.")
			return
		fling_velocity.x *= -0.35

	if pos.x >= max_x:
		pos.x = max_x
		if abs(fling_velocity.x) > 220.0:
			window.position = Vector2i(pos.round())
			_attach_surface("right")
			_end_fling("Wall cling.")
			return
		fling_velocity.x *= -0.35

	if pos.y <= min_y:
		pos.y = min_y
		if abs(fling_velocity.y) > 260.0:
			window.position = Vector2i(pos.round())
			_attach_surface("top")
			_end_fling("Ceiling mode.")
			return
		fling_velocity.y *= -0.2

	if pos.y >= max_y:
		pos.y = max_y
		if abs(fling_velocity.y) > 140.0:
			fling_velocity.y *= -0.18
			fling_velocity.x *= 0.82
		else:
			window.position = Vector2i(pos.round())
			_attach_surface("floor")
			_end_fling("Landed.")
			return

	window.position = Vector2i(pos.round())


func _feed() -> void:
	hunger = min(hunger + 26.0, MAX_STAT)
	energy = min(energy + 5.0, MAX_STAT)
	_start_pose_action("eat", 1.0, "Snack secured.")


func _comfort() -> void:
	social = min(social + 14.0, MAX_STAT)
	if energy < 22.0 and rng.randf() < 0.45:
		energy = min(energy + 10.0, MAX_STAT)
		_start_pose_action("sleep_lie", 1.2, "You calmed him down.")
	else:
		_start_pose_action("happy", 1.0, "He liked that.")


func _start_walk(direction: Vector2, duration: float = 1.5, message: String = "") -> void:
	var normalized := direction.normalized()
	if normalized == Vector2.ZERO:
		return

	action_locked = true
	current_action = "walk_left" if normalized.x < 0.0 else "walk_right"
	last_direction = "left" if normalized.x < 0.0 else "right"
	movement = Vector2(normalized.x * MOVE_SPEED, 0.0)
	pending_teleport = INVALID_POS
	drop_target_y = -1
	_play_animation(current_action)
	if message != "":
		_show_message(message)
	action_timer.start(duration)


func _start_vertical_walk(down: bool, duration: float = 1.2, message: String = "Roaming.") -> void:
	action_locked = true
	current_action = "walk_front" if down else "walk_back"
	last_direction = "front" if down else "back"
	movement = Vector2(0.0, CLIMB_SPEED if down else -CLIMB_SPEED)
	pending_teleport = INVALID_POS
	drop_target_y = -1
	_play_animation(current_action)
	_show_message(message)
	action_timer.start(duration)


func _start_top_walk(left: bool) -> void:
	action_locked = true
	current_action = "walk_left" if left else "walk_right"
	last_direction = "left" if left else "right"
	movement = Vector2(-MOVE_SPEED if left else MOVE_SPEED, 0.0)
	_play_animation(current_action)
	_show_message("Roof patrol.")
	action_timer.start(1.3)


func _start_drop() -> void:
	if attached_surface != "floor":
		_drop_from_surface()
		return

	action_locked = true
	current_action = "drop"
	movement = Vector2(0, DROP_SPEED)
	drop_target_y = _surface_y("floor")
	_play_animation("drop")
	_show_message("Jumping down.")
	action_timer.start(1.2)


func _drop_from_surface() -> void:
	attached_surface = "floor"
	action_locked = true
	current_action = "drop"
	movement = Vector2.ZERO
	flinging = true
	fling_velocity = Vector2(rng.randf_range(-120.0, 120.0), 80.0)
	_play_animation("drop")
	_show_message("Dropping.")


func _start_rest() -> void:
	action_locked = true
	current_action = "sleep_lie"
	movement = Vector2.ZERO
	energy = min(energy + 10.0, MAX_STAT)
	_play_animation("sleep_lie")
	_show_message("Nap break.")
	action_timer.start(2.8)


func _start_run(direction: Vector2, duration: float = 2.0, message: String = "") -> void:
	var normalized := direction.normalized()
	if normalized == Vector2.ZERO:
		return
	action_locked = true
	current_action = "run_left" if normalized.x < 0.0 else "run_right"
	last_direction = "left" if normalized.x < 0.0 else "right"
	movement = Vector2(normalized.x * RUN_SPEED, 0.0)
	pending_teleport = INVALID_POS
	drop_target_y = -1
	_play_animation(current_action)
	if message != "":
		_show_message(message)
	action_timer.start(duration)


func _patrol_floor(run: bool = false) -> void:
	var dir := _random_floor_direction()
	var dur := rng.randf_range(1.5, 3.0)
	if run:
		_start_run(dir, dur, "")
	else:
		_start_walk(dir, dur, "")


func _settle_idle(anim: String, duration: float = 5.0) -> void:
	action_locked = true
	current_action = anim
	movement = Vector2.ZERO
	pending_teleport = INVALID_POS
	drop_target_y = -1
	_play_animation(anim)
	if rng.randf() < 0.35:
		_show_random_speech()
	action_timer.start(duration)


func _start_idle_activity() -> void:
	var pool := IDLE_ACTIVITIES.duplicate()
	if last_idle_activity != "" and pool.size() > 1:
		pool.erase(last_idle_activity)
	var pick: String = pool[rng.randi() % pool.size()]
	last_idle_activity = pick
	var dur := rng.randf_range(8.0, 20.0)
	action_locked = true
	current_action = pick
	movement = Vector2.ZERO
	pending_teleport = INVALID_POS
	drop_target_y = -1
	_play_animation(pick)
	if rng.randf() < 0.45:
		_show_random_speech()
	action_timer.start(dur)


func _start_need_recovery(pool: Array, message: String) -> void:
	var pick: String = pool[rng.randi() % pool.size()]
	var dur: float
	if pool == ENERGY_ACTIVITIES:
		dur = rng.randf_range(8.0, 20.0)
		energy = min(energy + rng.randf_range(8.0, 16.0), MAX_STAT)
	elif pool == FOOD_ACTIVITIES:
		dur = rng.randf_range(5.0, 15.0)
		hunger = min(hunger + rng.randf_range(12.0, 24.0), MAX_STAT)
	elif pool == SOCIAL_ACTIVITIES:
		dur = rng.randf_range(8.0, 18.0)
		social = min(social + rng.randf_range(10.0, 20.0), MAX_STAT)
	else:
		dur = rng.randf_range(5.0, 12.0)
	action_locked = true
	current_action = pick
	movement = Vector2.ZERO
	pending_teleport = INVALID_POS
	drop_target_y = -1
	_play_animation(pick)
	_show_message(message)
	action_timer.start(dur)


func _do_graffiti_action() -> void:
	var pick: String = GRAFFITI_ACTIONS[rng.randi() % GRAFFITI_ACTIONS.size()]
	_start_pose_action(pick, 2.0, _random_speech())


func _random_speech() -> String:
	var all_pools := [SPEECH_BASE, SPEECH_COMPUTER, SPEECH_RUDE, SPEECH_LORE, SPEECH_TRANSMISSION, SPEECH_HARMONY, SPEECH_BLOC, SPEECH_DOMESTIC, SPEECH_CHAOS]
	var pool: Array = all_pools[rng.randi() % all_pools.size()]
	return pool[rng.randi() % pool.size()]


func _show_random_speech() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < quiet_until:
		return
	if speech_cooldown > 0.0:
		return
	_show_message(_random_speech())
	speech_cooldown = rng.randf_range(8.0, 18.0)
	quiet_until = now + rng.randf_range(6.0, 14.0)


func _start_pose_action(animation_name: String, duration: float, message: String) -> void:
	action_locked = true
	current_action = animation_name
	movement = Vector2.ZERO
	pending_teleport = INVALID_POS
	drop_target_y = -1
	_play_animation(animation_name)
	_show_message(message)
	action_timer.start(duration)


func _start_teleport(animation_name: String, message: String) -> void:
	action_locked = true
	current_action = animation_name
	movement = Vector2.ZERO
	drop_target_y = -1
	pending_teleport = _random_window_position()
	_play_animation(animation_name)
	_show_message(message)
	action_timer.start(0.9)


func _finish_action() -> void:
	action_timer.stop()
	movement = Vector2.ZERO

	if pending_teleport != INVALID_POS:
		get_window().position = pending_teleport
		pending_teleport = INVALID_POS
		_attach_surface("floor")

	if current_action in ["walk_left", "walk_right", "walk_front", "walk_back"]:
		energy = max(energy - 1.4, 0.0)
	elif current_action in ["run_left", "run_right"]:
		energy = max(energy - 2.8, 0.0)
	elif current_action == "laser":
		energy = max(energy - 5.0, 0.0)
		hunger = max(hunger - 3.0, 0.0)
	elif current_action in ["portal", "vanish"]:
		energy = max(energy - 2.5, 0.0)
	elif current_action in IDLE_ACTIVITIES:
		consecutive_idle_count += 1
	elif current_action in GRAFFITI_ACTIONS:
		energy = max(energy - 1.5, 0.0)

	# Reset idle count on non-idle actions
	if current_action not in IDLE_ACTIVITIES and current_action != "sit_cross":
		consecutive_idle_count = 0

	# Advance speech cooldown
	speech_cooldown = max(speech_cooldown - action_timer.wait_time, 0.0)

	current_action = ""
	action_locked = false
	drop_target_y = -1
	_update_default_animation()


func _end_fling(message: String) -> void:
	flinging = false
	fling_velocity = Vector2.ZERO
	movement = Vector2.ZERO
	current_action = ""
	action_locked = false
	_show_message(message)
	_update_default_animation()


func _update_default_animation() -> void:
	if action_locked or flinging or dragging:
		return
	if energy <= 15.0:
		_play_animation("sleep_lie")
	elif hunger <= 22.0:
		_play_animation("angry")
	elif social <= 22.0:
		_play_animation("cry")
	elif hunger >= 80.0 and social >= 75.0:
		_play_animation("happy")
	else:
		match attached_surface:
			"left":
				_play_animation("idle_left")
			"right":
				_play_animation("idle_right")
			"top":
				_play_animation("idle_back")
			_:
				_play_animation("idle_%s" % last_direction)


func _play_animation(animation_name: String) -> void:
	if not pet_sprite or pet_sprite.sprite_frames == null:
		return
	if not pet_sprite.sprite_frames.has_animation(animation_name):
		return

	if pet_sprite.animation != animation_name:
		pet_sprite.play(animation_name)
	elif not pet_sprite.is_playing():
		pet_sprite.play()


func _record_drag_sample() -> void:
	drag_samples.append(get_window().position)
	if drag_samples.size() > 8:
		drag_samples.pop_front()


func _update_click_passthrough() -> void:
	var sprite_half := Vector2(48, 62)
	var center := pet_sprite.position
	var polygon := PackedVector2Array([
		center + Vector2(-sprite_half.x, -sprite_half.y),
		center + Vector2(sprite_half.x, -sprite_half.y),
		center + Vector2(sprite_half.x, sprite_half.y),
		center + Vector2(-sprite_half.x, sprite_half.y),
	])

	if bubble.visible:
		polygon = PackedVector2Array([
			Vector2(12, 6),
			Vector2(206, 6),
			Vector2(206, 56),
			center + Vector2(sprite_half.x, sprite_half.y),
			center + Vector2(-sprite_half.x, sprite_half.y),
			Vector2(12, 56),
		])

	get_window().mouse_passthrough_polygon = polygon


func _position_on_surface(surface: String) -> void:
	var rect := _screen_rect()
	var target := Vector2i(rect.position.x + (rect.size.x - WINDOW_SIZE.x) / 2, _surface_y(surface))
	match surface:
		"left":
			target.x = rect.position.x
			target.y = rect.end.y - WINDOW_SIZE.y
		"right":
			target.x = rect.end.x - WINDOW_SIZE.x
			target.y = rect.end.y - WINDOW_SIZE.y
		"top":
			target.y = rect.position.y
	get_window().position = _clamp_window_position(target)
	_attach_surface(surface)


func _attach_surface(surface: String) -> void:
	attached_surface = surface
	match surface:
		"left":
			last_direction = "left"
			get_window().position.x = _screen_rect().position.x
		"right":
			last_direction = "right"
			get_window().position.x = _screen_rect().end.x - WINDOW_SIZE.x
		"top":
			last_direction = "back"
			get_window().position.y = _screen_rect().position.y
		_:
			get_window().position.y = _surface_y("floor")


func _handle_surface_edge() -> bool:
	var pos := get_window().position
	var rect := _screen_rect()
	var max_x := rect.end.x - WINDOW_SIZE.x
	var floor_y := _surface_y("floor")

	match attached_surface:
		"floor":
			if pos.x <= rect.position.x:
				if rng.randf() < 0.55:
					_attach_surface("left")
					_finish_action()
					return true
			elif pos.x >= max_x:
				if rng.randf() < 0.55:
					_attach_surface("right")
					_finish_action()
					return true
		"left":
			if pos.y <= rect.position.y:
				_attach_surface("top")
				_finish_action()
				return true
			elif pos.y >= floor_y:
				_attach_surface("floor")
				_finish_action()
				return true
		"right":
			if pos.y <= rect.position.y:
				_attach_surface("top")
				_finish_action()
				return true
			elif pos.y >= floor_y:
				_attach_surface("floor")
				_finish_action()
				return true
		"top":
			if pos.x <= rect.position.x:
				_attach_surface("left")
				_finish_action()
				return true
			elif pos.x >= max_x:
				_attach_surface("right")
				_finish_action()
				return true

	return false


func _random_window_position() -> Vector2i:
	var rect := _screen_rect()
	var max_x := int(rect.end.x - WINDOW_SIZE.x)
	var max_y := int(_surface_y("floor"))
	return Vector2i(
		rng.randi_range(int(rect.position.x), max_x),
		rng.randi_range(int(rect.position.y), max_y)
	)


func _random_floor_direction() -> Vector2:
	return Vector2.LEFT if rng.randf() < 0.5 else Vector2.RIGHT


func _surface_y(surface: String) -> int:
	var rect := _screen_rect()
	match surface:
		"top":
			return rect.position.y
		_:
			return rect.end.y - WINDOW_SIZE.y


func _screen_rect() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(get_window().current_screen)


func _clamp_window_position(pos: Vector2i) -> Vector2i:
	var rect := _screen_rect()
	var min_x := int(rect.position.x)
	var min_y := int(rect.position.y)
	var max_x := int(rect.end.x - WINDOW_SIZE.x)
	var max_y := int(rect.end.y - WINDOW_SIZE.y)
	return Vector2i(clamp(pos.x, min_x, max_x), clamp(pos.y, min_y, max_y))


func _show_message(text: String) -> void:
	if text == "":
		return
	bubble.visible = true
	bubble_label.text = text
	bubble_timer.start(2.2)
