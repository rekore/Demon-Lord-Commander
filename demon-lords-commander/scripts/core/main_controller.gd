extends Control

const TITLE_SCENE: PackedScene = preload("res://scenes/TitleScreen.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/BattleScene.tscn")
const VICTORY_SCENE: PackedScene = preload("res://scenes/VictoryScreen.tscn")

@onready var _scene_host: Control = $SceneHost

var _active_screen: Control


func _ready() -> void:
	SignalBus.quit_requested.connect(_on_quit_requested)
	SignalBus.battle_ended.connect(_on_battle_ended)
	SignalBus.battle_setup_ready.connect(_on_battle_setup_ready)
	SignalBus.battle_setup_failed.connect(_on_battle_setup_failed)
	SignalBus.victory_screen_requested.connect(_on_victory_screen_requested)
	SignalBus.return_to_title_requested.connect(_on_return_to_title_requested)
	GameState.phase_changed.connect(_on_phase_changed)

	_show_title()
	SignalBus.broadcast_bootstrap_complete()


func _on_phase_changed(_previous_phase: StringName, new_phase: StringName) -> void:
	match new_phase:
		GameState.PHASE_TITLE:
			_show_title()
		GameState.PHASE_HUB:
			SignalBus.request_battle_start("tutorial_battle")
		GameState.PHASE_BATTLE:
			_show_battle()


func _show_title() -> void:
	_set_screen(TITLE_SCENE.instantiate() as Control)


func _show_battle() -> void:
	_set_screen(BATTLE_SCENE.instantiate() as Control)


func _show_victory() -> void:
	_set_screen(VICTORY_SCENE.instantiate() as Control)


func _set_screen(next_screen: Control) -> void:
	if _active_screen != null:
		_active_screen.queue_free()

	_active_screen = next_screen
	_scene_host.add_child(_active_screen)
	_active_screen.anchor_right = 1.0
	_active_screen.anchor_bottom = 1.0
	_active_screen.offset_left = 0.0
	_active_screen.offset_top = 0.0
	_active_screen.offset_right = 0.0
	_active_screen.offset_bottom = 0.0


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_battle_ended(victory: bool, _rewards: Dictionary) -> void:
	# Victory screen is now requested from battle_controller, so we don't auto-return to title here
	# This handler is kept for other systems that might need battle end notifications
	pass


func _on_victory_screen_requested() -> void:
	_show_victory()


func _on_return_to_title_requested() -> void:
	GameState.set_phase(GameState.PHASE_TITLE)


func _on_battle_setup_ready(_payload: Dictionary) -> void:
	GameState.set_phase(GameState.PHASE_BATTLE)


func _on_battle_setup_failed(reason: String) -> void:
	push_warning("Battle setup failed: %s" % reason)
	GameState.set_phase(GameState.PHASE_TITLE)
