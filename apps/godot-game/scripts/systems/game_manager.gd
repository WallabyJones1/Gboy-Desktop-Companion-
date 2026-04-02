extends Node

## GBOY: Escape from MITER - Game Manager
## Manages global game state, abilities, and progression
## Based on Neuko lore: G*Boy (G304) escaping MITER-Corp

# === SIGNALS ===
signal ability_unlocked(ability_name: String)
signal health_changed(current: int, max_hp: int)
signal psi_energy_changed(current: float, max_psi: float)
signal badge_collected(badge_type: String)
signal lore_fragment_found(fragment_id: String)
signal game_over
signal checkpoint_reached(checkpoint_id: String)

# === PLAYER STATE ===
var player_max_health: int = 5
var player_health: int = 5
var psi_energy: float = 100.0
var psi_max_energy: float = 100.0
var psi_regen_rate: float = 15.0  # per second

# === ABILITIES (unlocked through progression) ===
var abilities: Dictionary = {
	"double_jump": false,     # Unlocked in MITER Lab
	"wall_slide": false,      # Unlocked in Ventilation Shafts
	"dash": false,            # Unlocked in City Ruins
	"psi_blast": false,       # Unlocked in Psionic Chamber
	"telekinesis": false,     # Unlocked in Underground Network
	"mind_shield": false,     # Unlocked in Hive Nexus
	"phase_shift": false,     # Final ability - MITER Core
}

# === COLLECTIBLES ===
var badges_collected: Dictionary = {
	"rabbit": 0,   # Phase 1 badges (exploration)
	"moth": 0,     # Phase 2 badges (combat)
	"snake": 0,    # Phase 3 badges (stealth)
}
var lore_fragments: Array[String] = []
var total_lore_fragments: int = 30

# === PROGRESSION ===
var current_level: String = "miter_lab_01"
var visited_rooms: Array[String] = []
var defeated_bosses: Array[String] = []
var checkpoint_id: String = ""
var play_time: float = 0.0

# === GAME FLAGS ===
var is_paused: bool = false
var is_cutscene: bool = false
var difficulty: int = 1  # 0=easy, 1=normal, 2=hard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not is_paused and not is_cutscene:
		play_time += delta
		# Regenerate psi energy
		if psi_energy < psi_max_energy:
			psi_energy = min(psi_energy + psi_regen_rate * delta, psi_max_energy)
			psi_energy_changed.emit(psi_energy, psi_max_energy)


func take_damage(amount: int) -> void:
	if abilities.get("mind_shield", false) and psi_energy >= 20.0:
		# Mind shield absorbs some damage
		psi_energy -= 20.0
		amount = max(amount - 1, 0)
		psi_energy_changed.emit(psi_energy, psi_max_energy)

	player_health = max(player_health - amount, 0)
	health_changed.emit(player_health, player_max_health)

	if player_health <= 0:
		game_over.emit()


func heal(amount: int) -> void:
	player_health = min(player_health + amount, player_max_health)
	health_changed.emit(player_health, player_max_health)


func use_psi_energy(amount: float) -> bool:
	if psi_energy >= amount:
		psi_energy -= amount
		psi_energy_changed.emit(psi_energy, psi_max_energy)
		return true
	return false


func unlock_ability(ability_name: String) -> void:
	if abilities.has(ability_name):
		abilities[ability_name] = true
		ability_unlocked.emit(ability_name)
		print("[GBOY] Ability unlocked: ", ability_name)


func has_ability(ability_name: String) -> bool:
	return abilities.get(ability_name, false)


func collect_badge(badge_type: String) -> void:
	if badges_collected.has(badge_type):
		badges_collected[badge_type] += 1
		badge_collected.emit(badge_type)


func find_lore_fragment(fragment_id: String) -> void:
	if fragment_id not in lore_fragments:
		lore_fragments.append(fragment_id)
		lore_fragment_found.emit(fragment_id)


func visit_room(room_id: String) -> void:
	if room_id not in visited_rooms:
		visited_rooms.append(room_id)


func defeat_boss(boss_id: String) -> void:
	if boss_id not in defeated_bosses:
		defeated_bosses.append(boss_id)


func set_checkpoint(cp_id: String) -> void:
	checkpoint_id = cp_id
	checkpoint_reached.emit(cp_id)
	SaveManager.save_game()


func change_level(level_path: String) -> void:
	TransitionManager.transition_to(level_path)


func reset_for_death() -> void:
	player_health = player_max_health
	psi_energy = psi_max_energy
	health_changed.emit(player_health, player_max_health)
	psi_energy_changed.emit(psi_energy, psi_max_energy)


func get_save_data() -> Dictionary:
	return {
		"health": player_health,
		"max_health": player_max_health,
		"psi_energy": psi_energy,
		"abilities": abilities.duplicate(),
		"badges": badges_collected.duplicate(),
		"lore_fragments": lore_fragments.duplicate(),
		"current_level": current_level,
		"visited_rooms": visited_rooms.duplicate(),
		"defeated_bosses": defeated_bosses.duplicate(),
		"checkpoint_id": checkpoint_id,
		"play_time": play_time,
	}


func load_save_data(data: Dictionary) -> void:
	player_health = data.get("health", 5)
	player_max_health = data.get("max_health", 5)
	psi_energy = data.get("psi_energy", 100.0)
	abilities = data.get("abilities", abilities)
	badges_collected = data.get("badges", badges_collected)
	lore_fragments = data.get("lore_fragments", [])
	current_level = data.get("current_level", "miter_lab_01")
	visited_rooms = data.get("visited_rooms", [])
	defeated_bosses = data.get("defeated_bosses", [])
	checkpoint_id = data.get("checkpoint_id", "")
	play_time = data.get("play_time", 0.0)
