extends Node

const BATTLE_SETUP_SCHEMA_VERSION: int = 1

var current_setup: Dictionary = {}


func _ready() -> void:
	SignalBus.battle_start_requested.connect(_on_battle_start_requested)


func _on_battle_start_requested(_battle_id: String, payload: Dictionary) -> void:
	var setup: Dictionary = _build_setup_payload(payload)
	if setup.is_empty():
		SignalBus.broadcast_battle_setup_failed("Failed to build battle setup payload.")
		return
	var validation_error: String = _validate_setup_payload(setup)
	if validation_error != "":
		SignalBus.broadcast_battle_setup_failed(validation_error)
		return

	current_setup = setup
	SignalBus.broadcast_battle_setup_ready(current_setup)


func _build_setup_payload(payload: Dictionary) -> Dictionary:
	var waifu_id: String = String(payload.get("waifu_id", SaveManager.get_selected_waifu_id()))
	var sub_waifu_id: String = String(payload.get("sub_waifu_id", SaveManager.get_selected_sub_waifu_id()))
	var deck_ids: Array[String] = SaveManager.get_selected_deck_card_ids()

	var waifu_data: Dictionary = ContentDB.get_waifu(waifu_id)
	var sub_waifu_data: Dictionary = ContentDB.get_waifu(sub_waifu_id)

	var enemy_ids: Array = payload.get("enemy_ids", [])
	if enemy_ids.is_empty():
		var fallback_id: String = String(payload.get("enemy_id", SaveManager.get_selected_enemy_id()))
		enemy_ids = [fallback_id]

	var enemies_data: Array[Dictionary] = []
	for raw_id: Variant in enemy_ids:
		var enemy_data: Dictionary = ContentDB.get_enemy(String(raw_id))
		if not enemy_data.is_empty():
			enemies_data.append(enemy_data)

	if enemies_data.is_empty():
		return {}

	var enemies: Array[Dictionary] = []
	for enemy_data: Dictionary in enemies_data:
		enemies.append({
			"id": String(enemy_data.get("id", "unknown")),
			"name": String(enemy_data.get("name", "Unknown Enemy")),
			"max_hp": int(enemy_data.get("max_hp", 40)),
			"sprite_anchor": String(enemy_data.get("sprite_anchor", "bottom")),
			"intents": enemy_data.get("intents", [])
		})

	var bond_level: int = SaveManager.get_bond_level(waifu_id)
	var runtime_deck: Array[Dictionary] = _build_runtime_deck(deck_ids)

	return {
		"schema_version": BATTLE_SETUP_SCHEMA_VERSION,
		"waifu_id": waifu_id,
		"waifu_name": String(waifu_data.get("display_name", waifu_id)),
		"waifu_portrait_path": String(waifu_data.get("portrait_path", "")),
		"waifu_bond": bond_level,
		"waifu_effects": ContentDB.get_bond_scaled_waifu_effects(waifu_id, bond_level),
		"sub_waifu_id": sub_waifu_id,
		"sub_waifu_name": String(sub_waifu_data.get("display_name", sub_waifu_id)),
		"sub_waifu_portrait_path": String(sub_waifu_data.get("portrait_path", "")),
		"enemies": enemies,
		"deck": runtime_deck
	}


func _validate_setup_payload(setup: Dictionary) -> String:
	var required_top_level: PackedStringArray = [
		"schema_version",
		"waifu_id",
		"enemies",
		"deck"
	]
	for field_name: String in required_top_level:
		if not setup.has(field_name):
			return "Battle setup missing required field '%s'." % field_name

	if int(setup.get("schema_version", -1)) != BATTLE_SETUP_SCHEMA_VERSION:
		return "Unsupported battle setup schema version."

	var enemies: Array = setup.get("enemies", [])
	if enemies.is_empty():
		return "Battle setup enemies array is empty."

	for raw_enemy: Variant in enemies:
		if not (raw_enemy is Dictionary):
			return "Battle setup enemies must contain only objects."
		var enemy: Dictionary = raw_enemy as Dictionary
		if not enemy.has("id"):
			return "Battle setup enemy payload missing id."
		if not enemy.has("max_hp"):
			return "Battle setup enemy payload missing max_hp."
		if not (enemy.get("intents", []) is Array):
			return "Battle setup enemy intents must be an array."

	var deck: Array = setup.get("deck", [])
	if deck.is_empty():
		return "Battle setup deck is empty."

	return ""


func _build_runtime_deck(deck_ids: Array[String]) -> Array[Dictionary]:
	var runtime_deck: Array[Dictionary] = []
	for card_id: String in deck_ids:
		var source_card: Dictionary = ContentDB.get_card(card_id)
		if source_card.is_empty():
			continue
		if not bool(source_card.get("supported_in_v1", false)):
			continue
		runtime_deck.append(_to_runtime_card(source_card))

	if runtime_deck.is_empty():
		runtime_deck = _fallback_deck()

	return runtime_deck


func _to_runtime_card(source_card: Dictionary) -> Dictionary:
	var runtime_card: Dictionary = {
		"id": String(source_card.get("id", "")),
		"name": String(source_card.get("name", "Unknown Card")),
		"cost": int(source_card.get("cost", 0)),
		"type": String(source_card.get("type", "Skill")).to_lower()
	}

	var effects: Array = source_card.get("effects", [])
	for raw_effect: Variant in effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect as Dictionary
		match String(effect.get("type", "")):
			"DealDamage":
				runtime_card["damage"] = int(effect.get("value", 0))
			"GainBlock":
				runtime_card["block"] = int(effect.get("value", 0))
			"DrawCards":
				runtime_card["draw"] = int(effect.get("value", 0))
			"GainMana":
				runtime_card["gain_mana"] = int(effect.get("value", 0))

	return runtime_card


func _fallback_deck() -> Array[Dictionary]:
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
