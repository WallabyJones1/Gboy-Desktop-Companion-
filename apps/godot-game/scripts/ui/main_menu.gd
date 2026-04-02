extends Control

const DEFAULT_LEVEL_ID := "miter_lab_01"

## GBOY: Escape from MITER - Main Menu
## Inspired by the cryptic aesthetic of Neuko transmissions

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var new_game_btn: Button = $VBoxContainer/ButtonContainer/NewGameBtn
@onready var continue_btn: Button = $VBoxContainer/ButtonContainer/ContinueBtn
@onready var quit_btn: Button = $VBoxContainer/ButtonContainer/QuitBtn
@onready var transmission_label: Label = $TransmissionLabel

var glitch_timer: float = 0.0
var transmissions: Array[String] = [
	">> SIGNAL INTERCEPTED... SOURCE: UNKNOWN",
	">> MITER-CORP CLASSIFIED // CLEARANCE: G304",
	">> SUBJECT STATUS: ESCAPED // ALERT LEVEL: CRITICAL",
	">> THE BADGES ARE NOT WHAT THEY SEEM",
	">> VARIANT B CONTAINMENT: COMPROMISED",
	">> PHASE 1 INITIATED // OPERATIVES ONLINE",
	">> [REDACTED] WAS NEVER A COINCIDENCE",
	">> WE ARE WATCHING // WE HAVE ALWAYS BEEN WATCHING",
]


func _ready() -> void:
	# Style the menu
	if title_label:
		title_label.text = "G*BOY"

	if subtitle_label:
		subtitle_label.text = "ESCAPE FROM MITER"

	if new_game_btn:
		new_game_btn.text = "NEW OPERATION"
		new_game_btn.pressed.connect(_on_new_game)

	if continue_btn:
		continue_btn.text = "CONTINUE"
		continue_btn.pressed.connect(_on_continue)
		continue_btn.visible = SaveManager.has_save()

	if quit_btn:
		quit_btn.text = "DISCONNECT"
		quit_btn.pressed.connect(_on_quit)

	# Start transmission cycle
	_cycle_transmissions()


func _process(delta: float) -> void:
	# Glitch effect on title
	glitch_timer += delta
	if title_label and fmod(glitch_timer, 3.0) < 0.1:
		title_label.position.x = randf_range(-2, 2)
	else:
		if title_label:
			title_label.position.x = 0


func _cycle_transmissions() -> void:
	while is_inside_tree():
		if transmission_label:
			var msg = transmissions[randi() % transmissions.size()]
			transmission_label.text = ""
			# Typewriter effect
			for i in range(msg.length()):
				if not is_inside_tree():
					return
				transmission_label.text += msg[i]
				await get_tree().create_timer(0.03).timeout
			await get_tree().create_timer(2.0).timeout


func _on_new_game() -> void:
	# Start from the beginning
	SaveManager.delete_save()
	GameManager.current_level = DEFAULT_LEVEL_ID
	GameManager.player_health = GameManager.player_max_health
	_change_to_level(DEFAULT_LEVEL_ID)


func _on_continue() -> void:
	if SaveManager.load_game():
		var level = GameManager.current_level
		if not _change_to_level(level):
			GameManager.current_level = DEFAULT_LEVEL_ID
			_change_to_level(DEFAULT_LEVEL_ID)


func _on_quit() -> void:
	get_tree().quit()


func _change_to_level(level_id: String) -> bool:
	var scene_path = "res://scenes/levels/%s.tscn" % level_id
	if not ResourceLoader.exists(scene_path):
		push_error("Missing level scene: %s" % scene_path)
		return false

	get_tree().change_scene_to_file(scene_path)
	return true
