extends RefCounted

# Small explicit battle phase machine.
# It documents and enforces the intended flow:
# round_start -> player_turn -> enemy_turn -> end_check -> round_start

const PHASE_ROUND_START: StringName = &"round_start"
const PHASE_PLAYER_TURN: StringName = &"player_turn"
const PHASE_ENEMY_TURN: StringName = &"enemy_turn"
const PHASE_END_CHECK: StringName = &"end_check"
const PHASE_BATTLE_OVER: StringName = &"battle_over"
const PHASE_SEARCHING: StringName = &"searching"

var _phase: StringName = PHASE_ROUND_START


func reset_for_new_battle() -> void:
	_phase = PHASE_ROUND_START


func enter_round_start() -> void:
	_phase = PHASE_ROUND_START


func enter_player_turn() -> void:
	_phase = PHASE_PLAYER_TURN


func enter_enemy_turn() -> void:
	_phase = PHASE_ENEMY_TURN


func enter_end_check() -> void:
	_phase = PHASE_END_CHECK


func enter_battle_over() -> void:
	_phase = PHASE_BATTLE_OVER


func enter_searching() -> void:
	_phase = PHASE_SEARCHING


func can_play_cards() -> bool:
	return _phase == PHASE_PLAYER_TURN


func can_end_turn() -> bool:
	return _phase == PHASE_PLAYER_TURN


func is_searching() -> bool:
	return _phase == PHASE_SEARCHING


func current_phase() -> StringName:
	return _phase
