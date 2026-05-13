class_name IntentLibrary
extends RefCounted

# IntentLibrary owns reusable intent type definitions and execution logic.
# This separates WHAT an intent does from HOW enemies select/use them.

const INTENT_TYPE_ATTACK: String = "attack"
const INTENT_TYPE_BLOCK: String = "block"
const INTENT_TYPE_BUFF: String = "buff"
const INTENT_TYPE_DEBUFF: String = "debuff"


func execute_attack(
	enemy_state: Dictionary,
	player_state: Dictionary,
	effect_resolver: RefCounted,
	params: Dictionary
) -> Dictionary:
	var damage: int = int(params.get("damage", 0))
	if damage > 0:
		effect_resolver.apply_damage_to_player(player_state, damage)
	return {"damage_dealt": damage}


func execute_block(
	enemy_state: Dictionary,
	player_state: Dictionary,
	effect_resolver: RefCounted,
	params: Dictionary
) -> Dictionary:
	var block: int = int(params.get("block", 0))
	if block > 0:
		enemy_state["block"] = int(enemy_state.get("block", 0)) + block
	return {"block_gained": block}


func execute_buff(
	enemy_state: Dictionary,
	player_state: Dictionary,
	effect_resolver: RefCounted,
	params: Dictionary
) -> Dictionary:
	# Placeholder for future buff logic
	var buff_type: String = String(params.get("buff_type", ""))
	var value: int = int(params.get("value", 0))
	return {"buff_type": buff_type, "value": value}


func execute_debuff(
	enemy_state: Dictionary,
	player_state: Dictionary,
	effect_resolver: RefCounted,
	params: Dictionary
) -> Dictionary:
	# Placeholder for future debuff logic
	var debuff_type: String = String(params.get("debuff_type", ""))
	var value: int = int(params.get("value", 0))
	return {"debuff_type": debuff_type, "value": value}


func execute_intent(
	intent_type: String,
	enemy_state: Dictionary,
	player_state: Dictionary,
	effect_resolver: RefCounted,
	params: Dictionary
) -> Dictionary:
	match intent_type:
		INTENT_TYPE_ATTACK:
			return execute_attack(enemy_state, player_state, effect_resolver, params)
		INTENT_TYPE_BLOCK:
			return execute_block(enemy_state, player_state, effect_resolver, params)
		INTENT_TYPE_BUFF:
			return execute_buff(enemy_state, player_state, effect_resolver, params)
		INTENT_TYPE_DEBUFF:
			return execute_debuff(enemy_state, player_state, effect_resolver, params)
		_:
			push_warning("IntentLibrary: Unknown intent type '%s'" % intent_type)
			return {}


func get_intent_display_name(intent_type: String) -> String:
	match intent_type:
		INTENT_TYPE_ATTACK:
			return "Attack"
		INTENT_TYPE_BLOCK:
			return "Block"
		INTENT_TYPE_BUFF:
			return "Buff"
		INTENT_TYPE_DEBUFF:
			return "Debuff"
		_:
			return "Unknown"


func is_valid_intent_type(intent_type: String) -> bool:
	return intent_type in [INTENT_TYPE_ATTACK, INTENT_TYPE_BLOCK, INTENT_TYPE_BUFF, INTENT_TYPE_DEBUFF]
