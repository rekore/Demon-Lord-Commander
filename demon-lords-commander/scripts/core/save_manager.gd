extends Node

const MAX_SLOTS: int = 10

var profile: Dictionary = {}
var active_slot_index: int = -1


func _ready() -> void:
	load_or_create_profile()


func _get_slot_path(slot_index: int) -> String:
	return "user://save_slot_%d.json" % (slot_index + 1)


func load_or_create_profile() -> void:
	# Legacy: try slot 1 first, then fall back
	load_slot(0)


func has_slot(slot_index: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot_index))


func get_slot_metadata(slot_index: int) -> Dictionary:
	var path: String = _get_slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return { "exists": false }

	var raw_text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return { "exists": false }

	var data: Dictionary = parsed as Dictionary
	var waifu_value: Variant = data.get("selected_waifu_id", "waifu_nyx")
	var waifu_id: String = String(waifu_value) if waifu_value != null else "waifu_nyx"
	var waifu_data: Dictionary = ContentDB.get_waifu(waifu_id)
	var waifu_name_value: Variant = waifu_data.get("name", waifu_id)
	var waifu_name: String = String(waifu_name_value) if waifu_name_value != null else waifu_id
	var loc_value: Variant = data.get("current_location_id", "world_map")
	var location_id: String = String(loc_value) if loc_value != null else "world_map"
	var loc_data: Dictionary = ContentDB.get_location(location_id)
	var loc_name_value: Variant = loc_data.get("name", location_id)
	var location_name: String = String(loc_name_value) if loc_name_value != null else location_id

	return {
		"exists": true,
		"waifu_name": waifu_name,
		"location_name": location_name,
		"current_location_id": location_id
	}


func load_slot(slot_index: int) -> void:
	var path: String = _get_slot_path(slot_index)
	active_slot_index = slot_index

	if FileAccess.file_exists(path):
		var raw_text: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(raw_text)
		if parsed is Dictionary:
			profile = _with_defaults(parsed as Dictionary)
			return

	profile = _default_profile()
	save_slot(slot_index)


func save_slot(slot_index: int) -> void:
	var path: String = _get_slot_path(slot_index)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % path)
		return

	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	active_slot_index = slot_index


func create_new_profile_in_slot(slot_index: int) -> void:
	active_slot_index = slot_index
	profile = _default_profile()
	save_slot(slot_index)


func delete_slot(slot_index: int) -> void:
	var path: String = _get_slot_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if active_slot_index == slot_index:
		active_slot_index = -1
		profile = {}


func save_profile() -> void:
	if active_slot_index < 0:
		active_slot_index = 0
	save_slot(active_slot_index)


func reset_save() -> void:
	for i: int in range(MAX_SLOTS):
		var path: String = _get_slot_path(i)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	profile = _default_profile()
	active_slot_index = 0
	save_slot(0)
	print("All save slots reset to defaults.")


func get_selected_deck_card_ids() -> Array[String]:
	var deck_ids: Array = profile.get("selected_deck_card_ids", [])
	var casted: Array[String] = []
	for id_value: Variant in deck_ids:
		casted.append(String(id_value))
	return casted


func get_selected_enemy_id() -> String:
	return String(profile.get("selected_enemy_id", "enemy_test_goblin"))


func get_selected_waifu_id() -> String:
	return String(profile.get("selected_waifu_id", "waifu_nyx"))


func get_selected_sub_waifu_id() -> String:
	return String(profile.get("selected_sub_waifu_id", get_selected_waifu_id()))


func get_bond_level(waifu_id: String) -> int:
	var bonds: Dictionary = profile.get("waifu_bond_levels", {})
	return int(bonds.get(waifu_id, 1))


func _with_defaults(raw_profile: Dictionary) -> Dictionary:
	var merged: Dictionary = _default_profile()
	for key: Variant in raw_profile.keys():
		merged[key] = raw_profile[key]
	return merged


func _default_profile() -> Dictionary:
	return {
		"save_version": "0.1.0",
		"current_location_id": "world_map",
		"story_flags": {
			"tutorial_complete": true
		},
		"discovered_pois": ["poi_crestfall"],
		"gold": 300,
		"owned_relics": [],
		"shop_inventory": [],
		"shop_reroll_count": 0,
		"active_relics": [],
		"materials": {},
		"consumables": [],
		"trash": {},
		"current_dungeon_run": {
			"dungeon_id": "",
			"dungeon_level": 1,
			"current_floor": 0,
			"run_status": "none",
			"pending_node": {},
			"floor_history": [],
			"total_floors": 15,
			"boss_floor": 15,
			"floor_bonus": 0,
			"run_relics": []
		},
		"selected_waifu_id": "waifu_nyx",
		"selected_sub_waifu_id": "waifu_lyra",
		"selected_enemy_id": "enemy_test_goblin",
		"selected_deck_card_ids": [
			"S1", "S1", "S1", "S1",
			"S1", "S1", "S1", "S1",
			"S1", "S1", "S1", "S1",
			"D1", "D1", "D1", "D1",
			"D1", "D1", "D1", "D1",
			"9", "9",
			"25", "25",
			"16", "16",
			"17", "17",
			"18", "18",
			"19", "19",
			"20", "20",
			"21", "21",
			"22", "22",
			"23", "24"
		],
		"waifu_bond_levels": {
			"waifu_chesy": 2,
			"waifu_nyx": 3,
			"waifu_lyra": 1
		}
	}
