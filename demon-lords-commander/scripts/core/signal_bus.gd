extends Node

# Core cross-system game signals.
signal new_game_requested
signal continue_requested
signal options_requested
signal quit_requested

# Requests (intent) - UI and gameplay systems ask for state transitions through these.
signal scene_change_requested(target_scene: String)
signal phase_change_requested(target_phase: StringName)
signal mission_selected(mission_id: StringName, deck_id: StringName, main_waifu_id: StringName, backup_waifu_ids: Array[StringName])
signal battle_start_requested(battle_id: String, payload: Dictionary)
signal battle_setup_ready(payload: Dictionary)
signal battle_setup_failed(reason: String)
signal dialogue_start_requested(dialogue_id: String, payload: Dictionary)
signal victory_screen_requested()
signal return_to_title_requested()

# Broadcasts (facts) - authoritative systems publish completed outcomes through these.
signal game_bootstrap_complete
signal game_state_changed(snapshot: Dictionary)
signal battle_ended(victory: bool, rewards: Dictionary)


func request_new_game() -> void:
	new_game_requested.emit()


func request_continue() -> void:
	continue_requested.emit()


func request_options() -> void:
	options_requested.emit()


func request_quit() -> void:
	quit_requested.emit()


func request_scene_change(target_scene: String) -> void:
	scene_change_requested.emit(target_scene)


func request_phase_change(target_phase: StringName) -> void:
	phase_change_requested.emit(target_phase)


func select_mission(mission_id: StringName, deck_id: StringName, main_waifu_id: StringName, backup_waifu_ids: Array[StringName]) -> void:
	mission_selected.emit(mission_id, deck_id, main_waifu_id, backup_waifu_ids)


func request_battle_start(battle_id: String, payload: Dictionary = {}) -> void:
	battle_start_requested.emit(battle_id, payload)


func broadcast_battle_setup_ready(payload: Dictionary) -> void:
	battle_setup_ready.emit(payload)


func broadcast_battle_setup_failed(reason: String) -> void:
	battle_setup_failed.emit(reason)


func request_dialogue_start(dialogue_id: String, payload: Dictionary = {}) -> void:
	dialogue_start_requested.emit(dialogue_id, payload)


func request_victory_screen() -> void:
	victory_screen_requested.emit()


func request_return_to_title() -> void:
	return_to_title_requested.emit()


func broadcast_bootstrap_complete() -> void:
	game_bootstrap_complete.emit()


func broadcast_game_state_changed(snapshot: Dictionary) -> void:
	game_state_changed.emit(snapshot)


func broadcast_battle_ended(victory: bool, rewards: Dictionary = {}) -> void:
	battle_ended.emit(victory, rewards)
