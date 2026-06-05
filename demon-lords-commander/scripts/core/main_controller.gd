extends Control

const TITLE_SCENE: PackedScene = preload("res://scenes/TitleScreen.tscn")
const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/WorldMap.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/BattleScene.tscn")
const VICTORY_SCENE: PackedScene = preload("res://scenes/VictoryScreen.tscn")
const RELIC_SHOP_SCENE: PackedScene = preload("res://scenes/RelicShopScreen.tscn")
const DUNGEON_CHOICE_SCENE: PackedScene = preload("res://scenes/DungeonChoiceScreen.tscn")
const BATTLE_VICTORY_SCENE: PackedScene = preload("res://scenes/BattleVictoryScreen.tscn")

@onready var _scene_host: Control = $SceneHost

var _active_screen: Control


func _ready() -> void:
	SignalBus.quit_requested.connect(_on_quit_requested)
	SignalBus.dialogue_start_requested.connect(_on_dialogue_start_requested)
	SignalBus.relic_shop_open_requested.connect(_on_relic_shop_open_requested)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	SignalBus.battle_ended.connect(_on_battle_ended)
	SignalBus.battle_setup_ready.connect(_on_battle_setup_ready)
	SignalBus.battle_setup_failed.connect(_on_battle_setup_failed)
	SignalBus.victory_screen_requested.connect(_on_victory_screen_requested)
	SignalBus.return_to_title_requested.connect(_on_return_to_title_requested)
	SignalBus.dungeon_run_requested.connect(_on_dungeon_run_requested)
	SignalBus.dungeon_choices_ready.connect(_on_dungeon_choices_ready)
	SignalBus.dungeon_node_selected.connect(_on_dungeon_node_selected)
	SignalBus.dungeon_run_completed.connect(_on_dungeon_run_completed)
	SignalBus.dungeon_run_failed.connect(_on_dungeon_run_failed)
	SignalBus.dungeon_rewards_claimed.connect(_on_dungeon_rewards_claimed)
	GameState.phase_changed.connect(_on_phase_changed)

	_show_title()
	SignalBus.broadcast_bootstrap_complete()


func _on_phase_changed(_previous_phase: StringName, new_phase: StringName) -> void:
	match new_phase:
		GameState.PHASE_TITLE:
			_show_title()
		GameState.PHASE_HUB:
			_show_world_map()
		GameState.PHASE_BATTLE:
			_show_battle()


func _show_title() -> void:
	_set_screen(TITLE_SCENE.instantiate() as Control)


func _show_world_map() -> void:
	_set_screen(WORLD_MAP_SCENE.instantiate() as Control)


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
	var node: Dictionary = {}
	if DungeonService.is_run_active():
		var run: Dictionary = DungeonService.get_current_run()
		node = run.get("pending_node", {})
	var loot: Dictionary = DungeonService.generate_battle_loot(node)
	_show_battle_victory(loot)


func _show_battle_victory(loot: Dictionary) -> void:
	var screen: Control = BATTLE_VICTORY_SCENE.instantiate() as Control
	_set_screen(screen)
	if screen.has_method("set_loot"):
		screen.set_loot(loot)


func _on_dungeon_rewards_claimed() -> void:
	if DungeonService.is_run_active():
		DungeonService.complete_node()
	else:
		GameState.set_phase(GameState.PHASE_HUB)


func _on_return_to_title_requested() -> void:
	if DungeonService.is_run_active():
		DungeonService.fail_run()
		# fail_run emits dungeon_run_failed -> _on_dungeon_run_failed -> sets PHASE_HUB
	else:
		GameState.set_phase(GameState.PHASE_TITLE)


func _on_battle_setup_ready(_payload: Dictionary) -> void:
	GameState.set_phase(GameState.PHASE_BATTLE)


func _on_battle_setup_failed(reason: String) -> void:
	push_warning("Battle setup failed: %s" % reason)
	GameState.set_phase(GameState.PHASE_TITLE)


func _on_relic_shop_open_requested() -> void:
	var shop: Control = RELIC_SHOP_SCENE.instantiate() as Control
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene_host.add_child(shop)


func _on_dialogue_start_requested(dialogue_id: String, _payload: Dictionary) -> void:
	Dialogic.start(dialogue_id)


func _on_dungeon_run_requested(dungeon_id: String) -> void:
	DungeonService.start_run(dungeon_id)


func _on_dungeon_choices_ready(choices: Array) -> void:
	var screen: Control = DUNGEON_CHOICE_SCENE.instantiate() as Control
	_set_screen(screen)
	if screen.has_method("set_choices"):
		screen.set_choices(choices)


func _on_dungeon_node_selected(node_data: Dictionary) -> void:
	var node_type: String = String(node_data.get("type", ""))
	match node_type:
		"battle_normal", "battle_elite", "battle_boss":
			var enemy_id: String = String(node_data.get("enemy_id", ""))
			var dungeon_level: int = int(node_data.get("dungeon_level", 1))
			SignalBus.request_battle_start(enemy_id, {
				"enemy_id": enemy_id,
				"dungeon_level": dungeon_level
			})
		"rest":
			# TODO: show rest screen (HP recovery), then complete_node on dismiss
			DungeonService.complete_node()
		"event":
			# TODO: show event screen, then complete_node on dismiss
			DungeonService.complete_node()
		"bond":
			# TODO: trigger Dialogic bond scene for selected waifu, then complete_node on scene end
			DungeonService.complete_node()


func _on_dungeon_run_completed(_dungeon_id: String) -> void:
	_show_victory()


func _on_dungeon_run_failed(_dungeon_id: String) -> void:
	GameState.set_phase(GameState.PHASE_HUB)


func _on_dialogic_signal(value: String) -> void:
	match value:
		"open_relic_shop":
			SignalBus.request_relic_shop_open()
		"start_dungeon_catacombs":
			SignalBus.request_dungeon_run("dungeon_catacombs")
