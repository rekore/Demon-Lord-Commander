extends Node

const SHOP_SIZE: int = 3
const REROLL_BASE_COST: int = 50
const REROLL_COST_INCREASE: int = 25

const RARITY_WEIGHTS: Dictionary = {
	"common": 100,
	"uncommon": 60,
	"rare": 25,
	"epic": 10,
	"legendary": 3
}


func _ready() -> void:
	SignalBus.battle_start_requested.connect(_on_battle_start_requested)
	SignalBus.battle_ended.connect(_on_battle_ended)


func _on_battle_start_requested(_battle_id: String, _payload: Dictionary) -> void:
	refresh_shop()


func _on_battle_ended(_victory: bool, _rewards: Dictionary) -> void:
	tick_relic_durations()


func refresh_shop() -> void:
	var all_relics: Array = ContentDB.get_all_relics()
	var owned: Array = SaveManager.profile.get("owned_relics", [])

	var available: Array = []
	for raw_relic: Variant in all_relics:
		if not (raw_relic is Dictionary):
			continue
		var relic: Dictionary = raw_relic as Dictionary
		if not owned.has(String(relic.get("id", ""))):
			available.append(relic)

	var picked: Array = _weighted_pick(available, SHOP_SIZE)
	var inventory: Array = []
	for r: Variant in picked:
		inventory.append(String((r as Dictionary).get("id", "")))

	SaveManager.profile["shop_inventory"] = inventory
	SaveManager.profile["shop_reroll_count"] = 0
	SaveManager.save_profile()


func reroll_shop() -> bool:
	var reroll_count: int = int(SaveManager.profile.get("shop_reroll_count", 0))
	var cost: int = get_reroll_cost()
	var gold: int = int(SaveManager.profile.get("gold", 0))
	if gold < cost:
		return false
	SaveManager.profile["gold"] = gold - cost
	SaveManager.profile["shop_reroll_count"] = reroll_count + 1
	refresh_shop()
	return true


func get_reroll_cost() -> int:
	var reroll_count: int = int(SaveManager.profile.get("shop_reroll_count", 0))
	return REROLL_BASE_COST + reroll_count * REROLL_COST_INCREASE


func _weighted_pick(candidates: Array, count: int) -> Array:
	var picked: Array = []
	var pool: Array = candidates.duplicate()
	for _i: int in range(mini(count, pool.size())):
		var total_weight: int = 0
		for raw_r: Variant in pool:
			var rarity: String = String((raw_r as Dictionary).get("rarity", "common"))
			total_weight += int(RARITY_WEIGHTS.get(rarity, 50))
		var roll: int = randi() % maxi(total_weight, 1)
		var cumulative: int = 0
		for j: int in range(pool.size()):
			var rarity: String = String((pool[j] as Dictionary).get("rarity", "common"))
			cumulative += int(RARITY_WEIGHTS.get(rarity, 50))
			if roll < cumulative:
				picked.append(pool[j])
				pool.remove_at(j)
				break
	return picked


func get_shop_inventory() -> Array:
	var ids: Array = SaveManager.profile.get("shop_inventory", [])
	var result: Array = []
	for raw_id: Variant in ids:
		var relic_id: String = String(raw_id) if raw_id != null else ""
		var relic: Dictionary = ContentDB.get_relic(relic_id)
		if not relic.is_empty():
			result.append(relic)
	return result


func buy_relic(relic_id: String) -> bool:
	var inventory: Array = SaveManager.profile.get("shop_inventory", [])
	if not inventory.has(relic_id):
		return false

	var relic_data: Dictionary = ContentDB.get_relic(relic_id)
	if relic_data.is_empty():
		return false

	var cost: int = int(relic_data.get("cost", 0))
	var gold: int = int(SaveManager.profile.get("gold", 0))
	if gold < cost:
		return false
	SaveManager.profile["gold"] = gold - cost

	var duration: int = int(relic_data.get("duration", 1))

	var owned: Array = SaveManager.profile.get("owned_relics", [])
	owned.append(relic_id)
	inventory.erase(relic_id)

	var active: Array = SaveManager.profile.get("active_relics", [])
	active.append({ "id": relic_id, "missions_remaining": duration })

	SaveManager.profile["owned_relics"] = owned
	SaveManager.profile["shop_inventory"] = inventory
	SaveManager.profile["active_relics"] = active
	SaveManager.save_profile()
	SignalBus.broadcast_relic_purchased(relic_id)
	return true


func tick_relic_durations() -> void:
	var active: Array = SaveManager.profile.get("active_relics", [])
	var still_active: Array = []
	for raw_entry: Variant in active:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = (raw_entry as Dictionary).duplicate()
		var remaining: int = int(entry.get("missions_remaining", 0)) - 1
		if remaining > 0:
			entry["missions_remaining"] = remaining
			still_active.append(entry)
	SaveManager.profile["active_relics"] = still_active
	SaveManager.save_profile()


func get_active_relic_buffs() -> Array:
	var active: Array = SaveManager.profile.get("active_relics", [])
	var buffs: Array = []
	for raw_entry: Variant in active:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var relic_id: String = String(entry.get("id", ""))
		var relic_data: Dictionary = ContentDB.get_relic(relic_id)
		if relic_data.is_empty():
			continue
		var effect: Variant = relic_data.get("effect", null)
		if effect is Dictionary:
			buffs.append((effect as Dictionary).duplicate())
	return buffs


func get_owned_relics() -> Array:
	var ids: Array = SaveManager.profile.get("owned_relics", [])
	var result: Array = []
	for raw_id: Variant in ids:
		var relic_id: String = String(raw_id) if raw_id != null else ""
		var relic: Dictionary = ContentDB.get_relic(relic_id)
		if not relic.is_empty():
			result.append(relic)
	return result
