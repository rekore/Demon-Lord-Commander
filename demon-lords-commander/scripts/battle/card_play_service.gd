extends RefCounted

# CardPlayService handles the full "play one card" pipeline.
# It keeps BattleController focused on scene orchestration and UI.


func play_card(
	card_id: String,
	hand: Array[Dictionary],
	player_state: Dictionary,
	enemy_states: Array[Dictionary],
	waifu_scaled_effects: Array[Dictionary],
	effect_resolver: RefCounted,
	turn_manager: RefCounted,
	draw_pile: Array[Dictionary],
	discard_pile: Array[Dictionary],
	max_hand_size: int,
	target_enemy_index: int = -1
) -> Dictionary:
	var card_index: int = _find_card_index(hand, card_id)
	if card_index < 0:
		return {"ok": false, "message": "Card not found in hand."}

	var card: Dictionary = hand[card_index]
	var cost: int = int(card.get("cost", 0))
	if cost > int(player_state.get("mana", 0)):
		return {"ok": false, "message": "Not enough mana for %s" % String(card.get("name", "Card"))}

	player_state["mana"] = int(player_state.get("mana", 0)) - cost
	_resolve_card_effects(
		card,
		player_state,
		enemy_states,
		waifu_scaled_effects,
		effect_resolver,
		turn_manager,
		draw_pile,
		hand,
		discard_pile,
		max_hand_size,
		target_enemy_index
	)

	discard_pile.append(card)
	hand.remove_at(card_index)
	return {"ok": true, "message": "Played %s" % String(card.get("name", "Card"))}


func _find_card_index(hand: Array[Dictionary], card_id: String) -> int:
	for i: int in range(hand.size()):
		if String(hand[i].get("id", "")) == card_id:
			return i
	return -1


func _resolve_card_effects(
	card: Dictionary,
	player_state: Dictionary,
	enemy_states: Array[Dictionary],
	waifu_scaled_effects: Array[Dictionary],
	effect_resolver: RefCounted,
	turn_manager: RefCounted,
	draw_pile: Array[Dictionary],
	hand: Array[Dictionary],
	discard_pile: Array[Dictionary],
	max_hand_size: int,
	target_enemy_index: int = -1
) -> void:
	var damage: int = effect_resolver.resolved_attack_damage(card, waifu_scaled_effects)
	var block_gain: int = int(card.get("block", 0))
	var draw_amount: int = int(card.get("draw", 0))
	var mana_gain: int = int(card.get("gain_mana", 0))

	if damage > 0:
		if target_enemy_index >= 0 and target_enemy_index < enemy_states.size():
			var target_enemy: Dictionary = enemy_states[target_enemy_index]
			if int(target_enemy.get("hp", 0)) > 0:
				effect_resolver.apply_damage_to_enemy(target_enemy, damage)
		else:
			for enemy_state: Dictionary in enemy_states:
				if int(enemy_state.get("hp", 0)) > 0:
					effect_resolver.apply_damage_to_enemy(enemy_state, damage)
	if block_gain > 0:
		player_state["block"] = int(player_state.get("block", 0)) + block_gain
	if draw_amount > 0:
		turn_manager.draw_cards(draw_pile, hand, discard_pile, draw_amount, max_hand_size)
	if mana_gain > 0:
		player_state["mana"] = int(player_state.get("mana", 0)) + mana_gain
