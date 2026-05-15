extends Node

const CARDS_PATH: String = "res://data/cards.json"
const WAIFUS_PATH: String = "res://data/waifus.json"
const ENEMIES_PATH: String = "res://data/enemies.json"

const V1_SUPPORTED_EFFECTS: PackedStringArray = [
	"DealDamage",
	"GainBlock",
	"DrawCards",
	"GainMana",
	"GainStrength",
	"ApplyDebuff",
	"GainRage",
	"SearchDeck"
]

var cards_by_id: Dictionary = {}
var waifus_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var validation_messages: PackedStringArray = []


func _ready() -> void:
	reload_content()


func reload_content() -> void:
	cards_by_id.clear()
	waifus_by_id.clear()
	enemies_by_id.clear()
	validation_messages = PackedStringArray()

	var cards_data: Dictionary = _load_json_dict(CARDS_PATH)
	var waifus_data: Dictionary = _load_json_dict(WAIFUS_PATH)
	var enemies_data: Dictionary = _load_json_dict(ENEMIES_PATH)

	_ingest_cards(cards_data.get("cards", []))
	_ingest_waifus(waifus_data.get("waifus", []))
	_ingest_enemies(enemies_data.get("enemies", []))

	if not validation_messages.is_empty():
		for message: String in validation_messages:
			push_warning(message)


func get_card(card_id: String) -> Dictionary:
	return cards_by_id.get(card_id, {})


func get_enemy(enemy_id: String) -> Dictionary:
	return enemies_by_id.get(enemy_id, {})


func get_waifu(waifu_id: String) -> Dictionary:
	return waifus_by_id.get(waifu_id, {})


func get_bond_scaled_waifu_effects(waifu_id: String, bond_level: int) -> Array[Dictionary]:
	var waifu: Dictionary = get_waifu(waifu_id)
	if waifu.is_empty():
		return []

	var clamped_bond: int = clampi(bond_level, 1, 10)
	var effects: Array = waifu.get("effects", [])
	var scaled_effects: Array[Dictionary] = []

	for raw_effect: Variant in effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = (raw_effect as Dictionary).duplicate(true)
		var base_value: int = int(effect.get("base_value", 0))
		var per_bond: int = int(effect.get("per_bond", 0))
		effect["value"] = base_value + ((clamped_bond - 1) * per_bond)
		scaled_effects.append(effect)

	return scaled_effects


func _ingest_cards(raw_cards: Array) -> void:
	for raw_card: Variant in raw_cards:
		if not (raw_card is Dictionary):
			validation_messages.append("Card entry is not an object.")
			continue

		var card: Dictionary = (raw_card as Dictionary).duplicate(true)
		var card_id: String = String(card.get("id", ""))
		if card_id == "":
			validation_messages.append("Card missing id.")
			continue

		card["id"] = card_id

		var card_errors: PackedStringArray = _validate_card_schema(card)
		for card_error: String in card_errors:
			validation_messages.append("Card %s: %s" % [card_id, card_error])

		cards_by_id[card_id] = card


func _ingest_waifus(raw_waifus: Array) -> void:
	for raw_waifu: Variant in raw_waifus:
		if not (raw_waifu is Dictionary):
			validation_messages.append("Waifu entry is not an object.")
			continue

		var waifu: Dictionary = (raw_waifu as Dictionary).duplicate(true)
		var waifu_id: String = String(waifu.get("id", ""))
		if waifu_id == "":
			validation_messages.append("Waifu missing id.")
			continue

		waifus_by_id[waifu_id] = waifu


func _ingest_enemies(raw_enemies: Array) -> void:
	for raw_enemy: Variant in raw_enemies:
		if not (raw_enemy is Dictionary):
			validation_messages.append("Enemy entry is not an object.")
			continue

		var enemy: Dictionary = (raw_enemy as Dictionary).duplicate(true)
		var enemy_id: String = String(enemy.get("id", ""))
		if enemy_id == "":
			validation_messages.append("Enemy missing id.")
			continue

		var enemy_errors: PackedStringArray = _validate_enemy_schema(enemy)
		for enemy_error: String in enemy_errors:
			validation_messages.append("Enemy %s: %s" % [enemy_id, enemy_error])

		enemies_by_id[enemy_id] = enemy


func _validate_card_schema(card: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var required_fields: PackedStringArray = ["id", "name", "type", "cost", "effects"]
	for field_name: String in required_fields:
		if not card.has(field_name):
			errors.append("Missing required field '%s'." % field_name)

	var effects: Array = card.get("effects", [])
	if effects.is_empty():
		errors.append("Card has no effects.")

	var has_unsupported_effect: bool = false
	for raw_effect: Variant in effects:
		if not (raw_effect is Dictionary):
			errors.append("Effect entry is not an object.")
			continue

		var effect_type: String = String((raw_effect as Dictionary).get("type", ""))
		if effect_type == "":
			errors.append("Effect missing type.")
			continue

		if not V1_SUPPORTED_EFFECTS.has(effect_type):
			has_unsupported_effect = true

	if card.has("art_path") and not (card["art_path"] is String):
		errors.append("Field 'art_path' must be a string.")
	if card.has("border_path") and not (card["border_path"] is String):
		errors.append("Field 'border_path' must be a string.")

	card["supported_in_v1"] = not has_unsupported_effect
	return errors


func _validate_enemy_schema(enemy: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var required_fields: PackedStringArray = ["id", "name", "max_hp", "intents"]
	for field_name: String in required_fields:
		if not enemy.has(field_name):
			errors.append("Missing required field '%s'." % field_name)

	var intents: Array = enemy.get("intents", [])
	if intents.is_empty():
		errors.append("Enemy has no intents.")

	for raw_intent: Variant in intents:
		if not (raw_intent is Dictionary):
			errors.append("Intent entry is not an object.")
			continue

		var intent: Dictionary = raw_intent as Dictionary
		# New format uses pattern_id, legacy format uses inline damage/block
		if intent.has("pattern_id"):
			var pattern_id: String = String(intent.get("pattern_id", ""))
			if pattern_id == "":
				errors.append("Intent has empty pattern_id.")
		elif not (intent.has("damage") or intent.has("block")):
			errors.append("Intent must have either pattern_id or legacy damage/block fields.")

	var anchor: String = String(enemy.get("sprite_anchor", "bottom"))
	if anchor != "bottom" and anchor != "center":
		errors.append("sprite_anchor must be 'bottom' or 'center'.")

	return errors


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		validation_messages.append("Missing data file: %s" % path)
		return {}

	var raw_text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		validation_messages.append("Invalid JSON format in: %s" % path)
		return {}

	return parsed as Dictionary
