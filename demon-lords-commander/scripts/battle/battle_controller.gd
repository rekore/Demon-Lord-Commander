extends Control

const MAX_HAND_SIZE: int = 10
const STARTING_DRAW: int = 5
const DEFAULT_PILE_ART_PATH: String = "res://assets/art/ui/icons/cascade_orb.png"
const DEFAULT_SIDE_WAIFU_ART_PATH: String = "res://assets/art/characters/sidewaifutest.png"
const TurnManagerScript = preload("res://scripts/battle/turn_manager.gd")
const EffectResolverScript = preload("res://scripts/battle/effect_resolver.gd")
const EnemyAIScript = preload("res://scripts/battle/enemy_ai.gd")
const BattleStateMachineScript = preload("res://scripts/battle/battle_state_machine.gd")
const CardPlayServiceScript = preload("res://scripts/battle/card_play_service.gd")
const CardUIScript = preload("res://scripts/battle/card_ui.gd")
const CardUIScene = preload("res://scenes/Card.tscn")

@onready var _main_waifu_header_portrait: TextureRect = $Margin/RootVBox/PersistentHeaderRow/PersistentBox1/MainWaifuPortraitRect
@onready var _side_waifu_1_portrait: TextureRect = $Margin/RootVBox/PersistentHeaderRow/PersistentBox2/SideWaifu1PortraitRect
@onready var _side_waifu_2_portrait: TextureRect = $Margin/RootVBox/PersistentHeaderRow/PersistentBox3/SideWaifu2PortraitRect

@onready var _main_waifu_portrait: AnimatedSprite2D = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/MainWaifuCard/Portrait
@onready var _main_waifu_stats_label: Label = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/MainWaifuCard/StatsLabel
@onready var _left_spacer: Control = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/LeftSpacer
@onready var _right_spacer: Control = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/RightSpacer
@onready var _main_waifu_card: Control = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/MainWaifuCard

@onready var _summon_1_card: Control = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/Summon1Card
@onready var _summon_1_stats_label: Label = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/Summon1Card/StatsLabel
@onready var _summon_2_card: Control = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/Summon2Card
@onready var _summon_2_stats_label: Label = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/Summon2Card/StatsLabel
@onready var _summon_3_card: Control = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/Summon3Card
@onready var _summon_3_stats_label: Label = $Margin/RootVBox/CombatRow/PlayerGroupPanel/PlayerGroupVBox/PlayerCardsRow/Summon3Card/StatsLabel

var _enemy_cards: Array[Control] = []
var _enemy_stats_labels: Array[Label] = []
var _enemy_intent_labels: Array[Label] = []

@onready var _enemy_cards_row: HBoxContainer = $Margin/RootVBox/CombatRow/EnemyGroupPanel/EnemyGroupVBox/EnemyCardsRow
@onready var _enemy_left_spacer: Control = $Margin/RootVBox/CombatRow/EnemyGroupPanel/EnemyGroupVBox/EnemyCardsRow/LeftSpacer
@onready var _enemy_right_spacer: Control = $Margin/RootVBox/CombatRow/EnemyGroupPanel/EnemyGroupVBox/EnemyCardsRow/RightSpacer

@onready var _draw_pile_art: TextureRect = $Margin/RootVBox/HandHudRow/DrawPilePanel/DrawPileArt
@onready var _draw_pile_count_label: Label = $Margin/RootVBox/HandHudRow/DrawPilePanel/DrawPileCountLabel
@onready var _mana_label: Label = $Margin/RootVBox/HandHudRow/ManaPanel/ManaLabel
@onready var _hand_container: Control = $Margin/RootVBox/HandHudRow/HandPanel/HandCards
@onready var _discard_pile_art: TextureRect = $Margin/RootVBox/HandHudRow/DiscardPilePanel/DiscardPileArt
@onready var _discard_pile_count_label: Label = $Margin/RootVBox/HandHudRow/DiscardPilePanel/DiscardPileCountLabel
@onready var _end_turn_button: Button = $Margin/RootVBox/HandHudRow/EndTurnButton

@onready var _consumable_rect_1: TextureRect = $Margin/RootVBox/PersistentHeaderRow/ConsumableSlot1/ConsumableRect1
@onready var _consumable_rect_2: TextureRect = $Margin/RootVBox/PersistentHeaderRow/ConsumableSlot2/ConsumableRect2
@onready var _consumable_rect_3: TextureRect = $Margin/RootVBox/PersistentHeaderRow/ConsumableSlot3/ConsumableRect3
@onready var _battle_info_label: Label = $Margin/RootVBox/PersistentHeaderRow/BattleInfoPanel/BattleInfoLabel
@onready var _deck_view_button: TextureButton = $Margin/RootVBox/PersistentHeaderRow/DeckViewButton
@onready var _deck_overlay: Control = $DeckOverlay
@onready var _deck_title_label: Label = $DeckOverlay/DeckPanel/DeckVBox/DeckHeader/DeckTitleLabel
@onready var _deck_close_button: Button = $DeckOverlay/DeckPanel/DeckVBox/DeckHeader/DeckCloseButton
@onready var _deck_card_grid: HFlowContainer = $DeckOverlay/DeckPanel/DeckVBox/DeckScrollContainer/DeckCardGrid

var _battle_over: bool = false
var _round_number: int = 1
var _battle_elapsed_time: float = 0.0

var _selected_waifu_id: String = ""
var _selected_waifu_name: String = "Unknown"
var _selected_waifu_bond: int = 1
var _selected_sub_waifu_id: String = ""
var _selected_sub_waifu_name: String = "Unknown"
var _waifu_scaled_effects: Array[Dictionary] = []
var _active_summon_count: int = 0

var _player_state: Dictionary = {}
var _enemy_states: Array[Dictionary] = []

var _draw_pile: Array[Dictionary] = []
var _hand: Array[Dictionary] = []
var _discard_pile: Array[Dictionary] = []
var _exhaust_pile: Array[Dictionary] = []
var _full_deck: Array[Dictionary] = []
var _turn_manager: RefCounted = TurnManagerScript.new()
var _effect_resolver: RefCounted = EffectResolverScript.new()
var _enemy_ai: RefCounted = EnemyAIScript.new()
var _battle_state_machine: RefCounted = BattleStateMachineScript.new()
var _card_play_service: RefCounted = CardPlayServiceScript.new()

# Drag-and-drop state
var _drag_card_ui: Control = null
var _drag_card_id: String = ""
var _drag_card_data: Dictionary = {}
var _drag_original_parent: Node = null
var _drag_original_index: int = -1
var _drag_active: bool = false
const DRAG_LIFT_SCALE: float = 1.1
const DRAG_THRESHOLD_PX: float = 100.0

func _ready() -> void:
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_hand_container.resized.connect(_arrange_hand_cards)
	_deck_view_button.pressed.connect(_open_deck_overlay)
	_deck_close_button.pressed.connect(_close_deck_overlay)
	_populate_enemy_ui_arrays()
	_initialize_battle()


func _process(delta: float) -> void:
	if not _battle_over:
		_battle_elapsed_time += delta
	if not _drag_active or _drag_card_ui == null:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_card_drag()
		return
	_drag_card_ui.global_position = get_global_mouse_position() - _drag_card_ui.size / 2.0
	_highlight_hovered_enemy()


func _populate_enemy_ui_arrays() -> void:
	var card_names: Array[String] = ["EnemyCard", "EnemyCard2", "EnemyCard3", "EnemyCard4"]
	for card_name: String in card_names:
		var card: Control = _enemy_cards_row.get_node(card_name)
		_enemy_cards.append(card)
		_enemy_stats_labels.append(card.get_node("InfoVBox/StatsLabel") as Label)
		_enemy_intent_labels.append(card.get_node("InfoVBox/IntentLabel") as Label)


func _is_card_targeted(card_data: Dictionary) -> bool:
	return String(card_data.get("type", "")) == "attack" or int(card_data.get("damage", 0)) > 0


func _start_card_drag(card_ui: Control) -> void:
	if _battle_over or not _battle_state_machine.can_play_cards():
		return
	var card_id: String = String(card_ui.get_meta("card_id", ""))
	if card_id == "":
		return
	var card_data: Dictionary = card_ui.get_meta("card_data", {}) as Dictionary
	if int(card_data.get("cost", 0)) > int(_player_state.get("mana", 0)):
		return

	_drag_card_ui = card_ui
	_drag_card_id = card_id
	_drag_card_data = card_data
	_drag_original_parent = card_ui.get_parent()
	_drag_original_index = card_ui.get_index()
	_drag_active = true

	# Reparent to root so it can move freely
	var global_pos: Vector2 = card_ui.global_position
	_drag_original_parent.remove_child(card_ui)
	add_child(card_ui)
	card_ui.global_position = global_pos
	card_ui.z_index = 10
	card_ui.scale = Vector2(DRAG_LIFT_SCALE, DRAG_LIFT_SCALE)
	_arrange_hand_cards()


func _end_card_drag() -> void:
	if not _drag_active or _drag_card_ui == null:
		return

	var target_index: int = -1
	var should_play: bool = false

	if _is_card_targeted(_drag_card_data):
		target_index = _find_enemy_drop_target()
		should_play = target_index >= 0
	else:
		# Non-target card: play when card center clears the top of the hand container
		var hand_top: float = _hand_container.global_position.y
		var card_bottom: float = _drag_card_ui.global_position.y + _drag_card_ui.size.y
		var threshold: float = hand_top + _drag_card_ui.size.y * 0.5
		should_play = card_bottom < threshold

	if should_play:
		_play_dragged_card(target_index)
	else:
		_snap_card_back()

	# Clear highlights
	for enemy_card: Control in _enemy_cards:
		enemy_card.modulate = Color.WHITE


func _find_enemy_drop_target() -> int:
	var mouse_pos: Vector2 = get_global_mouse_position()
	for i: int in range(_enemy_cards.size()):
		var enemy_card: Control = _enemy_cards[i]
		if not enemy_card.visible:
			continue
		if i < _enemy_states.size() and int(_enemy_states[i].get("hp", 0)) <= 0:
			continue
		var rect: Rect2 = Rect2(enemy_card.global_position, enemy_card.size)
		if rect.has_point(mouse_pos):
			return i
	return -1


func _highlight_hovered_enemy() -> void:
	if not _is_card_targeted(_drag_card_data):
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	for i: int in range(_enemy_cards.size()):
		var enemy_card: Control = _enemy_cards[i]
		if not enemy_card.visible:
			enemy_card.modulate = Color.WHITE
			continue
		if i < _enemy_states.size() and int(_enemy_states[i].get("hp", 0)) <= 0:
			enemy_card.modulate = Color.WHITE
			continue
		var rect: Rect2 = Rect2(enemy_card.global_position, enemy_card.size)
		if rect.has_point(mouse_pos):
			enemy_card.modulate = Color.YELLOW
		else:
			enemy_card.modulate = Color.WHITE


func _play_dragged_card(target_enemy_index: int = -1) -> void:
	if _drag_card_ui == null:
		return
	var card_id: String = _drag_card_id
	_drag_card_ui.queue_free()
	_drag_card_ui = null
	_drag_active = false
	_play_card_by_id(card_id, target_enemy_index)


func _snap_card_back() -> void:
	if _drag_card_ui == null:
		return
	_drag_card_ui.scale = Vector2.ONE
	_drag_card_ui.z_index = 0
	var global_pos: Vector2 = _drag_card_ui.global_position
	remove_child(_drag_card_ui)
	_drag_original_parent.add_child(_drag_card_ui)
	_drag_card_ui.global_position = global_pos
	if _drag_original_index >= 0 and _drag_original_index < _drag_original_parent.get_child_count():
		_drag_original_parent.move_child(_drag_card_ui, _drag_original_index)
	_drag_card_ui = null
	_drag_active = false
	_arrange_hand_cards()


func _arrange_hand_cards() -> void:
	var cards: Array[Node] = _hand_container.get_children()
	var count: int = cards.size()
	if count == 0:
		return

	var container_width: float = _hand_container.size.x
	var container_height: float = _hand_container.size.y
	if container_width <= 0 or container_height <= 0:
		return

	var card_width: float = CardUIScript.BASE_WIDTH * CardUIScript.SCALE_HAND
	var card_height: float = CardUIScript.BASE_HEIGHT * CardUIScript.SCALE_HAND

	var max_rotation: float = 7.0
	# Inset the spread by the horizontal distance a card top travels when tilted,
	# so edge cards never spill over the adjacent mana/discard panels.
	var tilt_overhang: float = card_height * sin(deg_to_rad(max_rotation))
	var h_padding: float = tilt_overhang + 8.0
	var usable_width: float = container_width - h_padding * 2.0
	if usable_width <= card_width:
		usable_width = card_width

	var step: float
	if count == 1:
		step = 0.0
	else:
		step = (usable_width - card_width) / float(count - 1)
		# Cap maximum step so cards always overlap (hand always looks "held together")
		var max_step: float = card_width * 0.65
		if step > max_step:
			step = max_step
		# Clamp minimum step so cards don't collapse entirely (keep at least 20% visible)
		var min_step: float = card_width * 0.20
		if step < min_step:
			step = min_step

	var total_width: float = card_width + (count - 1) * step
	var start_x: float = h_padding + (usable_width - total_width) / 2.0
	var center_index: float = (count - 1) / 2.0
	var bottom_y: float = container_height + card_height * 0.15

	for i: int in range(count):
		var card: Control = cards[i] as Control
		if card == null:
			continue

		var dist_from_center: float = (i - center_index) / maxf(1.0, center_index)
		if count == 1:
			dist_from_center = 0.0

		# Horizontal position
		var x: float = start_x + i * step

		# Vertical: bottom aligned, center cards arc higher for natural hand curve
		var arc_lift: float = (1.0 - absf(dist_from_center)) * 70.0
		var y: float = bottom_y - card_height - arc_lift

		# Z-index: rightmost card on top, +5 per slot to prevent border-over-art bleed
		var base_z: int = i * 5
		card.z_index = base_z
		card.set_meta("base_z", base_z)

		card.position = Vector2(x, y)
		card.pivot_offset = Vector2(card_width / 2.0, card_height)
		card.rotation_degrees = dist_from_center * max_rotation
		card.scale = Vector2.ONE
		card.set_meta("base_pos", Vector2(x, y))


func _initialize_battle() -> void:
	_battle_over = false
	_round_number = 1
	_battle_elapsed_time = 0.0
	_battle_state_machine.reset_for_new_battle()

	var setup: Dictionary = BattleSetupService.current_setup
	if setup.is_empty():
		SignalBus.request_battle_start("fallback_battle")
		setup = BattleSetupService.current_setup

	_selected_waifu_id = String(setup.get("waifu_id", "waifu_nyx"))
	_selected_waifu_name = String(setup.get("waifu_name", _selected_waifu_id))
	_selected_waifu_bond = int(setup.get("waifu_bond", 1))
	_selected_sub_waifu_id = String(setup.get("sub_waifu_id", _selected_waifu_id))
	_selected_sub_waifu_name = String(setup.get("sub_waifu_name", _selected_sub_waifu_id))
	_waifu_scaled_effects = setup.get("waifu_effects", [])

	_player_state = {
		"max_hp": int(GameState.player["max_hp"]),
		"hp": int(GameState.player["current_hp"]),
		"base_mana": int(GameState.player["base_mana"]),
		"mana": int(GameState.player["base_mana"]),
		"block": 0
	}

	_enemy_states = _build_enemy_states(setup)
	_draw_pile = _build_deck_from_setup(setup)
	_full_deck = _draw_pile.duplicate(true)
	_draw_pile.shuffle()
	_hand.clear()
	_discard_pile.clear()
	_exhaust_pile.clear()

	_apply_waifu_art(setup)
	_start_player_round()


func _apply_waifu_art(setup: Dictionary) -> void:
	var main_portrait_path: String = String(setup.get("waifu_portrait_path", ""))
	var sub_portrait_path: String = String(setup.get("sub_waifu_portrait_path", ""))

	# Header row waifu portraits — fall back to DEFAULT_SIDE_WAIFU_ART_PATH if path is empty/invalid.
	_set_texture_with_fallback(_main_waifu_header_portrait, main_portrait_path, DEFAULT_SIDE_WAIFU_ART_PATH)
	_set_texture_with_fallback(_side_waifu_1_portrait, "", DEFAULT_SIDE_WAIFU_ART_PATH)
	_set_texture_with_fallback(_side_waifu_2_portrait, "", DEFAULT_SIDE_WAIFU_ART_PATH)

	# Pile art uses sub-waifu portrait when available; falls back to scene default (discardpile.png).
	if sub_portrait_path != "":
		_set_texture_if_valid(_draw_pile_art, sub_portrait_path)
		_set_texture_if_valid(_discard_pile_art, sub_portrait_path)


func _set_texture_with_fallback(target: TextureRect, texture_path: String, fallback_path: String) -> void:
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture: Texture2D = load(texture_path) as Texture2D
		if texture != null:
			target.texture = texture
			return
	if ResourceLoader.exists(fallback_path):
		var texture: Texture2D = load(fallback_path) as Texture2D
		if texture != null:
			target.texture = texture


func _set_texture_if_valid(target: TextureRect, texture_path: String) -> void:
	if texture_path == "":
		return
	if not ResourceLoader.exists(texture_path):
		return
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture != null:
		target.texture = texture


func _build_enemy_states(setup: Dictionary) -> Array[Dictionary]:
	var enemies_data: Array = setup.get("enemies", [])
	if enemies_data.is_empty():
		var fallback: Dictionary = setup.get("enemy", {})
		if not fallback.is_empty():
			enemies_data = [fallback]
		else:
			enemies_data = [{
				"id": "fallback_enemy",
				"name": "Test Goblin",
				"max_hp": 20,
				"intents": [{"pattern_id": "light_attack"}]
			}]

	var states: Array[Dictionary] = []
	for enemy_data: Dictionary in enemies_data:
		states.append({
			"id": String(enemy_data.get("id", "enemy_unknown")),
			"name": String(enemy_data.get("name", "Unknown Enemy")),
			"max_hp": int(enemy_data.get("max_hp", 40)),
			"hp": int(enemy_data.get("max_hp", 40)),
			"block": 0,
			"intents": enemy_data.get("intents", []),
			"intent_index": 0
		})
	return states


func _build_deck_from_setup(setup: Dictionary) -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	var raw_deck: Array = setup.get("deck", [])
	for raw_card: Variant in raw_deck:
		if raw_card is Dictionary:
			deck.append((raw_card as Dictionary).duplicate(true))

	if deck.is_empty():
		return _create_fallback_deck()

	return deck


func _create_fallback_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	for i: int in range(12):
		deck.append({
			"id": "strike_%d" % i,
			"name": "Strike",
			"cost": 1,
			"type": "attack",
			"damage": 6
		})
	for i: int in range(8):
		deck.append({
			"id": "guard_%d" % i,
			"name": "Guard",
			"cost": 1,
			"type": "skill",
			"block": 5
		})
	return deck


func _start_player_round() -> void:
	if _battle_over:
		return

	_battle_state_machine.enter_round_start()
	_turn_manager.start_player_round(
		_player_state,
		_waifu_scaled_effects,
		_draw_pile,
		_hand,
		_discard_pile,
		STARTING_DRAW,
		MAX_HAND_SIZE
	)
	_battle_state_machine.enter_player_turn()
	_refresh_ui("Round %d start" % _round_number)


func _on_end_turn_pressed() -> void:
	if _battle_over or not _battle_state_machine.can_end_turn():
		return
	_discard_hand()
	_run_enemy_turn()


func _discard_hand() -> void:
	_turn_manager.discard_hand(_hand, _discard_pile)


func _run_enemy_turn() -> void:
	_battle_state_machine.enter_enemy_turn()
	for i: int in range(_enemy_states.size()):
		var enemy_state: Dictionary = _enemy_states[i]
		if int(enemy_state.get("hp", 0)) <= 0:
			continue
		var intent_index: int = int(enemy_state.get("intent_index", 0))
		var intent_result: Dictionary = _enemy_ai.run_enemy_turn(enemy_state, intent_index, _player_state, _effect_resolver)
		if bool(intent_result.get("had_intent", false)):
			enemy_state["intent_index"] = int(intent_result.get("next_intent_index", intent_index))
		if int(_player_state["hp"]) <= 0:
			break

	_battle_state_machine.enter_end_check()
	_check_battle_end()

	if _battle_over:
		return

	_round_number += 1
	_start_player_round()


func _play_card_by_id(card_id: String, target_enemy_index: int = -1) -> void:
	if _battle_over or not _battle_state_machine.can_play_cards():
		return

	var play_result: Dictionary = _card_play_service.play_card(
		card_id,
		_hand,
		_player_state,
		_enemy_states,
		_waifu_scaled_effects,
		_effect_resolver,
		_turn_manager,
		_draw_pile,
		_discard_pile,
		MAX_HAND_SIZE,
		target_enemy_index
	)
	if not bool(play_result.get("ok", false)):
		_refresh_ui(String(play_result.get("message", "Card play failed.")))
		return

	_check_battle_end()
	_refresh_ui(String(play_result.get("message", "Card played.")))


func _all_enemies_dead() -> bool:
	for enemy_state: Dictionary in _enemy_states:
		if int(enemy_state.get("hp", 0)) > 0:
			return false
	return true


func _check_battle_end() -> void:
	_battle_state_machine.enter_end_check()
	if _all_enemies_dead():
		_battle_over = true
		_battle_state_machine.enter_battle_over()
		for enemy_state: Dictionary in _enemy_states:
			enemy_state["hp"] = 0
		_end_turn_button.disabled = true
		GameState.set_player_combat_stats(int(_player_state["hp"]), int(_player_state["max_hp"]), int(_player_state["mana"]), int(_player_state["base_mana"]))
		SignalBus.broadcast_battle_ended(true, {"gold": 25})
		SignalBus.request_victory_screen()
		return

	if int(_player_state["hp"]) <= 0:
		_battle_over = true
		_battle_state_machine.enter_battle_over()
		_player_state["hp"] = 0
		_end_turn_button.disabled = true
		GameState.set_player_combat_stats(0, int(_player_state["max_hp"]), 0, int(_player_state["base_mana"]))
		SignalBus.broadcast_battle_ended(false, {})
		_refresh_ui("Defeat")
		return

	# Battle continues - return to player turn
	_battle_state_machine.enter_player_turn()


func _format_battle_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]


func _open_deck_overlay() -> void:
	_deck_title_label.text = "Your Deck (%d cards)" % _full_deck.size()
	for child: Node in _deck_card_grid.get_children():
		_deck_card_grid.remove_child(child)
		child.queue_free()
	_deck_overlay.visible = true
	for card_data: Dictionary in _full_deck:
		var card_ui: Control = CardUIScene.instantiate()
		card_ui.call("setup", card_data, CardUI.CardSize.FULL)
		card_ui.custom_minimum_size = card_ui.size
		card_ui.mouse_filter = Control.MOUSE_FILTER_PASS
		_deck_card_grid.add_child(card_ui)


func _close_deck_overlay() -> void:
	_deck_overlay.visible = false
	for child: Node in _deck_card_grid.get_children():
		_deck_card_grid.remove_child(child)
		child.queue_free()


func _refresh_ui(_log_text: String = "") -> void:
	_battle_info_label.text = "Floor 1  •  Turn %d  •  %s" % [_round_number, _format_battle_time(_battle_elapsed_time)]
	_main_waifu_stats_label.text = "%s\nHP %d/%d | Block %d" % [
		_selected_waifu_name,
		int(_player_state["hp"]),
		int(_player_state["max_hp"]),
		int(_player_state["block"])
	]

	_update_player_board_layout()

	_summon_1_stats_label.text = "Summon 1: Empty"
	_summon_2_stats_label.text = "Summon 2: Empty"
	_summon_3_stats_label.text = "Summon 3: Empty"

	for i: int in range(_enemy_cards.size()):
		if i < _enemy_states.size():
			var enemy_state: Dictionary = _enemy_states[i]
			var intent_index: int = int(enemy_state.get("intent_index", 0))
			var resolved_intent: Dictionary = _enemy_ai.get_current_intent(enemy_state, intent_index)
			var intent_name: String = String(resolved_intent.get("display_name", "None"))
			var intent_params: Dictionary = resolved_intent.get("params", {})
			var intent_damage: int = int(intent_params.get("damage", 0))
			var intent_block: int = int(intent_params.get("block", 0))

			var intent_text: String = "Intent: %s" % intent_name
			if intent_damage > 0 and intent_block > 0:
				intent_text += " (%d dmg / %d block)" % [intent_damage, intent_block]
			elif intent_damage > 0:
				intent_text += " (%d dmg)" % intent_damage
			elif intent_block > 0:
				intent_text += " (%d block)" % intent_block

			_enemy_stats_labels[i].text = "%s\nHP %d/%d | Block %d" % [
				String(enemy_state.get("name", "Enemy")),
				int(enemy_state.get("hp", 0)),
				int(enemy_state.get("max_hp", 0)),
				int(enemy_state.get("block", 0))
			]
			_enemy_intent_labels[i].text = intent_text
			_enemy_cards[i].sprite_anchor = String(enemy_state.get("sprite_anchor", "bottom"))
			_enemy_cards[i].visible = true
		else:
			_enemy_cards[i].visible = false

	_update_enemy_board_layout()

	_draw_pile_count_label.text = str(_draw_pile.size())
	_discard_pile_count_label.text = str(_discard_pile.size())
	_mana_label.text = "Mana: %d" % int(_player_state["mana"])

	_rebuild_hand_cards()


func _rebuild_hand_cards() -> void:
	for child: Node in _hand_container.get_children():
		_hand_container.remove_child(child)
		child.queue_free()

	for card: Dictionary in _hand:
		var card_ui: Control = CardUIScene.instantiate()
		card_ui.call("setup", card, 0)  # 0 = CardUI.CardSize.HAND
		card_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		card_ui.set_meta("card_id", String(card["id"]))
		card_ui.set_meta("card_data", card)
		card_ui.gui_input.connect(_on_card_gui_input.bind(card_ui))
		card_ui.mouse_entered.connect(_on_card_mouse_entered.bind(card_ui))
		card_ui.mouse_exited.connect(_on_card_mouse_exited.bind(card_ui))

		var can_play: bool = int(card.get("cost", 0)) <= int(_player_state["mana"]) and not _battle_over
		card_ui.call("set_unplayable_tint", not can_play)

		_hand_container.add_child(card_ui)

	_arrange_hand_cards()


func _on_card_gui_input(event: InputEvent, card_ui: Control) -> void:
	if _battle_over or not _battle_state_machine.can_play_cards():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_card_drag(card_ui)


func _on_card_mouse_entered(card_ui: Control) -> void:
	if _drag_active:
		return
	var base_z: int = int(card_ui.get_meta("base_z", 0))
	card_ui.z_index = base_z + 50
	var base_pos: Vector2 = card_ui.get_meta("base_pos", card_ui.position)
	card_ui.position = Vector2(base_pos.x, base_pos.y - 15.0)
	card_ui.scale = Vector2(1.06, 1.06)


func _on_card_mouse_exited(card_ui: Control) -> void:
	if _drag_active:
		return
	var base_z: int = int(card_ui.get_meta("base_z", 0))
	card_ui.z_index = base_z
	var base_pos: Vector2 = card_ui.get_meta("base_pos", card_ui.position)
	card_ui.position = base_pos
	card_ui.scale = Vector2.ONE


func _update_player_board_layout() -> void:
	var summon_cards: Array[Control] = [_summon_1_card, _summon_2_card, _summon_3_card]
	var visible_units: int = 1 + _active_summon_count

	for i: int in range(summon_cards.size()):
		summon_cards[i].visible = i < _active_summon_count

	# Keep the active units centered in the middle of available space.
	_left_spacer.visible = true
	_right_spacer.visible = true
	_left_spacer.size_flags_stretch_ratio = 1.0
	_right_spacer.size_flags_stretch_ratio = 1.0

	_main_waifu_card.size_flags_stretch_ratio = 1.0
	for summon_card: Control in summon_cards:
		summon_card.size_flags_stretch_ratio = 1.0

	# When nothing is summoned, keep the commander centered with stronger side spacing.
	if _active_summon_count == 0:
		_left_spacer.size_flags_stretch_ratio = 2.0
		_right_spacer.size_flags_stretch_ratio = 2.0
		_main_waifu_card.size_flags_stretch_ratio = 1.4

	# If two or more summons are present, reduce side padding and prioritize board occupancy.
	if visible_units >= 3:
		_left_spacer.size_flags_stretch_ratio = 0.6
		_right_spacer.size_flags_stretch_ratio = 0.6


func _update_enemy_board_layout() -> void:
	var active_count: int = _enemy_states.size()
	for i: int in range(_enemy_cards.size()):
		_enemy_cards[i].visible = i < active_count

	# Default even spacing
	_enemy_left_spacer.visible = true
	_enemy_right_spacer.visible = true
	_enemy_left_spacer.size_flags_stretch_ratio = 1.0
	_enemy_right_spacer.size_flags_stretch_ratio = 1.0

	for card: Control in _enemy_cards:
		card.size_flags_stretch_ratio = 1.0

	# Single enemy: center with stronger side spacing
	if active_count == 1:
		_enemy_left_spacer.size_flags_stretch_ratio = 2.0
		_enemy_right_spacer.size_flags_stretch_ratio = 2.0
		_enemy_cards[0].size_flags_stretch_ratio = 1.4

	# Three or more enemies: reduce side padding
	if active_count >= 3:
		_enemy_left_spacer.size_flags_stretch_ratio = 0.6
		_enemy_right_spacer.size_flags_stretch_ratio = 0.6
