extends Node

const CARDS_PATH: String = "res://data/cards.json"
const WAIFUS_PATH: String = "res://data/waifus.json"
const ENEMIES_PATH: String = "res://data/enemies.json"
const LOCATIONS_PATH: String = "res://data/locations.json"
const POIS_PATH: String = "res://data/pois.json"
const RELICS_PATH: String = "res://data/relics.json"
const DUNGEONS_PATH: String = "res://data/dungeons.json"
const EVENTS_PATH: String = "res://data/events.json"
const LOOT_ITEMS_PATH: String = "res://data/loot_items.json"

const V1_SUPPORTED_EFFECTS: PackedStringArray = [
	"DealDamage",
	"GainBlock",
	"DrawCards",
	"GainMana",
	"GainStrength",
	"ApplyDebuff",
	"GainRage",
	"SearchDeck",
	"Summon",
	"SacrificeAllSummons"
]

var cards_by_id: Dictionary = {}
var waifus_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var locations_by_id: Dictionary = {}
var pois_by_id: Dictionary = {}
var relics_by_id: Dictionary = {}
var dungeons_by_id: Dictionary = {}
var events_by_id: Dictionary = {}
var loot_items_by_id: Dictionary = {}
var validation_messages: PackedStringArray = []


func _ready() -> void:
	reload_content()


func reload_content() -> void:
	cards_by_id.clear()
	waifus_by_id.clear()
	enemies_by_id.clear()
	locations_by_id.clear()
	pois_by_id.clear()
	relics_by_id.clear()
	dungeons_by_id.clear()
	events_by_id.clear()
	loot_items_by_id.clear()
	validation_messages = PackedStringArray()

	var cards_data: Dictionary = _load_json_dict(CARDS_PATH)
	var waifus_data: Dictionary = _load_json_dict(WAIFUS_PATH)
	var enemies_data: Dictionary = _load_json_dict(ENEMIES_PATH)
	var locations_data: Dictionary = _load_json_dict(LOCATIONS_PATH)

	_ingest_cards(cards_data.get("cards", []))
	_ingest_waifus(waifus_data.get("waifus", []))
	_ingest_enemies(enemies_data.get("enemies", []))
	_ingest_locations(locations_data.get("locations", []))
	var pois_data: Dictionary = _load_json_dict(POIS_PATH)
	_ingest_pois(pois_data.get("pois", []))
	var relics_data: Dictionary = _load_json_dict(RELICS_PATH)
	_ingest_relics(relics_data.get("relics", []))
	var dungeons_data: Dictionary = _load_json_dict(DUNGEONS_PATH)
	_ingest_dungeons(dungeons_data.get("dungeons", []))
	var events_data: Dictionary = _load_json_dict(EVENTS_PATH)
	_ingest_events(events_data.get("events", []))
	var loot_data: Dictionary = _load_json_dict(LOOT_ITEMS_PATH)
	_ingest_loot_items(loot_data.get("items", []))

	if not validation_messages.is_empty():
		for message: String in validation_messages:
			push_warning(message)


func get_card(card_id: String) -> Dictionary:
	return cards_by_id.get(card_id, {})


func get_enemy(enemy_id: String) -> Dictionary:
	return enemies_by_id.get(enemy_id, {})


func get_waifu(waifu_id: String) -> Dictionary:
	return waifus_by_id.get(waifu_id, {})


func get_location(location_id: String) -> Dictionary:
	return locations_by_id.get(location_id, {})


func get_map_pois() -> Array:
	var result: Array = []
	for poi: Variant in pois_by_id.values():
		if poi is Dictionary:
			var parent: String = String((poi as Dictionary).get("parent_location_id", ""))
			if parent == "":
				result.append(poi)
	return result


func get_pois_for_location(location_id: String) -> Array:
	var result: Array = []
	for poi: Variant in pois_by_id.values():
		if poi is Dictionary:
			var parent: String = String((poi as Dictionary).get("parent_location_id", ""))
			if parent == location_id:
				result.append(poi)
	return result


func get_map_fog_regions() -> Array:
	var world_map: Dictionary = get_location("world_map")
	return world_map.get("fog_regions", [])


func get_map_size() -> Vector2:
	var world_map: Dictionary = get_location("world_map")
	var map_size: Dictionary = world_map.get("map_size", {})
	var width: int = int(map_size.get("width", 1920))
	var height: int = int(map_size.get("height", 1080))
	return Vector2(width, height)


func get_poi(poi_id: String) -> Dictionary:
	return pois_by_id.get(poi_id, {})


func get_relic(relic_id: String) -> Dictionary:
	return relics_by_id.get(relic_id, {})


func get_all_relics() -> Array:
	return relics_by_id.values()


func get_dungeon(dungeon_id: String) -> Dictionary:
	return dungeons_by_id.get(dungeon_id, {})


func get_all_dungeons() -> Array:
	return dungeons_by_id.values()


func get_loot_item(item_id: String) -> Dictionary:
	return loot_items_by_id.get(item_id, {})


func get_loot_items_for_level(dungeon_level: int) -> Array:
	var result: Array = []
	for raw_item: Variant in loot_items_by_id.values():
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item as Dictionary
		var min_lv: int = int(item.get("min_level", 1))
		var max_lv: int = int(item.get("max_level", 999))
		if dungeon_level >= min_lv and dungeon_level <= max_lv:
			result.append(item)
	return result


func get_all_cards() -> Array:
	return cards_by_id.values()


func get_run_relics_for_level(dungeon_level: int) -> Array:
	var result: Array = []
	for raw_relic: Variant in relics_by_id.values():
		if not (raw_relic is Dictionary):
			continue
		var relic: Dictionary = raw_relic as Dictionary
		if String(relic.get("relic_type", "")) != "run":
			continue
		var min_lv: int = int(relic.get("min_level", 1))
		if dungeon_level >= min_lv:
			result.append(relic)
	return result


func get_event(event_id: String) -> Dictionary:
	return events_by_id.get(event_id, {})


# Returns all events whose level range includes dungeon_level, sorted by weight descending.
func get_events_for_level(dungeon_level: int) -> Array:
	var result: Array = []
	for raw_event: Variant in events_by_id.values():
		if not (raw_event is Dictionary):
			continue
		var event: Dictionary = raw_event as Dictionary
		var min_lv: int = int(event.get("min_level", 1))
		var max_lv: int = int(event.get("max_level", 999))
		if dungeon_level >= min_lv and dungeon_level <= max_lv:
			result.append(event)
	return result


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


func _ingest_locations(raw_locations: Array) -> void:
	for raw_location: Variant in raw_locations:
		if not (raw_location is Dictionary):
			validation_messages.append("Location entry is not an object.")
			continue

		var location: Dictionary = (raw_location as Dictionary).duplicate(true)
		var location_id: String = String(location.get("id", ""))
		if location_id == "":
			validation_messages.append("Location missing id.")
			continue

		locations_by_id[location_id] = location


func _ingest_relics(raw_relics: Array) -> void:
	for raw_relic: Variant in raw_relics:
		if not (raw_relic is Dictionary):
			validation_messages.append("Relic entry is not an object.")
			continue
		var relic: Dictionary = (raw_relic as Dictionary).duplicate(true)
		var relic_id: String = String(relic.get("id", ""))
		if relic_id == "":
			validation_messages.append("Relic missing id.")
			continue
		relics_by_id[relic_id] = relic


func _ingest_dungeons(raw_dungeons: Array) -> void:
	for raw_dungeon: Variant in raw_dungeons:
		if not (raw_dungeon is Dictionary):
			validation_messages.append("Dungeon entry is not an object.")
			continue
		var dungeon: Dictionary = (raw_dungeon as Dictionary).duplicate(true)
		var dungeon_id: String = String(dungeon.get("id", ""))
		if dungeon_id == "":
			validation_messages.append("Dungeon missing id.")
			continue
		dungeons_by_id[dungeon_id] = dungeon


func _ingest_loot_items(raw_items: Array) -> void:
	for raw_item: Variant in raw_items:
		if not (raw_item is Dictionary):
			validation_messages.append("Loot item entry is not an object.")
			continue
		var item: Dictionary = (raw_item as Dictionary).duplicate(true)
		var item_id: String = String(item.get("id", ""))
		if item_id == "":
			validation_messages.append("Loot item missing id.")
			continue
		loot_items_by_id[item_id] = item


func _ingest_events(raw_events: Array) -> void:
	for raw_event: Variant in raw_events:
		if not (raw_event is Dictionary):
			validation_messages.append("Event entry is not an object.")
			continue
		var event: Dictionary = (raw_event as Dictionary).duplicate(true)
		var event_id: String = String(event.get("id", ""))
		if event_id == "":
			validation_messages.append("Event missing id.")
			continue
		events_by_id[event_id] = event


func _ingest_pois(raw_pois: Array) -> void:
	for raw_poi: Variant in raw_pois:
		if not (raw_poi is Dictionary):
			validation_messages.append("POI entry is not an object.")
			continue

		var poi: Dictionary = (raw_poi as Dictionary).duplicate(true)
		var poi_id: String = String(poi.get("id", ""))
		if poi_id == "":
			validation_messages.append("POI missing id.")
			continue

		pois_by_id[poi_id] = poi


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
