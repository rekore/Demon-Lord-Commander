extends Node

# =============================================================================
# DungeonService — Authoritative owner of dungeon run state.
# =============================================================================
#
# WHAT THIS DOES:
#   Starts/ends dungeon runs, generates per-floor node choices, tracks floor
#   progress, stores the pending node before a battle, and exposes scaling
#   values (damage_multiplier, player_penalties) to BattleSetupService.
#
# ARCHITECTURE RULES:
#   - Never mutate SaveManager["current_dungeon_run"] from outside this service.
#   - Always call start_run(), complete_node(), or fail_run() — never write directly.
#   - UI emits SignalBus.request_dungeon_node_select(node_data); this service listens.
#
# HOW TO TRIGGER A DUNGEON:
#   SignalBus.request_dungeon_run("dungeon_catacombs")
#   — OR — emit Dialogic signal "start_dungeon_catacombs" (MainController handles it).
#
# HOW TO SET DUNGEON LEVEL VIA A STORY FLAG:
#   In a story event script or Dialogic callback:
#     SaveManager.profile["story_flags"]["dungeon_catacombs_difficulty_level"] = 2
#     SaveManager.save_profile()
#   The next call to start_run("dungeon_catacombs") will run at level 2.
#   The flag key must match the "level_flag" field in dungeons.json for that dungeon.
#
# HOW TO TRIGGER A STORY BOSS:
#   In a story event:
#     SaveManager.profile["story_flags"]["dungeon_catacombs_story_boss_queued"] = true
#     SaveManager.save_profile()
#   When the boss floor is generated, DungeonService checks story_boss_flags in
#   dungeons.json in order. The first matching active flag wins.
#   If consume_flag = true, the flag is cleared after the node is generated (one-shot).
#
# HOW TO ADD A NEW DUNGEON:
#   1. Add an entry in data/dungeons.json (see _dev_notes in that file).
#   2. Add enemy IDs to normal/elite/boss pools (defined in data/enemies.json).
#   3. Add floor_configs covering floors 1..(boss_floor-1). Uncovered floors fall back
#      to pure battle_normal.
#   4. Optionally set level_flag to a story flag key so the dungeon scales with chapters.
#   5. Add a POI in data/pois.json or a Dialogic signal in MainController.
#
# HOW TO ADD A NEW NODE TYPE:
#   1. Add labels to NODE_LABELS dict below.
#   2. Add icon path to NODE_TYPE_ICONS dict below.
#   3. Add a handler case in MainController._on_dungeon_node_selected().
#   4. Add TYPE_DISPLAY entry in dungeon_choice_screen.gd.
#   5. Use the new type string as a weight key in dungeons.json floor_configs.
#
# BOSS ENEMY PRIORITY ORDER:
#   1. story_boss_flags (first active flag in the array wins)
#   2. scripted_boss    (non-empty string always wins, flag-independent)
#   3. boss_pool        (random pick)
#
# PLAYER PENALTY FORMULA (applied per level above 1):
#   draw_reduction = floori((level-1) / PENALTY_DRAW_DIVISOR)
#   mana_reduction = floori((level-1) / PENALTY_MANA_DIVISOR)
#   Adjust the PENALTY_* consts below to tune difficulty.
#   Penalties clamp to PENALTY_MAX_DRAW / PENALTY_MAX_MANA minimums.
# =============================================================================
#
# Boss resolution priority: story_boss_flags → scripted_boss → boss_pool (random).
# Forced floors: floor_config with forced_type produces a single-card floor (no choice).

const SCALE_PER_LEVEL: float = 0.15

# ---------------------------------------------------------------------------
# Floor count scaling.
# base_floors in dungeons.json is the floor count at level 1.
# Every FLOOR_LEVEL_INTERVAL levels adds FLOOR_LEVEL_BONUS floors, clamped to [MIN_FLOORS, MAX_FLOORS].
# External modifiers (relics, story events) call add_floor_modifier(n) to adjust floor_bonus,
# which is added AFTER the level clamp so it can push beyond MAX_FLOORS if intended.
# ---------------------------------------------------------------------------
const MIN_FLOORS: int = 15
const MAX_FLOORS: int = 50
const FLOOR_LEVEL_INTERVAL: int = 5
const FLOOR_LEVEL_BONUS: int = 2

# ---------------------------------------------------------------------------
# Dungeon levels range from 1 to 100.
# Player penalty formula below is a PLACEHOLDER — full 1-100 penalty curve is TODO.
# Current formula gives mild penalties early and caps at small values.
# Adjust PENALTY_* consts when the full penalty design is ready.
# ---------------------------------------------------------------------------
const PENALTY_DRAW_DIVISOR: int = 3
const PENALTY_MANA_DIVISOR: int = 4
const PENALTY_MAX_DRAW: int = 3
const PENALTY_MAX_MANA: int = 2

# ---------------------------------------------------------------------------
# Adaptive weight system — history tracking and balancing rules.
#
# HISTORY_WINDOW     : how many recently completed floor types to keep.
# MIN_WEIGHT_AFTER_SUPPRESS : floor value for suppressed types that already exist
#                             in the base weights. Prevents a type dropping to 0
#                             by suppression alone.
#
# ADAPTIVE_RULES: each rule fires when its condition is true and adds its
# adjustments to the base weights for that floor.
#   type "streak"  — fires when match_types appear >= min_count times in last 'window' floors.
#   type "absence" — fires when NONE of match_types appear in last 'window' floors.
#                    Only fires when history has >= 'window' entries (avoids false positives
#                    on the very first floor of a run).
#   adjustments    — applied on top of base weights from floor_config.
#                    Positive = boost, negative = suppress.
#                    Types already in base_weights are clamped to MIN_WEIGHT_AFTER_SUPPRESS.
#                    Types NOT in base_weights are added only when final delta > 0
#                    (allows recovery nodes to appear on combat-only floors in emergencies).
#   label          — human-readable name for debugging / future UI display.
#
# Rules are cumulative — multiple can fire on the same floor.
# To add a new rule: copy an entry and adjust types/min_count/window/adjustments.
# ---------------------------------------------------------------------------
const HISTORY_WINDOW: int = 5
const MIN_WEIGHT_AFTER_SUPPRESS: int = 5

const ADAPTIVE_RULES: Array = [
	# --- STREAK GUARDS: prevent brutal monotony ---
	{
		"label": "elite_boss_streak",
		"type": "streak",
		"match_types": ["battle_elite", "battle_boss"],
		"min_count": 2,
		"window": 3,
		"adjustments": {"rest": 50, "event": 25, "bond": 15}
	},
	{
		"label": "heavy_combat_streak",
		"type": "streak",
		"match_types": ["battle_normal", "battle_elite"],
		"min_count": 3,
		"window": 4,
		"adjustments": {"rest": 35, "event": 15}
	},
	# --- OVERUSE GUARDS: prevent coasting on easy nodes ---
	{
		"label": "rest_overuse",
		"type": "streak",
		"match_types": ["rest"],
		"min_count": 2,
		"window": 3,
		"adjustments": {"rest": -50, "battle_normal": 20}
	},
	{
		"label": "bond_overuse",
		"type": "streak",
		"match_types": ["bond"],
		"min_count": 2,
		"window": 4,
		"adjustments": {"bond": -60}
	},
	# --- DROUGHT GUARDS: prevent long stretches without a type ---
	{
		"label": "combat_drought",
		"type": "absence",
		"match_types": ["battle_normal", "battle_elite"],
		"window": 3,
		"adjustments": {"battle_normal": 40, "battle_elite": 20}
	},
	{
		"label": "event_drought",
		"type": "absence",
		"match_types": ["event"],
		"window": 4,
		"adjustments": {"event": 20}
	}
]

const NODE_LABELS: Dictionary = {
	"battle_normal": [
		"Shadowed Passage", "Distant Scraping", "Flickering Torchlight",
		"Uneasy Silence", "Muffled Movement"
	],
	"battle_elite": [
		"A Heavy Presence", "Iron Stench", "Armoured Steps",
		"Something Powerful Waits", "Cold Air Ahead"
	],
	"battle_boss": [
		"Final Chamber", "The End of the Path", "Darkness Absolute"
	],
	"event": [
		"A Strange Discovery", "Scattered Remains",
		"Forgotten Writings", "An Odd Glow"
	],
	"bond": [
		"A Familiar Presence", "She's Here", "A Quiet Moment",
		"Her Voice in the Dark", "Something Stirs"
	],
	"rest": [
		"Quiet Corner", "Brief Respite", "Dying Embers", "Crumbling Alcove"
	]
}

const NODE_TYPE_ICONS: Dictionary = {
	"battle_normal": "res://assets/art/ui/icons/dungeon/battle_normal.png",
	"battle_elite":  "res://assets/art/ui/icons/dungeon/battle_elite.png",
	"battle_boss":   "res://assets/art/ui/icons/dungeon/battle_boss.png",
	"event":         "res://assets/art/ui/icons/dungeon/event.png",
	"bond":          "res://assets/art/ui/icons/dungeon/bond.png",
	"rest":          "res://assets/art/ui/icons/dungeon/rest.png"
}


func _ready() -> void:
	SignalBus.dungeon_node_selected.connect(_on_dungeon_node_selected)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func is_run_active() -> bool:
	var run: Dictionary = _get_run()
	return String(run.get("run_status", "none")) == "in_progress"


func get_current_run() -> Dictionary:
	return _get_run().duplicate(true)


func start_run(dungeon_id: String) -> void:
	var dungeon: Dictionary = ContentDB.get_dungeon(dungeon_id)
	if dungeon.is_empty():
		push_warning("DungeonService: Unknown dungeon id '%s'" % dungeon_id)
		return

	var dungeon_level: int = _resolve_dungeon_level(dungeon)
	var computed_floors: int = _compute_total_floors(dungeon, dungeon_level, 0)
	var run: Dictionary = {
		"dungeon_id": dungeon_id,
		"dungeon_level": dungeon_level,
		"current_floor": 0,
		"run_status": "in_progress",
		"pending_node": {},
		"floor_history": [],
		"total_floors": computed_floors,
		"boss_floor": computed_floors,
		"floor_bonus": 0
	}
	SaveManager.profile["current_dungeon_run"] = run
	SaveManager.save_profile()

	var choices: Array = _generate_choices(dungeon, run, 1, [])
	SignalBus.broadcast_dungeon_choices_ready(choices)


func complete_node() -> void:
	var run: Dictionary = _get_run()
	if String(run.get("run_status", "none")) != "in_progress":
		return

	var pending_node: Dictionary = run.get("pending_node", {})
	var was_boss: bool = bool(pending_node.get("is_boss", false))
	var dungeon_id: String = String(run.get("dungeon_id", ""))

	# Record completed node type in floor history (boss nodes end the run, not recorded).
	var node_type: String = String(pending_node.get("type", ""))
	if node_type != "" and not was_boss:
		var history: Array = run.get("floor_history", []).duplicate()
		history.append(node_type)
		if history.size() > HISTORY_WINDOW:
			history = history.slice(history.size() - HISTORY_WINDOW)
		run["floor_history"] = history

	if was_boss:
		run["run_status"] = "completed"
		_save_run(run)
		SignalBus.broadcast_dungeon_run_completed(dungeon_id)
		return

	_save_run(run)
	var dungeon: Dictionary = ContentDB.get_dungeon(dungeon_id)
	var current_floor: int = int(run.get("current_floor", 0))
	var next_floor: int = current_floor + 1
	var floor_history: Array = run.get("floor_history", [])
	var choices: Array = _generate_choices(dungeon, run, next_floor, floor_history)
	SignalBus.broadcast_dungeon_choices_ready(choices)


func fail_run() -> void:
	var run: Dictionary = _get_run()
	var dungeon_id: String = String(run.get("dungeon_id", ""))
	run["run_status"] = "failed"
	run["pending_node"] = {}
	_save_run(run)
	SignalBus.broadcast_dungeon_run_failed(dungeon_id)


func get_damage_multiplier() -> float:
	var run: Dictionary = _get_run()
	if String(run.get("run_status", "none")) != "in_progress":
		return 1.0
	var dungeon_level: int = int(run.get("dungeon_level", 1))
	return 1.0 + float(dungeon_level - 1) * SCALE_PER_LEVEL


# Returns the player penalties dict for the active run.
# Injected into the battle setup payload by BattleSetupService so BattleController
# can apply them without querying DungeonService directly at battle runtime.
func get_player_penalties() -> Dictionary:
	var run: Dictionary = _get_run()
	if String(run.get("run_status", "none")) != "in_progress":
		return {}
	var dungeon_level: int = int(run.get("dungeon_level", 1))
	if dungeon_level <= 1:
		return {}
	var level_above_base: int = dungeon_level - 1
	return {
		"draw_reduction": mini(level_above_base / PENALTY_DRAW_DIVISOR, PENALTY_MAX_DRAW),
		"mana_reduction": mini(level_above_base / PENALTY_MANA_DIVISOR, PENALTY_MAX_MANA)
	}


# Adds or removes floors from the active run at runtime.
# Positive = more floors, negative = fewer (minimum stays MIN_FLOORS).
# Called by relic effects or story events — e.g. DungeonService.add_floor_modifier(3).
# The bonus is applied AFTER the level-based clamp, so it can push beyond MAX_FLOORS.
func add_floor_modifier(amount: int) -> void:
	var run: Dictionary = _get_run()
	if String(run.get("run_status", "none")) != "in_progress":
		return
	var new_bonus: int = int(run.get("floor_bonus", 0)) + amount
	run["floor_bonus"] = new_bonus
	var dungeon: Dictionary = ContentDB.get_dungeon(String(run.get("dungeon_id", "")))
	var new_total: int = _compute_total_floors(dungeon, int(run.get("dungeon_level", 1)), new_bonus)
	run["total_floors"] = new_total
	run["boss_floor"] = new_total
	_save_run(run)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_dungeon_node_selected(node_data: Dictionary) -> void:
	var run: Dictionary = _get_run()
	if String(run.get("run_status", "none")) != "in_progress":
		return
	run["pending_node"] = node_data.duplicate()
	run["current_floor"] = int(node_data.get("floor", int(run.get("current_floor", 0))))
	_save_run(run)


# ---------------------------------------------------------------------------
# Choice generation
# ---------------------------------------------------------------------------

func _generate_choices(dungeon: Dictionary, run: Dictionary, floor_num: int, floor_history: Array) -> Array:
	var total_floors: int = int(run.get("total_floors", MIN_FLOORS))
	var boss_floor: int = int(run.get("boss_floor", total_floors))
	var dungeon_level: int = int(run.get("dungeon_level", 1))

	# Boss floor always produces a single forced boss card.
	if floor_num >= boss_floor:
		return [_build_node(dungeon, "battle_boss", floor_num, dungeon_level, true, "")]

	var floor_config: Dictionary = _get_floor_config(dungeon, floor_num)

	# forced_type: story-locked floor — single card, no adaptive adjustments applied.
	if floor_config.has("forced_type"):
		var forced_type: String = String(floor_config.get("forced_type", "battle_normal"))
		var forced_enemy: String = String(floor_config.get("forced_enemy_id", ""))
		return [_build_node(dungeon, forced_type, floor_num, dungeon_level, false, forced_enemy)]

	# Normal floor: apply adaptive balancing then pick 3 weighted random choices.
	var base_weights: Dictionary = floor_config.get("weights", {"battle_normal": 100})
	var weights: Dictionary = _apply_adaptive_weights(base_weights, floor_history)
	var choices: Array = []
	var used_labels: Array = []

	for _i: int in range(3):
		var node_type: String = _weighted_pick_type(weights)
		var node: Dictionary = _build_node(dungeon, node_type, floor_num, dungeon_level, false, "")
		var label: String = String(node.get("label", ""))
		if used_labels.has(label):
			var label_pool: Array = NODE_LABELS.get(node_type, ["Unknown Encounter"])
			for candidate: String in label_pool:
				if not used_labels.has(candidate):
					node["label"] = candidate
					label = candidate
					break
		used_labels.append(label)
		choices.append(node)

	return choices


func _get_floor_config(dungeon: Dictionary, floor_num: int) -> Dictionary:
	var floor_configs: Array = dungeon.get("floor_configs", [])
	for raw_config: Variant in floor_configs:
		if not (raw_config is Dictionary):
			continue
		var config: Dictionary = raw_config as Dictionary
		var floor_min: int = int(config.get("floor_min", 1))
		var floor_max: int = int(config.get("floor_max", 999))
		if floor_num >= floor_min and floor_num <= floor_max:
			return config
	return {"weights": {"battle_normal": 100}}


func _weighted_pick_type(weights: Dictionary) -> String:
	var total: int = 0
	for raw_w: Variant in weights.values():
		total += int(raw_w)
	var roll: int = randi() % maxi(total, 1)
	var cumulative: int = 0
	for raw_key: Variant in weights.keys():
		cumulative += int(weights.get(raw_key, 0))
		if roll < cumulative:
			return String(raw_key)
	return "battle_normal"


# Applies all matching ADAPTIVE_RULES on top of base_weights.
# Returns a new adjusted weights dict — base_weights is never mutated.
func _apply_adaptive_weights(base_weights: Dictionary, floor_history: Array) -> Dictionary:
	if base_weights.is_empty():
		return base_weights.duplicate()

	var adjusted: Dictionary = {}
	for raw_key: Variant in base_weights.keys():
		adjusted[String(raw_key)] = int(base_weights[raw_key])

	for raw_rule: Variant in ADAPTIVE_RULES:
		if not (raw_rule is Dictionary):
			continue
		var rule: Dictionary = raw_rule as Dictionary
		if not _rule_matches(rule, floor_history):
			continue
		var adjustments: Dictionary = rule.get("adjustments", {})
		for raw_key: Variant in adjustments.keys():
			var type_key: String = String(raw_key)
			var delta: int = int(adjustments[raw_key])
			if adjusted.has(type_key):
				adjusted[type_key] = maxi(MIN_WEIGHT_AFTER_SUPPRESS, adjusted[type_key] + delta)
			elif delta > 0:
				adjusted[type_key] = delta

	return adjusted


# Returns true when the given rule's condition is satisfied against floor_history.
func _rule_matches(rule: Dictionary, floor_history: Array) -> bool:
	var rule_type: String = String(rule.get("type", "streak"))
	var match_types: Array = rule.get("match_types", [])
	var window: int = int(rule.get("window", HISTORY_WINDOW))
	var recent: Array = _get_recent_history(floor_history, window)

	match rule_type:
		"streak":
			var min_count: int = int(rule.get("min_count", 2))
			var count: int = 0
			for raw_entry: Variant in recent:
				if String(raw_entry) in match_types:
					count += 1
			return count >= min_count
		"absence":
			# Require a full window of history to avoid triggering on the first floors.
			if recent.size() < window:
				return false
			for raw_entry: Variant in recent:
				if String(raw_entry) in match_types:
					return false
			return true

	return false


# Returns the last 'window' entries from history (or fewer if history is shorter).
func _get_recent_history(history: Array, window: int) -> Array:
	if history.is_empty():
		return []
	var start: int = maxi(0, history.size() - window)
	return history.slice(start)


# Picks one event from the level-eligible pool using weighted random selection.
# Returns an empty dict if no events are defined for the given level.
func _pick_event_for_level(dungeon_level: int) -> Dictionary:
	var pool: Array = ContentDB.get_events_for_level(dungeon_level)
	if pool.is_empty():
		return {}
	var total_weight: int = 0
	for raw_ev: Variant in pool:
		total_weight += int((raw_ev as Dictionary).get("weight", 1))
	var roll: int = randi() % maxi(total_weight, 1)
	var cumulative: int = 0
	for raw_ev: Variant in pool:
		var ev: Dictionary = raw_ev as Dictionary
		cumulative += int(ev.get("weight", 1))
		if roll < cumulative:
			return ev
	return pool[pool.size() - 1] as Dictionary


func _build_node(dungeon: Dictionary, node_type: String, floor_num: int, dungeon_level: int, is_boss: bool, forced_enemy_id: String) -> Dictionary:
	var enemy_id: String = _pick_enemy_for_type(dungeon, node_type, forced_enemy_id)
	var label_pool: Array = NODE_LABELS.get(node_type, ["Unknown Encounter"])
	var label: String = String(label_pool[randi() % label_pool.size()])

	var node: Dictionary = {
		"type": node_type,
		"enemy_id": enemy_id,
		"dungeon_id": String(dungeon.get("id", "")),
		"dungeon_level": dungeon_level,
		"floor": floor_num,
		"label": label,
		"icon_path": String(NODE_TYPE_ICONS.get(node_type, "")),
		"is_boss": is_boss,
		"event_id": "",
		"event_name": "",
		"event_description": ""
	}

	# For event nodes: pre-select a level-appropriate event for routing purposes.
	# The event identity is intentionally NOT shown on the choice card — blind pick.
	if node_type == "event":
		var event: Dictionary = _pick_event_for_level(dungeon_level)
		if not event.is_empty():
			node["event_id"] = String(event.get("id", ""))
			node["event_name"] = String(event.get("name", ""))
			node["event_description"] = String(event.get("description", ""))

	return node


func _pick_enemy_for_type(dungeon: Dictionary, node_type: String, forced_enemy_id: String) -> String:
	# Explicit override always wins (forced_type floor or external caller).
	if forced_enemy_id != "":
		return forced_enemy_id

	var pool: Array = []
	match node_type:
		"battle_normal":
			pool = dungeon.get("normal_enemy_pool", [])
		"battle_elite":
			pool = dungeon.get("elite_enemy_pool", [])
		"battle_boss":
			# 1. Story flag overrides (conditional, checked in order).
			var story_enemy: String = _check_story_boss_flags(dungeon)
			if story_enemy != "":
				return story_enemy
			# 2. Scripted boss (always-override, no flag condition).
			var scripted: String = String(dungeon.get("scripted_boss", ""))
			if scripted != "":
				return scripted
			# 3. Random from boss pool.
			pool = dungeon.get("boss_pool", [])
		_:
			return ""

	if pool.is_empty():
		return ""
	return String(pool[randi() % pool.size()])


func _check_story_boss_flags(dungeon: Dictionary) -> String:
	var flag_entries: Array = dungeon.get("story_boss_flags", [])
	var story_flags: Dictionary = SaveManager.profile.get("story_flags", {})

	for raw_entry: Variant in flag_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var flag_key: String = String(entry.get("flag", ""))
		var enemy_id: String = String(entry.get("enemy_id", ""))
		if flag_key == "" or enemy_id == "":
			continue
		if bool(story_flags.get(flag_key, false)):
			if bool(entry.get("consume_flag", false)):
				story_flags[flag_key] = false
				SaveManager.profile["story_flags"] = story_flags
			return enemy_id

	return ""


# ---------------------------------------------------------------------------
# Loot generation
# ---------------------------------------------------------------------------

# Applies collected loot and the chosen card to SaveManager.
# Called by BattleVictoryScreen just before it emits dungeon_rewards_claimed.
func apply_loot_rewards(collected_items: Array, chosen_card: Dictionary) -> void:
	var materials: Dictionary = SaveManager.profile.get("materials", {})
	var trash: Dictionary = SaveManager.profile.get("trash", {})
	var consumables: Array = SaveManager.profile.get("consumables", [])
	var run: Dictionary = _get_run()
	var run_relics: Array = run.get("run_relics", [])

	for raw_item: Variant in collected_items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item as Dictionary
		var item_id: String = String(item.get("id", ""))
		var item_type: String = String(item.get("_pool_type", item.get("type", "trash")))

		match item_type:
			"trash":
				trash[item_id] = int(trash.get(item_id, 0)) + 1
			"material":
				materials[item_id] = int(materials.get(item_id, 0)) + 1
			"consumable", "card_pack":
				consumables.append(item.duplicate())
			"relic_run":
				run_relics.append(item.duplicate())

	SaveManager.profile["materials"] = materials
	SaveManager.profile["trash"] = trash
	SaveManager.profile["consumables"] = consumables
	if is_run_active():
		run["run_relics"] = run_relics
		_save_run(run)

	if not chosen_card.is_empty():
		var card_id: String = String(chosen_card.get("id", ""))
		if card_id != "":
			var deck: Array = SaveManager.profile.get("selected_deck_card_ids", [])
			deck.append(card_id)
			SaveManager.profile["selected_deck_card_ids"] = deck

	SaveManager.save_profile()


# Generates a complete loot payload for the just-completed battle node.
# Returns { gold, drops[], card_choices[] }
# gold is computed and written to SaveManager immediately.
# drops and card_choices are returned to the UI for player interaction —
# actual collection is applied when the player clicks items on the victory screen.
func generate_battle_loot(node_data: Dictionary) -> Dictionary:
	var dungeon_level: int = int(node_data.get("dungeon_level", 1))
	var node_type: String = String(node_data.get("type", "battle_normal"))
	var enemy_id: String = String(node_data.get("enemy_id", ""))
	var dungeon_id: String = String(node_data.get("dungeon_id", ""))
	var dungeon: Dictionary = ContentDB.get_dungeon(dungeon_id)

	# Gold — guaranteed, auto-collected at screen open.
	var gold_min: int = 10 + dungeon_level * 2
	var gold_max: int = 20 + dungeon_level * 4
	var gold_mult: float = 1.0
	match node_type:
		"battle_elite": gold_mult = 1.5
		"battle_boss":  gold_mult = 2.5
	var gold: int = floori(randi_range(gold_min, gold_max) * gold_mult)

	# Roll count — how many item drops to generate.
	var roll_min: int = 1
	var roll_max: int = 2
	match node_type:
		"battle_elite": roll_min = 2; roll_max = 3
		"battle_boss":  roll_min = 3; roll_max = 4
	var roll_count: int = randi_range(roll_min, roll_max)

	# Build pool and roll drops.
	var pool: Array = _build_loot_pool(dungeon_level, dungeon, enemy_id)
	var drops: Array = []
	for _i: int in range(roll_count):
		var picked: Dictionary = _loot_weighted_pick(pool)
		if not picked.is_empty():
			drops.append(picked.duplicate())

	# Card choices — probabilistic. Boss always rewards a card; normal/elite do not.
	var card_chance: float = 0.35
	match node_type:
		"battle_boss":  card_chance = 1.0
		"battle_elite": card_chance = 0.60
	var card_choices: Array = []
	if randf() < card_chance:
		card_choices = _pick_card_choices(dungeon_level, 3)

	return {
		"gold": gold,
		"drops": drops,
		"card_choices": card_choices
	}


# Builds the merged item pool: global items + dungeon local items + run relics,
# filtered by dungeon_level. Enemy bonus_drops adjust existing item weights.
func _build_loot_pool(dungeon_level: int, dungeon: Dictionary, enemy_id: String) -> Array:
	var pool: Array = []

	# Global items from loot_items.json.
	for raw: Variant in ContentDB.get_loot_items_for_level(dungeon_level):
		if raw is Dictionary:
			pool.append((raw as Dictionary).duplicate())

	# Dungeon-specific local items.
	var local_loot: Array = dungeon.get("local_loot", [])
	for raw: Variant in local_loot:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = (raw as Dictionary).duplicate()
		var min_lv: int = int(item.get("min_level", 1))
		if dungeon_level >= min_lv:
			pool.append(item)

	# Run relics as droppable items — tag them for UI handling.
	for raw: Variant in ContentDB.get_run_relics_for_level(dungeon_level):
		if not (raw is Dictionary):
			continue
		var relic: Dictionary = (raw as Dictionary).duplicate()
		relic["_pool_type"] = "relic_run"
		pool.append(relic)

	# Apply enemy bonus_drops weight adjustments.
	if enemy_id != "":
		var enemy_data: Dictionary = ContentDB.get_enemy(enemy_id)
		var bonus_drops: Array = enemy_data.get("bonus_drops", [])
		for raw_bonus: Variant in bonus_drops:
			if not (raw_bonus is Dictionary):
				continue
			var bonus: Dictionary = raw_bonus as Dictionary
			var target_id: String = String(bonus.get("id", ""))
			var weight_bonus: int = int(bonus.get("weight_bonus", 0))
			for item: Variant in pool:
				if item is Dictionary and String((item as Dictionary).get("id", "")) == target_id:
					(item as Dictionary)["weight"] = int((item as Dictionary).get("weight", 0)) + weight_bonus

	return pool


# Picks a single item from the pool using weighted random selection.
func _loot_weighted_pick(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var total: int = 0
	for raw: Variant in pool:
		if raw is Dictionary:
			total += int((raw as Dictionary).get("weight", 0))
	if total <= 0:
		return {}
	var roll: int = randi() % total
	var cumulative: int = 0
	for raw: Variant in pool:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		cumulative += int(item.get("weight", 0))
		if roll < cumulative:
			return item
	return pool[pool.size() - 1] as Dictionary


# Picks `count` unique cards from the full card pool, weighted by rarity.
# Basic-archetype cards are excluded from rewards (S1 / D1 starter cards).
# Rarity weights are boosted toward rarer cards at higher dungeon levels.
func _pick_card_choices(dungeon_level: int, count: int) -> Array:
	var all_cards: Array = ContentDB.get_all_cards()
	var pool: Array = []
	var weights: Array = []

	for raw: Variant in all_cards:
		if not (raw is Dictionary):
			continue
		var card: Dictionary = raw as Dictionary
		var archetypes: Array = card.get("archetype", [])
		if "basic" in archetypes:
			continue
		var rarity: String = String(card.get("rarity", "Common")).to_lower()
		var w: int = 60
		match rarity:
			"common":
				w = maxi(60 - dungeon_level, 20)
			"uncommon":
				w = mini(20 + dungeon_level, 50)
			"rare":
				w = mini(5 + dungeon_level / 2, 30)
			"legendary":
				w = mini(1 + dungeon_level / 5, 10)
		pool.append(card)
		weights.append(w)

	var choices: Array = []
	var used: Array = []
	for _i: int in range(count):
		if used.size() >= pool.size():
			break
		var avail_idx: Array = []
		var avail_w: Array = []
		for j: int in range(pool.size()):
			if j not in used:
				avail_idx.append(j)
				avail_w.append(weights[j])
		var total: int = 0
		for w: Variant in avail_w:
			total += int(w)
		if total <= 0:
			break
		var roll: int = randi() % total
		var cum: int = 0
		for k: int in range(avail_idx.size()):
			cum += int(avail_w[k])
			if roll < cum:
				used.append(avail_idx[k])
				choices.append(pool[avail_idx[k]])
				break

	return choices


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_run() -> Dictionary:
	var raw: Variant = SaveManager.profile.get("current_dungeon_run", {})
	if raw is Dictionary:
		return raw as Dictionary
	return {}


func _save_run(run: Dictionary) -> void:
	SaveManager.profile["current_dungeon_run"] = run
	SaveManager.save_profile()


# Computes the effective total floor count for a run.
# Level scaling is clamped to [MIN_FLOORS, MAX_FLOORS]; floor_bonus is added after and is uncapped.
func _compute_total_floors(dungeon: Dictionary, dungeon_level: int, floor_bonus: int) -> int:
	var base_floors: int = int(dungeon.get("base_floors", MIN_FLOORS))
	var level_bonus: int = ((dungeon_level - 1) / FLOOR_LEVEL_INTERVAL) * FLOOR_LEVEL_BONUS
	var scaled: int = clampi(base_floors + level_bonus, MIN_FLOORS, MAX_FLOORS)
	return maxi(MIN_FLOORS, scaled + floor_bonus)


# Reads the dungeon's level_flag from SaveManager.profile["story_flags"].
# If the flag is set to an integer >= 1, that value overrides the hardcoded "level".
# To set: SaveManager.profile["story_flags"][dungeon.level_flag] = 2
# See dungeons.json _dev_notes for full instructions.
func _resolve_dungeon_level(dungeon: Dictionary) -> int:
	var level_flag: String = String(dungeon.get("level_flag", ""))
	if level_flag != "":
		var story_flags: Dictionary = SaveManager.profile.get("story_flags", {})
		var flag_val: Variant = story_flags.get(level_flag, null)
		if flag_val != null:
			var level_from_flag: int = int(flag_val)
			if level_from_flag >= 1:
				return level_from_flag
	return int(dungeon.get("level", 1))
