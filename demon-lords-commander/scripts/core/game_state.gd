extends Node

# The phase model keeps high-level flow explicit and easy to debug.
const PHASE_BOOT: StringName = &"boot"
const PHASE_TITLE: StringName = &"title"
const PHASE_HUB: StringName = &"hub"
const PHASE_MISSION: StringName = &"mission"
const PHASE_BATTLE: StringName = &"battle"
const PHASE_PAUSED: StringName = &"paused"

signal state_reset
signal phase_changed(previous_phase: StringName, new_phase: StringName)
signal mission_progress_changed(current_battle_index: int, total_battles: int)
signal player_stats_changed(current_hp: int, max_hp: int, current_mana: int, base_mana: int)

var run_seed: int = 0
var current_phase: StringName = PHASE_BOOT

var player: Dictionary = {
	"id": "player",
	"current_hp": 100,
	"max_hp": 100,
	"current_mana": 3,
	"base_mana": 3
}

var mission: Dictionary = {
	"id": &"",
	"current_battle_index": 0,
	"total_battles": 0,
	"main_waifu_id": &"",
	"backup_waifu_ids": [],
	"selected_deck_id": &""
}


func _ready() -> void:
	SignalBus.new_game_requested.connect(_on_new_game_requested)
	SignalBus.continue_requested.connect(_on_continue_requested)
	SignalBus.phase_change_requested.connect(_on_phase_change_requested)
	SignalBus.mission_selected.connect(_on_mission_selected)

	# Start from a known clean baseline for deterministic boot behavior.
	new_campaign()
	set_phase(PHASE_TITLE)


func new_campaign(run_seed_value: int = -1) -> void:
	run_seed = run_seed_value if run_seed_value >= 0 else randi()
	player = {
		"id": "player",
		"current_hp": 100,
		"max_hp": 100,
		"current_mana": 3,
		"base_mana": 3
	}
	mission = {
		"id": &"",
		"current_battle_index": 0,
		"total_battles": 0,
		"main_waifu_id": &"",
		"backup_waifu_ids": [],
		"selected_deck_id": &""
	}

	state_reset.emit()
	emit_player_stats_changed()
	mission_progress_changed.emit(0, 0)
	SignalBus.broadcast_game_state_changed(get_snapshot())


func set_phase(next_phase: StringName) -> void:
	if current_phase == next_phase:
		return

	var previous_phase: StringName = current_phase
	current_phase = next_phase
	phase_changed.emit(previous_phase, current_phase)
	SignalBus.broadcast_game_state_changed(get_snapshot())


func start_mission(mission_id: StringName, deck_id: StringName, main_waifu_id: StringName, backup_waifu_ids: Array[StringName], total_battles: int) -> void:
	mission["id"] = mission_id
	mission["current_battle_index"] = 0
	mission["total_battles"] = max(total_battles, 0)
	mission["main_waifu_id"] = main_waifu_id
	mission["backup_waifu_ids"] = backup_waifu_ids.duplicate()
	mission["selected_deck_id"] = deck_id

	set_phase(PHASE_MISSION)
	mission_progress_changed.emit(mission["current_battle_index"], mission["total_battles"])
	SignalBus.broadcast_game_state_changed(get_snapshot())


func advance_mission_battle() -> void:
	var next_index: int = int(mission["current_battle_index"]) + 1
	var total_battles: int = int(mission["total_battles"])
	mission["current_battle_index"] = clampi(next_index, 0, total_battles)
	mission_progress_changed.emit(mission["current_battle_index"], total_battles)
	SignalBus.broadcast_game_state_changed(get_snapshot())


func set_player_combat_stats(current_hp: int, max_hp: int, current_mana: int, base_mana: int) -> void:
	player["current_hp"] = max(current_hp, 0)
	player["max_hp"] = max(max_hp, 1)
	player["current_mana"] = max(current_mana, 0)
	player["base_mana"] = max(base_mana, 0)
	emit_player_stats_changed()
	SignalBus.broadcast_game_state_changed(get_snapshot())


func get_snapshot() -> Dictionary:
	return {
		"run_seed": run_seed,
		"current_phase": current_phase,
		"player": player.duplicate(true),
		"mission": mission.duplicate(true)
	}


func emit_player_stats_changed() -> void:
	player_stats_changed.emit(
		int(player["current_hp"]),
		int(player["max_hp"]),
		int(player["current_mana"]),
		int(player["base_mana"])
	)


func _on_new_game_requested() -> void:
	new_campaign()
	# If we were already in HUB (for example after an interrupted setup flow),
	# force a phase edge so MainController reliably re-triggers battle setup.
	if current_phase == PHASE_HUB:
		set_phase(PHASE_TITLE)
	set_phase(PHASE_HUB)


func _on_continue_requested() -> void:
	# Save/load system is not implemented yet; this keeps the flow functional for now.
	if current_phase == PHASE_HUB:
		set_phase(PHASE_TITLE)
	set_phase(PHASE_HUB)


func _on_phase_change_requested(target_phase: StringName) -> void:
	set_phase(target_phase)


func _on_mission_selected(mission_id: StringName, deck_id: StringName, main_waifu_id: StringName, backup_waifu_ids: Array[StringName]) -> void:
	# Default mission length can be replaced by mission data later.
	start_mission(mission_id, deck_id, main_waifu_id, backup_waifu_ids, 3)
