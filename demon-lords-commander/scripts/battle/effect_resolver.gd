extends RefCounted

# EffectResolver owns combat math (damage, card attack bonuses, enemy intent execution).
# BattleController should call this and then only handle scene/UI and battle flow decisions.


func resolved_attack_damage(card: Dictionary, player_state: Dictionary, waifu_scaled_effects: Array[Dictionary]) -> int:
	var total_damage: int = int(card.get("damage", 0))
	if String(card.get("type", "")) != "attack":
		return total_damage

	total_damage += int(player_state.get("strength", 0))
	total_damage += int(player_state.get("strength_round", 0))

	for effect: Dictionary in waifu_scaled_effects:
		if String(effect.get("type", "")) == "passive_attack_damage":
			total_damage += int(effect.get("value", 0))

	var rage: int = int(player_state.get("rage", 0))
	if rage > 0:
		total_damage = int(float(total_damage) * 1.5)
		player_state["rage"] = rage - 1

	return total_damage


func apply_damage_to_enemy(enemy_state: Dictionary, amount: int) -> void:
	var remaining_damage: int = max(amount, 0)
	var enemy_block: int = int(enemy_state.get("block", 0))
	if enemy_block > 0:
		var absorbed: int = min(enemy_block, remaining_damage)
		enemy_state["block"] = enemy_block - absorbed
		remaining_damage -= absorbed

	if remaining_damage > 0:
		enemy_state["hp"] = int(enemy_state.get("hp", 0)) - remaining_damage


func apply_damage_to_player(player_state: Dictionary, amount: int) -> void:
	var remaining_damage: int = max(amount, 0)
	if int(player_state.get("frail", 0)) > 0:
		remaining_damage = int(float(remaining_damage) * 1.25)
	var player_block: int = int(player_state.get("block", 0))
	if player_block > 0:
		var absorbed: int = min(player_block, remaining_damage)
		player_state["block"] = player_block - absorbed
		remaining_damage -= absorbed

	if remaining_damage > 0:
		player_state["hp"] = int(player_state.get("hp", 0)) - remaining_damage


func run_enemy_intent(enemy_state: Dictionary, intent_index: int, player_state: Dictionary) -> Dictionary:
	var intents: Array = enemy_state.get("intents", [])
	if intents.is_empty():
		return {
			"had_intent": false,
			"next_intent_index": intent_index,
			"intent_name": "None"
		}

	var current_intent: Dictionary = intents[intent_index]
	var intent_block: int = int(current_intent.get("block", 0))
	var intent_damage: int = int(current_intent.get("damage", 0))

	if intent_block > 0:
		enemy_state["block"] = int(enemy_state.get("block", 0)) + intent_block
	if intent_damage > 0:
		apply_damage_to_player(player_state, intent_damage)

	return {
		"had_intent": true,
		"next_intent_index": (intent_index + 1) % intents.size(),
		"intent_name": String(current_intent.get("name", "Unknown Intent"))
	}
