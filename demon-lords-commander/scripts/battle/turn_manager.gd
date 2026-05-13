extends RefCounted

# TurnManager owns round flow utilities that are independent from scene/UI nodes.
# Keeping this logic outside BattleController makes it easier to test and extend.


func start_player_round(
	player_state: Dictionary,
	waifu_scaled_effects: Array[Dictionary],
	draw_pile: Array[Dictionary],
	hand: Array[Dictionary],
	discard_pile: Array[Dictionary],
	starting_draw: int,
	max_hand_size: int
) -> void:
	player_state["mana"] = int(player_state.get("base_mana", 0))
	player_state["block"] = 0
	_apply_start_of_turn_waifu_effects(player_state, waifu_scaled_effects)
	draw_cards(draw_pile, hand, discard_pile, starting_draw, max_hand_size)


func draw_cards(
	draw_pile: Array[Dictionary],
	hand: Array[Dictionary],
	discard_pile: Array[Dictionary],
	amount: int,
	max_hand_size: int
) -> void:
	for _i: int in range(max(amount, 0)):
		_draw_one_card(draw_pile, hand, discard_pile, max_hand_size)


func discard_hand(hand: Array[Dictionary], discard_pile: Array[Dictionary]) -> void:
	while not hand.is_empty():
		discard_pile.append(hand.pop_back())


func apply_start_of_turn_waifu_effects(player_state: Dictionary, waifu_scaled_effects: Array[Dictionary]) -> void:
	_apply_start_of_turn_waifu_effects(player_state, waifu_scaled_effects)


func _apply_start_of_turn_waifu_effects(player_state: Dictionary, waifu_scaled_effects: Array[Dictionary]) -> void:
	for effect: Dictionary in waifu_scaled_effects:
		var effect_type: String = String(effect.get("type", ""))
		var effect_value: int = int(effect.get("value", 0))
		match effect_type:
			"passive_start_turn_mana":
				player_state["mana"] = int(player_state.get("mana", 0)) + effect_value
			"passive_block_per_turn":
				player_state["block"] = int(player_state.get("block", 0)) + effect_value


func _draw_one_card(
	draw_pile: Array[Dictionary],
	hand: Array[Dictionary],
	discard_pile: Array[Dictionary],
	max_hand_size: int
) -> void:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return
		draw_pile.assign(discard_pile.duplicate(true))
		discard_pile.clear()
		draw_pile.shuffle()

	if draw_pile.is_empty():
		return

	var drawn_card: Dictionary = draw_pile.pop_back()
	if hand.size() >= max_hand_size:
		# If hand is full, the draw is still consumed and card goes to discard.
		discard_pile.append(drawn_card)
		return

	hand.append(drawn_card)
