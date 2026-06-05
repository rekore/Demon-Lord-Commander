extends RefCounted

class_name LocationService


static func get_active_event(location_id: String) -> Dictionary:
	var location: Dictionary = ContentDB.get_location(location_id)
	if location.is_empty():
		return {}

	var events: Array = location.get("events", [])
	if events.is_empty():
		return {}

	# Sort by priority descending (highest first)
	var sorted_events: Array = events.duplicate()
	sorted_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(b.get("priority", 0)) < int(a.get("priority", 0))
	)

	for raw_event: Variant in sorted_events:
		if not (raw_event is Dictionary):
			continue
		var event: Dictionary = raw_event as Dictionary
		var conditions: Array = event.get("conditions", [])
		if _conditions_met(conditions):
			return event

	return {}


static func _conditions_met(conditions: Array) -> bool:
	for condition: Variant in conditions:
		if not (condition is String):
			continue
		if not check_condition(condition):
			return false
	return true


static func check_condition(condition: String) -> bool:
	var story_flags: Dictionary = GameState.story_flags

	if condition.begins_with("flag:"):
		var flag_name: String = condition.substr(5)
		return story_flags.get(flag_name, false)

	if condition.begins_with("!flag:"):
		var flag_name: String = condition.substr(6)
		return not story_flags.get(flag_name, false)

	if condition.begins_with("bond:"):
		var parts: PackedStringArray = condition.substr(5).split("_")
		if parts.size() < 2:
			return false
		var waifu_id: String = "waifu_" + parts[0]
		var required_level: int = int(parts[1])
		return SaveManager.get_bond_level(waifu_id) >= required_level

	push_warning("LocationService: unknown condition format: %s" % condition)
	return false


static func is_location_visible(location_id: String) -> bool:
	var location: Dictionary = ContentDB.get_location(location_id)
	if location.is_empty():
		return false

	var unlock_value: Variant = location.get("unlock_condition", "")
	var unlock_condition: String = String(unlock_value) if unlock_value != null else ""
	if unlock_condition == "":
		return true

	return check_condition(unlock_condition)


static func is_fog_region_revealed(region_id: String) -> bool:
	for raw_region: Variant in ContentDB.get_map_fog_regions():
		if not (raw_region is Dictionary):
			continue
		var region: Dictionary = raw_region as Dictionary
		var id_value: Variant = region.get("id", "")
		var id_str: String = String(id_value) if id_value != null else ""
		if id_str != region_id:
			continue
		var unlock_value: Variant = region.get("unlock_condition", "")
		var unlock_condition: String = String(unlock_value) if unlock_value != null else ""
		if unlock_condition == "":
			return true
		return check_condition(unlock_condition)
	return false


static func is_poi_visible(poi_id: String) -> bool:
	if not is_poi_discovered(poi_id):
		return false

	var poi: Dictionary = ContentDB.get_poi(poi_id)
	if poi.is_empty():
		return false

	var unlock_value: Variant = poi.get("unlock_condition", "")
	var unlock_condition: String = String(unlock_value) if unlock_value != null else ""
	if unlock_condition == "":
		return true
	return check_condition(unlock_condition)


static func is_poi_discovered(poi_id: String) -> bool:
	var discovered: Array = SaveManager.profile.get("discovered_pois", [])
	return discovered.has(poi_id)


static func discover_poi(poi_id: String) -> bool:
	if is_poi_discovered(poi_id):
		return false

	var poi: Dictionary = ContentDB.get_poi(poi_id)
	if poi.is_empty():
		push_warning("LocationService: tried to discover unknown POI '%s'" % poi_id)
		return false

	var discovered: Array = SaveManager.profile.get("discovered_pois", [])
	discovered.append(poi_id)
	SaveManager.profile["discovered_pois"] = discovered
	SaveManager.save_profile()
	SignalBus.poi_discovered.emit(poi_id)
	return true
