extends CanvasLayer
class_name HUD

## In-game HUD showing health, psi energy, badges, and ability icons

@onready var health_container: HBoxContainer = $MarginContainer/VBoxContainer/HealthContainer
@onready var psi_bar: ProgressBar = $MarginContainer/VBoxContainer/PsiBar
@onready var badge_label: Label = $MarginContainer/VBoxContainer/BadgeLabel
@onready var ability_container: HBoxContainer = $TopRight/AbilityContainer
@onready var lore_popup: PanelContainer = $LorePopup
@onready var lore_label: Label = $LorePopup/LoreLabel

var heart_full_color: Color = Color(0.85, 0.12, 0.08)
var heart_empty_color: Color = Color(0.3, 0.15, 0.15)


func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.psi_energy_changed.connect(_on_psi_changed)
	GameManager.badge_collected.connect(_on_badge_collected)
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	GameManager.lore_fragment_found.connect(_on_lore_found)

	_update_health_display(GameManager.player_health, GameManager.player_max_health)
	_update_psi_display(GameManager.psi_energy, GameManager.psi_max_energy)
	_update_badge_display()

	if lore_popup:
		lore_popup.visible = false


func _on_health_changed(current: int, max_hp: int) -> void:
	_update_health_display(current, max_hp)


func _on_psi_changed(current: float, max_psi: float) -> void:
	_update_psi_display(current, max_psi)


func _on_badge_collected(_badge_type: String) -> void:
	_update_badge_display()


func _on_ability_unlocked(ability_name: String) -> void:
	_show_ability_unlock(ability_name)


func _on_lore_found(fragment_id: String) -> void:
	_show_lore_popup(fragment_id)


func _update_health_display(current: int, max_hp: int) -> void:
	# Create heart icons
	for child in health_container.get_children():
		child.queue_free()

	for i in range(max_hp):
		var heart = ColorRect.new()
		heart.custom_minimum_size = Vector2(10, 10)
		heart.color = heart_full_color if i < current else heart_empty_color
		health_container.add_child(heart)


func _update_psi_display(current: float, max_psi: float) -> void:
	if psi_bar:
		psi_bar.value = (current / max_psi) * 100.0


func _update_badge_display() -> void:
	if badge_label:
		var b = GameManager.badges_collected
		badge_label.text = "R:%d M:%d S:%d" % [b.rabbit, b.moth, b.snake]


func _show_ability_unlock(ability_name: String) -> void:
	var names = {
		"double_jump": "DOUBLE JUMP",
		"wall_slide": "WALL CLING",
		"dash": "PHASE DASH",
		"psi_blast": "PSI BLAST",
		"telekinesis": "TELEKINESIS",
		"mind_shield": "MIND SHIELD",
		"phase_shift": "PHASE SHIFT",
	}
	var display_name = names.get(ability_name, ability_name.to_upper())

	if lore_popup and lore_label:
		lore_label.text = ">> ABILITY ACQUIRED: %s <<" % display_name
		lore_popup.visible = true
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(lore_popup):
			lore_popup.visible = false


func _show_lore_popup(fragment_id: String) -> void:
	if lore_popup and lore_label:
		lore_label.text = "MITER LOG RECOVERED: %s" % fragment_id
		lore_popup.visible = true
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(lore_popup):
			lore_popup.visible = false
