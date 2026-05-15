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
	player_state["strength_round"] = 0
	var player_frail: int = int(player_state.get("frail", 0))
	if player_frail > 0:
		player_state["frail"] = player_frail - 1
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


func tick_enemy_burn(enemy_states: Array[Dictionary], effect_resolver: RefCounted) -> void:
	for enemy_state: Dictionary in enemy_states:
		if int(enemy_state.get("hp", 0)) <= 0:
			continue
		var burn: int = int(enemy_state.get("burn", 0))
		if burn > 0:
			effect_resolver.apply_damage_to_enemy(enemy_state, burn)


func tick_enemy_status_effects(enemy_states: Array[Dictionary], effect_resolver: RefCounted) -> void:
	for enemy_state: Dictionary in enemy_states:
		if int(enemy_state.get("hp", 0)) <= 0:
			continue
		var poison: int = int(enemy_state.get("poison", 0))
		if poison > 0:
			effect_resolver.apply_damage_to_enemy(enemy_state, poison)
			enemy_state["poison"] = max(0, poison - 1)
		var frail: int = int(enemy_state.get("frail", 0))
		if frail > 0:
			enemy_state["frail"] = frail - 1


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
