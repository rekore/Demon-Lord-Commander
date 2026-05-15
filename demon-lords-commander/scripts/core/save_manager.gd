extends Node

const SAVE_PATH: String = "user://save_slot_1.json"

var profile: Dictionary = {}


func _ready() -> void:
	load_or_create_profile()


func load_or_create_profile() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var raw_text: String = FileAccess.get_file_as_string(SAVE_PATH)
		var parsed: Variant = JSON.parse_string(raw_text)
		if parsed is Dictionary:
			profile = _with_defaults(parsed as Dictionary)
			return

	profile = _default_profile()
	save_profile()


func save_profile() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(profile, "\t"))
	file.close()


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	profile = _default_profile()
	save_profile()
	print("Save file reset to defaults.")


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
		"selected_waifu_id": "waifu_nyx",
		"selected_sub_waifu_id": "waifu_lyra",
		"selected_enemy_id": "enemy_test_goblin",
		"selected_deck_card_ids": [
			"S1", "S1", "S1", "S1",
			"S1", "S1", "S1", "S1",
			"S1", "S1", "S1", "S1",
			"D1", "D1", "D1", "D1",
			"D1", "D1", "D1", "D1",
			"16", "16",
			"17", "17",
			"18", "18",
			"19", "19",
			"20", "20",
			"21", "21",
			"22", "22"
		],
		"waifu_bond_levels": {
			"waifu_chesy": 2,
			"waifu_nyx": 3,
			"waifu_lyra": 1
		}
	}
