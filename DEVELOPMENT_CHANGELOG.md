# Development Changelog

This file tracks coding progress between long breaks.
After each meaningful session, add a new entry at the top.

## 2026-06-03 — Victory Screen Overhaul + Tooltip System

- Focus: Polish pass on the battle victory screen — conditional card rewards, priority-ordered loot sections, click-to-collect row layout, real card scene for rewards, card re-selection, and a game-wide tooltip autoload.

### New Files
- `scripts/core/tooltip_manager.gd` — global autoload registered as `TooltipManager`. `show_tooltip(body, title="")` renders an optional amber title + HSeparator + body text inside a `PanelContainer` (auto-sizes to content). 85% opacity dark background, 2px border, drop shadow. Follows cursor, clamps to viewport. Fade-in tween. `hide_tooltip()` instant-hides. Any node can call from `mouse_entered`/`mouse_exited`.

### Modified Files
- `scripts/core/dungeon_service.gd` — card rewards now probabilistic per node type: boss 100%, elite 60%, normal/test 35%. `card_choices` is empty array when no card is rolled — victory screen detects this and hides the card section entirely.
- `scripts/ui/battle_victory_screen.gd` — complete rewrite:
  - **Architecture**: `_build_ui()` now builds only the static skeleton (title + `_content_vbox` + separator + Continue). `set_loot()` dynamically inserts sections into `_content_vbox` at runtime.
  - **Section ordering**: rewards appear in priority order — RUN RELICS → CARD PACKS → CARD REWARD → MATERIALS → SPOILS (trash) → Gold. Each section is only added if that drop type actually exists.
  - **Loot rows**: each item is a full-width clickable `Panel` (68px tall, coloured left-accent border). Item name 28px, type badge + sell price right-aligned. Click anywhere on the row to collect. Slides in from left with stagger tween. Hover shows `TooltipManager` popup with item name as title and description as body.
  - **Take All**: single button below all item sections; only shown when drops exist. Updates to "All Taken ✓" when all rows collected.
  - **Card reward**: uses real `scenes/Card.tscn` instantiated at `CardSize.FULL`. Clicking a card highlights it green; others dim via `set_unplayable_tint`. Player can re-select any card freely until Continue is pressed — no lock-in on first click. Skip button keeps cards interactive so player can change their mind.
  - **Gold**: auto-collected on screen open, displayed at bottom as a label (not a section with rows).
  - **Tooltips on loot rows only** — card panels have no tooltip since the card already shows all its information.
- `project.godot` — `TooltipManager` registered as autoload after `DungeonService`.

### Architecture Notes
- `TooltipManager` lives on layer 128 (`CanvasLayer`) so it always renders above all game UI.
- `PanelContainer` used (not `Panel`) so the background correctly auto-sizes to label content — no circular size dependency.
- Card re-selection works because `_on_card_chosen` no longer has an early-return guard; it resets all cards to `MOUSE_FILTER_STOP` + `set_unplayable_tint(false)` before applying the new selection state.

---

## 2026-06-03 - Battle Victory Screen + Loot System

- Focus: Per-battle victory screen with click-to-collect loot, card reward choice, and a full tiered loot framework. Dungeon loop is now complete: battle → loot → card pick → next floor.

### New Files
- `data/loot_items.json` — global loot pool (13 items): 4 trash tiers, 4 materials (level-gated), 3 consumables, 2 card pack types. All items have `weight`, `min_level`, `sell_value`.
- `scenes/BattleVictoryScreen.tscn` + `scripts/ui/battle_victory_screen.gd` — full victory screen. Gold auto-collects on open. Loot items pop in with stagger animation (scale+fade tween). Each item is click-to-collect with visual confirmation. Card choice shows 3 rarity-weighted cards; player picks 1 or skips. Continue unlocks after card choice is resolved.

### Modified Files
- `data/relics.json` — added `relic_type` field to all entries (`shop` for existing 3). Added 5 new run relics (`relic_bloodied_fang`, `relic_bone_talisman`, `relic_cursed_ring`, `relic_void_pendant`, `relic_demon_heart`) — droppable from dungeon combat, last current run only, with `min_level` and `weight` for pool inclusion.
- `data/enemies.json` — added `bonus_drops[]` to each enemy. Goblin: boosts `goblin_ear`+`tattered_cloth`. Rogue Knight: boosts `cursed_iron`+`shadow_dust`+`rusted_scrap`.
- `data/dungeons.json` — added `local_loot[]` to `dungeon_catacombs`: 3 trash items + 3 materials unique to this zone (encourages players to visit different dungeons for different crafting stocks).
- `scripts/core/signal_bus.gd` — added `dungeon_rewards_claimed` signal + `broadcast_dungeon_rewards_claimed()`.
- `scripts/core/save_manager.gd` — added `materials: {}`, `consumables: []`, `trash: {}` to base profile; added `run_relics: []` inside `current_dungeon_run`.
- `scripts/core/content_db.gd` — added `LOOT_ITEMS_PATH`, `loot_items_by_id` dict, `_ingest_loot_items()`, `get_loot_item()`, `get_loot_items_for_level()`, `get_all_cards()`, `get_run_relics_for_level()`.
- `scripts/core/dungeon_service.gd` — added `apply_loot_rewards(items, card)`, `generate_battle_loot(node_data)`, `_build_loot_pool()`, `_loot_weighted_pick()`, `_pick_card_choices()`. Loot scales with dungeon level + node type (normal/elite/boss). Pool = global + dungeon local + run relics + enemy bonus weight adjustments.
- `scripts/core/main_controller.gd` — preloads `BattleVictoryScreen`. `_on_victory_screen_requested` now generates loot from `pending_node` and shows victory screen instead of calling `complete_node()` directly. Connects `dungeon_rewards_claimed` → `complete_node()`.

### Architecture Notes
- **Three relic tiers**: `shop` (bought, multi-run), `run` (dropped, current run only), `crafted` (future hub crafting from materials).
- **Two-layer loot pool**: global items + dungeon local items + run relics merged at generation time. Enemy `bonus_drops` adjust weights for thematic drops.
- **Card reward pool**: excludes `basic` archetype (S1/D1 starter cards). Weights shift toward rarer cards at higher dungeon levels.
- **Architecture rule maintained**: UI (`BattleVictoryScreen`) calls `DungeonService.apply_loot_rewards()` then emits signal — service owns state mutation, UI owns presentation only.

---

## 2026-05-31 - Dungeon Run System Framework

- Focus: Build the complete framework for dungeon runs — scalable level system, 3-choice fog-of-war navigation, full signal/service/UI/routing pipeline.

### New Files
- `data/dungeons.json` — dungeon templates (id, name, level, floor count, boss floor, enemy pools, floor_configs with node-type weights per floor range). Seed dungeon: `dungeon_catacombs` (level 1, 5 floors).
- `scripts/core/dungeon_service.gd` — new autoload. Authoritative owner of run state (floor progress, pending node, run status). Generates weighted node choices, handles boss detection, emits `dungeon_choices_ready`/`dungeon_run_completed`/`dungeon_run_failed`. Connects to `dungeon_node_selected` to store pending node before battle.
- `scenes/DungeonChoiceScreen.tscn` + `scripts/ui/dungeon_choice_screen.gd` — post-battle choice screen showing 3 cards (1 for boss floor). Each card shows: type badge (COMBAT/ELITE/BOSS/EVENT/REST/SHOP) with colour, type-appropriate vague label for tension, floor number, Enter button. Built dynamically in script, populated via `set_choices()`.

### Modified Files
- `scripts/core/signal_bus.gd` — 5 new signals: `dungeon_run_requested`, `dungeon_choices_ready`, `dungeon_node_selected`, `dungeon_run_completed`, `dungeon_run_failed`. Helper functions for each.
- `scripts/core/save_manager.gd` — added `shop_reroll_count: 0` and `current_dungeon_run: {dungeon_id, dungeon_level, current_floor, run_status, pending_node}` to default profile.
- `scripts/core/content_db.gd` — added `DUNGEONS_PATH`, `dungeons_by_id` dict, `_ingest_dungeons()`, `get_dungeon()`, `get_all_dungeons()`. `reload_content()` now loads `dungeons.json`.
- `scripts/core/battle_setup_service.gd` — reads `dungeon_level` from battle payload. Applies scaling: `max_hp = floor(base_hp * (1 + (level-1) * 0.15))`. Injects `damage_multiplier` into each enemy dict in the payload.
- `scripts/battle/battle_controller.gd` — `_build_enemy_states` now reads and stores `damage_multiplier` from enemy_data into enemy_state.
- `scripts/battle/enemy_ai.gd` — `run_enemy_turn` duplicates intent params and scales `damage` by `enemy_state["damage_multiplier"]` (floor math) before executing the intent.
- `scripts/core/main_controller.gd` — preloads `DungeonChoiceScreen`. Connects 5 new dungeon signals. Overrides `_on_victory_screen_requested` and `_on_return_to_title_requested` to check `DungeonService.is_run_active()` — dungeon runs route to choice screen instead of victory/title. New handler `_on_dialogic_signal` case `"start_dungeon_catacombs"` wires Dialogic → dungeon start.
- `project.godot` — registered `DungeonService` as autoload.

### Dungeon Generator Refinement (same session)
- Removed `shop` from dungeon node types permanently — dungeons do not have shops.
- `rest` IS a valid dungeon node type (HP recovery breather floor) — restored. Green "REST" badge, "Rest" button. Stub auto-advances; TODO: rest screen with HP recovery.
- Added `bond` node type (non-combat waifu interaction scene, stubs to Dialogic later). Pink "BOND" badge, "Approach" button.
- **Story boss flags**: `dungeons.json` `story_boss_flags` array — `flag`, `enemy_id`, `consume_flag`. Priority: story_boss_flags → scripted_boss → boss_pool.
- **Forced floors**: `floor_configs` entry can use `forced_type` + optional `forced_enemy_id` instead of `weights` — single-card floor with no player choice.
- **Level flags**: each dungeon now has a `level_flag` string in `dungeons.json`. `DungeonService._resolve_dungeon_level()` reads that key from `SaveManager.profile["story_flags"]` at `start_run()`. If an integer >= 1 is stored there, it overrides the hardcoded `"level"` — dungeons scale with story chapter progression without editing JSON.
- **Player penalties**: `DungeonService.get_player_penalties()` returns `{draw_reduction, mana_reduction}` for the active run's level. Injected into battle payload by `BattleSetupService` as `dungeon_player_penalties`. `BattleController` reads it at battle start: mana penalty reduces `base_mana` permanently for that battle; draw penalty is subtracted from `STARTING_DRAW` every round (clamped to min 1). Formula: draw = floori((level-1)/3) max 3; mana = floori((level-1)/4) max 2.
- `_get_floor_config()` replaces `_get_floor_weights()` — returns full config dict.
- Added comprehensive header comment block in `dungeon_service.gd` explaining: how to trigger a dungeon, how to set level via a story flag, how to trigger a story boss, how to add a new dungeon, how to add a new node type, and the full boss priority chain.

### Adaptive Dungeon Generator + Level 1-100 Expansion (same session)
- **Dungeon levels now range 1–100**. Scaling formula and penalty consts are placeholders pending full 1-100 curve design.
- **`floor_history[]`** added to `current_dungeon_run` in `SaveManager`. Tracks last `HISTORY_WINDOW` (5) completed node types across the run. Persists through save/load. Boss nodes are never recorded.
- **`ADAPTIVE_RULES`** const array in `dungeon_service.gd` — 6 built-in rules, data-driven, easy to extend:
  - `elite_boss_streak` — 2+ elites/bosses in last 3 → boost rest +50, event +25, bond +15
  - `heavy_combat_streak` — 3+ combats in last 4 → boost rest +35, event +15
  - `rest_overuse` — 2+ rests in last 3 → suppress rest -50, boost normal +20
  - `bond_overuse` — 2+ bonds in last 4 → suppress bond -60
  - `combat_drought` — 0 combats in last 3 (requires full window) → boost normal +40, elite +20
  - `event_drought` — 0 events in last 4 (requires full window) → boost event +20
- **`_apply_adaptive_weights(base_weights, floor_history)`** — returns adjusted weight dict, never mutates base. New types introduced if delta > 0. Existing types clamped to `MIN_WEIGHT_AFTER_SUPPRESS` (5).
- Forced floors (`forced_type`) skip adaptive entirely — story intent always wins.
- `_generate_choices()` now takes `floor_history` as a parameter. `complete_node()` appends the completed node type before generating next choices.

### Tiered Event System (same session)
- **Enemy scaling confirmed already implemented**: `BattleSetupService` applies `1.0 + (level-1)*0.15` to both `max_hp` and `damage_multiplier` universally for ALL enemies. Every enemy in `enemies.json` scales automatically with dungeon level — no per-enemy code needed.
- **`data/events.json`** created — 10 events across 3 tiers:
  - **Level 1+** (common): Abandoned Camp, Mysterious Chest, Scavenged Supplies, Wounded Soldier
  - **Level 5+** (risky): Dark Altar, Forbidden Tome, Collapsed Shrine
  - **Level 10+** (extreme): The Demon's Bargain, The Void Rift, Cursed Idol
- Each event has `min_level`, `max_level`, `weight`, `category` (neutral/positive/negative/gamble), and a `choices` array with `effects` (typed effect objects for a future `EventService` to resolve).
- **`ContentDB`** already had `events_by_id`, `_ingest_events()`, `get_event()`, `get_events_for_level(dungeon_level)` — all pre-built and confirmed working.
- **`DungeonService._pick_event_for_level(dungeon_level)`** — weighted random selection from the level-eligible event pool.
- **`DungeonService._build_node()`** — event-type nodes now pre-select an event and store `event_id`, `event_name`, `event_description` in the node dict. The card `label` is set to the event name.
- **`DungeonChoiceScreen`** — event cards now show the event name as the title AND a one-sentence flavour description below it in teal. Players see "Dark Altar" / "Abandoned Camp" / "Void Rift" as distinct choices instead of three identical "EVENT" cards.
- Effect types defined in `events.json` (resolved by future `EventService`): `heal_percent`, `damage_percent_max`, `gain_gold`, `lose_gold`, `gain_strength`, `gain_max_hp_percent`, `lose_max_hp_percent`, `add_floor_modifier`, `gain_bond`, `nothing`.

### Dynamic Floor Count Scaling (same session)
- `base_floors` replaces `total_floors`/`boss_floor` in `dungeons.json` — the design-time value is now just the level-1 floor count.
- `dungeon_catacombs` updated to `base_floors: 15`. Floor configs expanded to cover floors 1–999 in 5 tiers.
- **Runtime formula**: `total = clamp(base_floors + floori((level-1)/5)*2, 15, 50) + floor_bonus`
  - Level 1 = 15 floors, grows +2 per 5 levels, caps at 50 at level ~93.
  - `floor_bonus` (starts 0) is applied after the clamp — can push beyond 50 if intended.
- `total_floors`, `boss_floor`, `floor_bonus` stored in `current_dungeon_run` run state (also added to `SaveManager` default profile).
- Boss is always the last floor (`boss_floor == total_floors`). Both update together.
- **`DungeonService.add_floor_modifier(amount)`** — public API for relics/story to change floor count mid-run. Recomputes `total_floors`/`boss_floor` and saves.
- **`DungeonService._compute_total_floors(dungeon, level, bonus)`** — private helper, used at `start_run()` and `add_floor_modifier()`.
- `_generate_choices()` now takes `run` dict as a parameter and reads `total_floors`/`boss_floor`/`dungeon_level` from it rather than the dungeon dict.

### Architecture Notes
- `DungeonService` owns all run state — never mutate `current_dungeon_run` from UI.
- Scaling is purely runtime — `enemies.json` base stats are never modified.
- `event` and `bond` node types auto-complete the node for now (stubs with `TODO` comments).
- To trigger a dungeon from Dialogic: emit signal `"start_dungeon_catacombs"` in a timeline.
- To add a new dungeon: add entry in `dungeons.json` and add a POI entry in `pois.json`.
- To set a story boss: set `SaveManager.profile["story_flags"]["your_flag_key"] = true` via a story event, and add the matching entry in that dungeon's `story_boss_flags` array.

## 2026-05-25 - Relic Shop System

- Focus:
  - Implement a full Relic Shop: data, service, UI, and battle integration
  - Shop opens via Dialogic signal from the `testshopkeeper` timeline in Crestfall
  - Relics apply passive buffs (GainStrength, GainBlock, DrawCards) at battle start for a limited number of missions
  - Shop shows 3 relics per visit, weighted by rarity; player can reroll for increasing gold cost

### Data

#### data/relics.json (new file)
  - Created `data/relics.json` with 3 starter relics: `relic_dark_sword`, `relic_dark_shield`, `relic_dark_choker`
  - Each relic has: `id`, `name`, `description`, `rarity`, `cost`, `duration`, `art_path`, `effect` (`type`, `value`, `trigger`)
  - `duration` = number of missions the relic stays active before expiring
  - `effect.trigger` = `start_of_battle`; supported `type` values: `GainStrength`, `GainBlock`, `DrawCards`
  - `_dev_notes` in JSON explain how to add new relics
  - Rarity values: `common`, `uncommon`, `rare`, `epic`, `legendary`

#### data/locations.json
  - Added `relic_shop` as a child location of `crestfall` with `dialogue_on_enter: "testshopkeeper"`
  - Clicking the Relic Shop location on the map triggers the shopkeeper timeline directly (no navigate)

#### scripts/core/save_manager.gd
  - Default profile now includes: `"gold": 300`, `"owned_relics": []`, `"shop_inventory": []`, `"active_relics": []`, `"shop_reroll_count": 0`
  - New saves start with 300 gold

### Backend Service

#### scripts/core/relic_shop_service.gd (new autoload)
  - `SHOP_SIZE = 3`, `REROLL_BASE_COST = 50`, `REROLL_COST_INCREASE = 25`
  - `RARITY_WEIGHTS`: common(100), uncommon(60), rare(25), epic(10), legendary(3)
  - `refresh_shop()`: picks 3 unowned relics by weighted rarity, resets reroll count, saves profile
  - `reroll_shop()`: deducts gold, increments reroll count, calls `refresh_shop()`; returns `false` if insufficient gold
  - `get_reroll_cost()`: `50 + reroll_count × 25`
  - `buy_relic(relic_id)`: checks inventory, checks gold affordability, deducts gold, adds to `active_relics` with `missions_remaining = duration`, adds to `owned_relics`, saves profile, emits `SignalBus.broadcast_relic_purchased`
  - `tick_relic_durations()`: called on `battle_ended` — decrements `missions_remaining`; removes expired relics
  - `get_active_relic_buffs()`: returns array of effect dictionaries from all active relics (for battle setup)
  - `get_shop_inventory()`: resolves IDs from save into full relic dictionaries via `ContentDB`
  - `_weighted_pick()`: weighted random selection without replacement using rarity weights
  - Registered as autoload `RelicShopService`

### ContentDB Integration

#### scripts/core/content_db.gd
  - Added `RELICS_PATH`, `relics_by_id` dictionary
  - `reload_content()` now loads `relics.json` via `_ingest_relics()`
  - Added `get_all_relics()` and `get_relic(relic_id)` helpers

### SignalBus

#### scripts/core/signal_bus.gd
  - Added `relic_shop_open_requested` signal + `request_relic_shop_open()` helper
  - Added `relic_purchased(relic_id: String)` signal + `broadcast_relic_purchased()` helper

### Battle Integration

#### scripts/core/battle_setup_service.gd
  - Battle payload now includes `"relic_buffs": RelicShopService.get_active_relic_buffs()`

#### scripts/battle/battle_controller.gd
  - Added `_relic_buffs: Array` populated from setup payload `"relic_buffs"`
  - `GainStrength` applied immediately to `_player_state["strength"]` before `_start_player_round()`
  - `DrawCards` applied to `STARTING_DRAW` count on round 1 only
  - `GainBlock` applied to `_player_state["block"]` on round 1 after block reset

### UI

#### scenes/RelicShopScreen.tscn (new scene) + scripts/ui/relic_shop_screen.gd (new script)
  - Overlay UI: `z_index = 10` ensures it renders above WorldMap `UIOverlay` (`z_index = 1`)
  - Dark overlay (`ColorRect` 82% opacity) blocks world map interaction
  - Layout: `OuterMargin` → `ShopArea` (HBox) → `PortraitPanel` (shopkeeper portrait + name) + `ShopPanel` (relics + buttons)
  - `ShopPanel` styled with `StyleBoxFlat` (dark purple, rounded corners, purple border)
  - Header row: title label + gold label (right-aligned, gold colour)
  - `RelicsContainer` (`HBoxContainer`, EXPAND_FILL): dynamically populated with relic cards
  - Each relic card: icon (180px min), name, rarity (colour-coded), duration, description, cost (gold), Buy button (140×44, centered)
  - Buy button → calls `RelicShopService.buy_relic()` only; service owns gold deduction (architecture rule compliance)
  - Button row: `RerollButton` + `rerolllabelcost` | expanding spacer | `CloseButton`
  - All interactive nodes use `unique_name_in_owner = true` (accessed via `%NodeName` in script)
  - Shop auto-calls `refresh_shop()` on open if `shop_inventory` is empty (first visit)
  - `MainTheme.tres` applied to each relic card for font consistency

#### scripts/core/main_controller.gd
  - Added `RELIC_SHOP_SCENE` preload
  - Connected `SignalBus.relic_shop_open_requested` → `_on_relic_shop_open_requested()`
  - Shop instantiated as full-rect overlay child of `_scene_host` (does not replace current scene)

#### scripts/ui/world_map_controller.gd
  - Removed `_update_actions()` call from `_refresh_ui()` — action buttons (talk, rest) removed from map
  - Back button retained; `_update_back_button()` still called normally

### Architecture Compliance
  - `RelicShopService` owns all gold mutation, relic ownership, and inventory state
  - `relic_shop_screen.gd` emits nothing to SignalBus directly for purchase — calls service only
  - `buy_relic()` is a single authoritative purchase gate (affordability + deduction + ownership in one call)

---

## 2026-05-24 - Game Loop, Viewport-Stable Buttons & Sub-Map Rendering

- Focus:
  - Wire the full New Game → World Map → Town → Home → Battle → Victory → Continue loop
  - Make POI/location buttons stay the same screen size regardless of map zoom
  - Fix interior sub-maps to render their background image at correct viewport size
  - Apply pan-margin only to world map; sub-maps hard-clamp to viewport edges

### Game Loop (New Game → Battle → Continue)

#### Interior Battle POIs (pois.json)
  - Added `parent_location_id` field to all POIs: `""` = world map, location ID = interior map
  - Added `action` field: `"navigate"` (default) or `"battle"`
  - Added `battle_id` and `enemy_id` fields for battle POIs
  - Added `poi_home_training` — interior battle POI for `home` location, triggers `tutorial_battle` vs `enemy_test_goblin`
  - Updated `_dev_notes` in `pois.json` to document the new schema

#### ContentDB
  - `get_map_pois()` now filters to world-map-only POIs (`parent_location_id == ""`)
  - Added `get_pois_for_location(location_id)` — returns all interior POIs for a given location

#### WorldMapController — Interior POI Rendering
  - `_show_interior_view()` now calls `_build_interior_poi_buttons()` to render interior POIs
  - `_build_interior_poi_buttons()` reads from `ContentDB.get_pois_for_location()`, builds buttons at their map coords
  - Battle-action POIs call `_on_interior_battle_poi_clicked(battle_id, enemy_id)` → `SignalBus.request_battle_start()`
  - Navigate-action POIs use the existing `_on_poi_clicked()` flow

#### VictoryScreen — Continue Button
  - Added "Continue" button to `VictoryScreen.tscn` next to "Return to Title"
  - `victory_screen.gd`: `_on_continue_pressed()` saves profile then calls `SignalBus.request_continue()`
  - `continue_requested` → `GameState._on_continue_requested()` → `PHASE_HUB` → world map resumes at saved location
  - Full loop confirmed: New Game → World Map → Town → Home → Battle → Victory → Continue → World Map

### Viewport-Stable POI/Location Buttons

#### Counter-Scale System (world_map_controller.gd)
  - All POI and location buttons store their center position in map coordinates as `map_pos` node metadata
  - `_update_poi_scales()` runs after every zoom/pan change (called from `_update_map_transform()`)
  - Each button's `scale` is set to `1/zoom_level` so its screen size stays constant regardless of zoom
  - Position is recalculated each frame: `map_pos - size * (1/zoom) * 0.5` to keep button centered on its map coord
  - Applies to all maps (world map, town, home, any future map) — no per-map special casing
  - Button positions in JSON are always **center coordinates** on the background image

#### Interior Bounds Calculation
  - `_show_interior_view()` bounds pass reads `map_pos` meta (center-based) rather than top-left position
  - Padding offset step updates `map_pos` meta so `_update_poi_scales()` uses the correct offset position
  - `_create_location_button()` and `_build_interior_poi_buttons()` both store `map_pos` meta and use center-based initial positioning

### Sub-Map Rendering Fixes

#### Background-Driven Content Size
  - `_show_interior_view()` now mirrors `_show_world_map_view()`: if a background texture is loaded, `texture.get_size()` drives the content dimensions
  - Falls back to button-bounds auto-fit only when no background image is set
  - `locations.json` `town` entry: `art_path` set to `res://assets/art/background/map/crestfallmap.png`

#### Pan Margin Scoped to World Map
  - `_clamp_pan()` uses `PAN_MARGIN` (700px) only when `current_location_id == "world_map"`
  - All other maps use `margin = 0.0` — content cannot be dragged past viewport edges

---

## 2026-05-24 - POI Discovery System (Save-Driven, Scalable to 100s)

- Focus:
  - Separate POI definitions from locations.json into a dedicated pois.json
  - Make POI visibility driven by save data (`discovered_pois`) rather than story flags alone
  - Allow any game system (battle, dialogue, exploration) to trigger POI discovery at runtime
  - Keep the architecture clean for hundreds of POIs

- Completed:

### New Data File: data/pois.json
  - Created `data/pois.json` with all existing POIs (town, forest, dungeon, swamp)
  - Each POI now has: `id`, `name`, `region`, `category`, `position`, `icon_path`, `target_location_id`, `unlock_condition`
  - `region` links POIs to fog_region IDs in `locations.json`
  - `_dev_notes` array in the JSON explains how to add new POIs for other developers

### locations.json Cleaned
  - Removed `points_of_interest` array from `world_map` location
  - Added `_dev_notes` redirecting developers to `data/pois.json` for POI documentation

### ContentDB POI Loading
  - `scripts/core/content_db.gd`: Added `POIS_PATH` constant, `pois_by_id` dictionary
  - `reload_content()` now loads `data/pois.json` via `_ingest_pois()`
  - `get_map_pois()` returns `pois_by_id.values()` (all defined POIs)
  - `get_poi(poi_id)` returns a single POI by ID

### SaveManager: discovered_pois
  - `scripts/core/save_manager.gd`: Added `"discovered_pois": ["poi_town"]` to default profile
  - New games start with only Crestfall Town discovered; other POIs are hidden until unlocked
  - Existing saves will get the default empty array via `_with_defaults()` on next load

### LocationService: Discovery API
  - `scripts/core/location_service.gd`:
    - `is_poi_discovered(poi_id)` — checks `SaveManager.profile["discovered_pois"]`
    - `is_poi_visible(poi_id)` — now requires `is_poi_discovered()` first, then checks `unlock_condition`
    - `discover_poi(poi_id)` — adds ID to save, persists, emits `SignalBus.poi_discovered`, returns `true` if newly discovered
  - `discover_poi()` validates the POI exists in ContentDB before adding, preventing typos

### SignalBus: poi_discovered
  - `scripts/core/signal_bus.gd`: Added `poi_discovered(poi_id: String)` signal
  - Emitted by `LocationService.discover_poi()` after save is written

### WorldMapController: Live Refresh on Discovery
  - `scripts/ui/world_map_controller.gd`: Connected `SignalBus.poi_discovered` → `_on_poi_discovered()`
  - If player is on the world map when a POI is discovered, the map auto-refreshes and the new button appears
  - No manual refresh needed — the signal handles it

### How to Use from Any Game System
  ```gdscript
  # From battle victory, dialogue choice, bond level up, exploration, etc.
  LocationService.discover_poi("poi_ruined_castle")
  ```
  - Automatically updates save data
  - Automatically emits signal
  - Automatically refreshes the world map if the player is looking at it
  - Returns `false` if already discovered (idempotent)

### POI Coordinate System
  - Map space: `(0, 0)` = top-left, `(8192, 4608)` = bottom-right of `worldmap.png`
  - POI `position: { "x": N, "y": N }` places the button **centered** on that pixel
  - Best workflow: open `worldmap.png` in an image editor, read cursor coordinates, paste into `pois.json`
  - Alternative: use percentage — `x = 8192 * 0.34`, `y = 4608 * 0.52`
  - Interior locations (town, home, etc.) use relative positioning inside a fitted viewport; eyeballing is fine

## 2026-05-24 - World Map Scaling, Vastness Feel, Responsive POIs

- Focus:
  - Scale world map to 8192×4608 pixels so it feels vast and requires scrolling
  - Prevent player from zooming out enough to see the entire map at once
  - Make POI/location buttons readable at all screen sizes (viewport-based sizing, not map-based)
  - Allow dragging 700px past map edges for a smoother pan feel

- Completed:

### World Map Image & Data Scaling
  - `data/locations.json`: `world_map.map_size` updated to `{"width": 8192, "height": 4608}`
  - All `fog_regions` positions and sizes rescaled to match new map dimensions
  - All `points_of_interest` positions rescaled to match new map dimensions
  - `world_map` `art_path` set to `res://assets/art/background/map/worldmap.png`

### Scene Layout Updates
  - `scenes/WorldMap.tscn`: `MapContent`, `Background`, `FogOverlay`, `POIsContainer` resized to `8192×4608`
  - `Background.expand_mode = 0` (EXPAND_KEEP_SIZE) so the 8192×4608 texture renders at native resolution
  - `MapContent.mouse_filter = 2` (IGNORE) so drag/zoom events pass through empty map space to parent `WorldMap`
  - `UIOverlay.z_index = 1` so buttons, breadcrumb, and panels always draw above the map

### Dynamic Min-Zoom (No Full-Map View)
  - `scripts/ui/world_map_controller.gd`: Replaced fixed `MIN_ZOOM = 0.3` with runtime `_recalculate_min_zoom()`
  - Computes `max(fit_zoom_x, fit_zoom_y) * 1.5`, capped at `1.0`
  - On 1080p: min zoom ≈ 0.35 — player sees only ~23% of map width at once
  - On 4K: min zoom ≈ 0.70
  - On ultrawide: min zoom ≈ 0.94
  - Ensures the world always feels too big to fit on screen

### Viewport-Based Button Sizing
  - `scripts/ui/world_map_controller.gd`: Added `_get_button_size()` — computes from viewport dimensions
    - Width: `max(180, viewport_width * 0.09)`
    - Height: `max(55, viewport_height * 0.06)`
    - Font size: `max(16, viewport_height * 0.018)`
  - On 1080p: buttons are ~180×65 with ~19pt font
  - On 4K: buttons are ~346×130 with ~39pt font
  - Buttons remain readable regardless of zoom level

### Map-Bound Buttons with Correct Centering
  - POI and location buttons are children of `POIsContainer` (inside `MapContent`) so they pan and zoom with the map
  - `_build_poi_buttons()`: buttons centered on POI coordinates using dynamic `_get_button_size()` (half-size offset)
  - `_create_location_button()`: buttons placed at top-left of coordinate as before, but with viewport-based size
  - `_clear_map_children()`: clears both `_fog_overlay` and `_pois_container` children

### Pan Margin Past Map Edges
  - `scripts/ui/world_map_controller.gd`: Added `PAN_MARGIN = 700.0`
  - `_clamp_pan()` updated so player can drag the map 700px past every edge before clamping
  - Provides empty buffer space around the map for a smoother scrolling experience

### Resource Loading Fix
  - `scripts/ui/world_map_controller.gd`: `_update_background()` now uses `Image.new()` + `ImageTexture.create_from_image()` for direct PNG loading
  - Bypasses Godot's `ResourceLoader` import cache which had stale `.import` metadata (`valid=false`)

### Interior View Still Fits Content
  - `_show_interior_view()` dynamically calculates content bounds from button positions, then calls `_fit_map_to_viewport()`
  - Interior locations zoom to fit their buttons; world map starts zoomed in at 1.0×

## 2026-05-24 - World Map Overhaul (Fog of War, POIs, Pan/Zoom)

- Focus:
  - Add visual fog of war covering undiscovered map regions
  - Add Points of Interest (POIs) that appear/disappear based on story tags
  - Implement map drag/pan and mouse-wheel zoom
  - Keep all UI responsive across resolutions

- Completed:

### Fog of War System
  - `data/locations.json`: Added `fog_regions` array to `world_map` — each region has `id`, `position`, `size`, and `unlock_condition`
  - `scripts/core/location_service.gd`: Added `is_fog_region_revealed(region_id)` — checks `unlock_condition` against `story_flags` (same condition system as locations)
  - `scripts/ui/world_map_controller.gd`: `_build_fog_patches()` creates semi-transparent dark `ColorRect` patches (`Color(0.02, 0.02, 0.05, 0.92)`) for each unrevealed fog region
  - Fog patches are hidden when their `unlock_condition` is met (e.g., `flag:discovered_north`)

### Points of Interest (POIs)
  - `data/locations.json`: Added `points_of_interest` array to `world_map` — each POI has `id`, `name`, `position`, `icon_path`, `unlock_condition`, `target_location_id`
  - `scripts/core/content_db.gd`: Added `get_map_pois()`, `get_map_fog_regions()`, `get_map_size()` helpers
  - `scripts/core/location_service.gd`: Added `is_poi_visible(poi_id)` — checks POI `unlock_condition` against `story_flags`
  - `scripts/ui/world_map_controller.gd`: `_build_poi_buttons()` creates centered buttons for each visible POI; clicking navigates to `target_location_id`
  - Added example POIs: Crestfall Town (visible by default), Whispering Forest, Ruined Dungeon, Fetid Swamp (locked until story flags set)
  - Added example locations: `forest`, `dungeon`, `swamp` as POI targets with their own events

### Map Pan & Zoom
  - `scenes/WorldMap.tscn`: Restructured with `MapViewport` (clip area) + `MapContent` (pannable/zoomable layer) + `UIOverlay` (fixed HUD)
  - `scripts/ui/world_map_controller.gd`: Mouse wheel zooms toward cursor (0.3x–3.0x); mouse drag pans the map
  - Pan is clamped to keep map edges within viewport; content smaller than viewport is auto-centered
  - `_fit_map_to_viewport()` calculates best initial zoom to show full map on load
  - `MapViewport.resized` connected to refit map on window resize

### Scene Restructure (Responsive)
  - `scenes/WorldMap.tscn`: UI elements moved into `UIOverlay` (Control with `mouse_filter = PASS`) so they stay fixed while map pans underneath
  - Map content nodes (`Background`, `FogOverlay`, `POIsContainer`) placed inside `MapViewport/MapContent` and scaled together
  - `Background.mouse_filter = PASS` so drag events reach parent `WorldMap` when clicking empty map space
  - Action buttons in `_actions_panel` get `custom_minimum_size = Vector2(0, 35)` for consistent sizing

### Dual View Mode
  - When `current_location_id == "world_map"`: shows POIs + fog patches + Battle Test button
  - When in interior location (e.g., `town`, `home`): shows child location buttons (existing hierarchical behavior)
  - `_show_world_map_view()` vs `_show_interior_view()` cleanly separates the two modes

## 2026-05-24 - Save Slot System

- Focus:
  - Replace single hardcoded save with 10-slot save system
  - Add slot picker overlay on title screen (New Game / Continue / Load Game)
  - Allow creating, loading, deleting, and overwriting save slots

- Completed:

### SaveManager Refactor
  - `scripts/core/save_manager.gd`: Replaced single `SAVE_PATH` with dynamic `_get_slot_path(slot_index)`
  - `MAX_SLOTS = 10`
  - `active_slot_index` tracks currently loaded slot
  - New methods: `has_slot()`, `get_slot_metadata()`, `load_slot()`, `save_slot()`, `create_new_profile_in_slot()`, `delete_slot()`
  - `reset_save()` now clears all 10 slots and recreates slot 1 with defaults
  - Metadata extraction reads waifu name and location name from save file for display

### Save Slot Overlay UI
  - `scenes/SaveSlotOverlay.tscn`: Centered panel with ScrollContainer + VBoxContainer for vertical slot list
  - `scripts/ui/save_slot_overlay.gd`: Rebuilds 10 slot rows dynamically
  - Each slot row shows: Slot #, waifu name + location (or "Empty"), action buttons
  - New Game mode: shows [New Game] for empty slots, [Overwrite] for occupied slots
  - Continue/Load mode: shows [Play] + [Delete] for occupied slots, "—" for empty slots
  - "Back" button closes overlay

### Title Screen Integration
  - `scripts/ui/title_screen.gd`: New Game and Continue now open slot picker overlay instead of directly starting
  - Added "Load Game" button (same behavior as Continue)
  - `scenes/TitleScreen.tscn`: Button order: New Game, Continue, Load Game, Options, Quit, Reset Save
  - SaveSlotOverlay instanced as child of TitleScreen

### GameState Sync
  - `scripts/core/game_state.gd`: Added `_sync_from_save()` to load `current_location_id` and `story_flags` from `SaveManager.profile` on Continue/Load
  - Ensures players resume at their last visited location with correct story progress

### Resolution Scalability Fixes (Project Overview Compliance)
  - `scenes/SaveSlotOverlay.tscn`: Panel changed from fixed 900×800 pixel offsets to percentage anchors (`0.15–0.85` width, `0.1–0.9` height)
  - `scenes/TitleScreen.tscn`: Added `custom_minimum_size = Vector2(0, 40)` to all 6 buttons + `Vector2(300, 0)` to button column VBoxContainer
  - `scripts/ui/save_slot_overlay.gd`: Added `custom_minimum_size` to Play, Delete, Overwrite, New Game buttons (80–100×35)
  - `scenes/SaveSlotOverlay.tscn`: Added `custom_minimum_size = Vector2(0, 35)` to CloseButton
  - Fixes checked against Project Overview v1.2 Core UI Scaling & Layout Rules: Full Rect roots, containers, size flags, spacer nodes, min sizes

### Auto-Save
  - `scripts/ui/world_map_controller.gd`: Saves active slot after every location change (clicked or back button)
  - `scripts/ui/victory_screen.gd`: Saves before returning to title after battle victory
  - **Defeat behavior**: `scripts/battle/battle_controller.gd` returns to title directly on defeat — no save. This preserves the player's pre-battle save (from world map navigation) so they can reload and choose whether to fight again, avoiding unwinnable fight locks

## 2026-05-24 - World Map & Location Navigation

- Focus:
  - Implement hierarchical location navigation (World Map → Town → Home)
  - Implement fog of war / unlock conditions for location visibility
  - Implement priority-based event system per location
  - Wire location navigation into existing phase flow

- Completed:

### Location Data & Service
  - `data/locations.json`: Defines `world_map`, `town`, and `home` with hierarchy, positions, unlock conditions, and events
  - `scripts/core/content_db.gd`: Loads `locations.json` into `locations_by_id`, adds `get_location()`
  - `scripts/core/location_service.gd` (`class_name LocationService`): Resolves active events by priority, checks visibility via `unlock_condition` against `story_flags`
  - Supported condition formats: `flag:X`, `!flag:X`, `bond:waifu_level`

### State Persistence
  - `scripts/core/game_state.gd`: Added `current_location_id` (String) and `story_flags` (Dictionary)
  - `scripts/core/save_manager.gd` + `data/save_template.json`: Persist `current_location_id` and `story_flags`
  - Default `story_flags` includes `tutorial_complete: true` so town is visible on new game

### SignalBus
  - `scripts/core/signal_bus.gd`: Added `location_change_requested(location_id: String)` signal + `request_location_change()` helper

### World Map UI
  - `scenes/WorldMap.tscn`: Full-screen Control with Background (TextureRect), BreadcrumbLabel, BackButton, LocationsContainer, ActionsPanel
  - `scripts/ui/world_map_controller.gd`: Displays current location background, breadcrumb trail, positioned child location buttons, action buttons from active events, back navigation
  - Fog of war: child locations hidden when `unlock_condition` is not met; buttons dynamically created from data

### Scene Flow
  - `scripts/core/main_controller.gd`: Changed `PHASE_HUB` to show `WorldMap.tscn` instead of immediately requesting battle
  - Added `WORLD_MAP_SCENE` preload

### Bug Fixes
  - Fixed `Invalid call. Nonexistent 'String' constructor.` errors in `world_map_controller.gd` and `location_service.gd`
  - Root cause: JSON `null` values (e.g., `"parent": null`, `"art_path": null`) were passed to `String()` which throws in GDScript 4
  - Fix: All `String(value)` calls now use `String(value) if value != null else ""` pattern
  - Files modified: `world_map_controller.gd` (7 locations), `location_service.gd` (1 location)

### Architecture Notes
  - Locations are data-driven; positions are set in `locations.json` (`position.x`, `position.y`) so they align with background art without code changes
  - Event priority system allows locations to evolve over time (e.g., cutscene → hub → boss fight → empty)
  - Navigation state flows through `SignalBus` → `GameState` → `WorldMapController` refresh

## 2026-05-23 - Summon System

- Focus:
  - Implement Summon card effect (create HP-based summon units)
  - Implement summon damage absorption: Block → Summons (right-to-left, taunt-first) → Player HP
  - Implement summon replacement mode when all 3 slots are full
  - Implement SacrificeAllSummons effect support
  - Wire summons into enemy intent damage resolution

- Completed:

### Summon Core System
  - `content_db.gd`: Added `"Summon"` and `"SacrificeAllSummons"` to `V1_SUPPORTED_EFFECTS`
  - `battle_setup_service.gd`:
    - `_to_runtime_card()`: Extracts `"Summon"` → `summon_name` + `summon_hp`
    - `_to_runtime_card()`: Extracts `"SacrificeAllSummons"` → `sacrifice_summons: true`
  - `effect_resolver.gd`:
    - `apply_damage_to_player()`: After block is consumed, remaining damage now pierces through summons before hitting player HP
    - Damage order: taunt summons first (right-to-left), then normal summons (right-to-left)
    - Summons that drop to 0 HP are cleared in-place (`summons[idx] = {}`)
    - Each damage instance independently consumes block then summons then HP
  - `intent_library.gd` `execute_attack()`: Already calls `apply_damage_to_player(..., skip_frail = true)` — no signature change needed; summons are read from `player_state["summons"]`

### CardPlayService Summon Handling
  - Added `replace_summon_index: int = -1` optional parameter to `play_card()` and `_resolve_card_effects()`
  - `SacrificeAllSummons`: Clears all summon slots in-place (mutates existing array, no reassignment)
  - `Summon`: If `replace_summon_index >= 0`, replaces that slot; otherwise finds first empty slot (left-to-right placement). Warns if no space (BattleController pre-checks prevent this in practice)

### BattleController Summon UI & Replacement Mode
  - Added `_summons: Array[Dictionary] = [{}, {}, {}]` (3 slots, left-to-right index 0→2, damage hits index 2→0)
  - Added `_summon_cards`, `_summon_stats_labels` arrays; populated in `_populate_summon_ui_arrays()`
  - Added `_replace_summon_mode: bool` and `_pending_summon_card_id: String` state
  - `_initialize_battle()`: `_player_state["summons"] = _summons` so EffectResolver can access summons through player_state
  - `_play_card_by_id()`:
    - Pre-check: if card has summon effect and all 3 slots full, enters replace mode instead of playing
    - Otherwise passes `replace_summon_index` to `CardPlayService`
  - `_enter_replace_summon_mode(card_id)`: Highlights occupied summon slots in yellow; shows "Select a summon to replace"
  - `_exit_replace_summon_mode()`: Clears highlights and mode state
  - `_on_summon_slot_gui_input(index)`: In replace mode, clicking an occupied slot exits mode and completes the card play with that replace index
  - `_on_card_gui_input()`: Clicking any card while in replace mode cancels the mode
  - `_on_end_turn_pressed()`: Blocked while in replace mode
  - `_refresh_ui()`: Each summon slot shows `"Name\nX/Y HP"` or `"Summon N: Empty"`
  - `_update_player_board_layout()`: Visibility derived from `_summons[i].is_empty()`; `active_count` derived from `_get_active_summon_count()`
  - Helper functions: `_find_card_data_in_hand()`, `_card_has_summon_effect()`, `_get_active_summon_count()`

### Deck Updates for Testing
  - `save_manager.gd` + `data/save_template.json`: Added `"8", "8"` (Soulbound Wraith — 2× Summon 25 HP) to default deck

### Architecture Notes
  - Summons are stored inside `_player_state["summons"]` as an `Array[Dictionary]` reference. This lets `EffectResolver`, `IntentLibrary`, and `CardPlayService` all access/modify summons without changing function signatures across the entire chain
  - Empty slots use `{}` (empty Dictionary). `is_empty()` checks distinguish occupied vs empty
  - Summon placement fills left-to-right (index 0 first). Damage hits right-to-left (index 2 first) with taunt reordering
  - Multi-hit enemy intents (e.g. double_attack) apply damage as separate instances; block and summons are consumed progressively across instances
  - Card #8 "Soulbound Wraith" (Summon, 1 mana, 25 HP) is now fully supported in v1
  - Card #6 "Last Breath Ritual" has `SacrificeAllSummons` supported, but still requires `PlayerHPBelow` and `HasSummonAlive` play conditions which are not yet implemented
  - **Known issue**: Summon sprite appears but does not animate. The `SpriteFrames` resource in `BattleScene.tscn` currently contains a single static frame. Multi-frame animation must be configured in the Godot editor (add additional `AtlasTexture` frames to `SpriteFrames_summon` and set playback speed). The `AnimatedSprite2D` node and positioning script are already wired correctly.

## 2026-05-23 - Weakness and Stun Status Effects

- Focus:
  - Implement Weakness debuff (player and enemy outgoing damage -25%)
  - Implement Stun (skip enemy turn, advance intent, consume stack)
  - Wire both into existing status infrastructure

- Completed:

### Weakness System
  - `effect_resolver.gd`:
    - `resolved_attack_damage()`: after rage, if `player_state["weak"] > 0` and no opposing frail, apply `floor(total × 0.75)`; weak+frail now cancel at base values
    - `intent_library.gd` `execute_attack()`: if `enemy_state["weak"] > 0` and no player frail, apply `floor(damage × 0.75)` before hitting player
  - `card_play_service.gd`: Added `"weak"` case to debuff match — stacks additively on target enemy
  - `turn_manager.gd`:
    - `start_player_round()`: decrements `player_state["weak"]` by 1 each round start (like frail)
    - `tick_enemy_status_effects()`: decrements `enemy_state["weak"]` by 1 each round start
  - `intent_library.gd`: Added `"weak"` to `execute_debuff()` with player/enemy target support
  - `battle_controller.gd`:
    - Player state initialized with `"weak": 0`
    - Enemy states initialized with `"weak": 0`
    - `_refresh_ui()`: `| WKN X` shown in player waifu stats and enemy stats labels
    - `_rebuild_hand_cards()` + `_highlight_hovered_enemy()`: pass `player_weak_active` to `CardUI.set_damage_preview()`
  - `card_ui.gd`:
    - `set_damage_preview()` signature extended with `player_weak_active: bool`
    - `_format_single_effect()` DealDamage: if `player_weak_active`, `floor(buffed × 0.75)`; red color if below base
    - Propagates through `_format_effects` with new parameter

### Stun System
  - `card_play_service.gd`: Added `"stun"` case to debuff match — stacks additively on target enemy
  - `intent_library.gd`: Added `"stun"` to `execute_debuff()` (enemy target only; player stun reserved)
  - `enemy_ai.gd`:
    - `run_enemy_turn()`: stun check at top — if `enemy_state["stun"] > 0`, decrement stack, skip intent execution, return next intent index with `"intent_name": "Stunned"`
  - `battle_controller.gd`:
    - Enemy states initialized with `"stun": 0`
    - `_refresh_ui()`: `| STN X` shown in enemy stats labels
    - If enemy stunned, intent label shows "Intent: Stunned" instead of resolved pattern

### Duration Fallback Fix
  - `battle_setup_service.gd`: `_to_runtime_card()` ApplyDebuff extraction now uses `int(effect.get("stacks", effect.get("duration", 0)))` so duration-based debuffs (e.g. card #6 Last Breath Ritual) produce correct stack counts

- Architecture Notes:
  - **Weak+Frail Counter**: Base Weak (×0.75) and base Frail (×1.25) now counter each other → 100% damage when both are present on opposing sides. Refactored into single call sites so multipliers are computed together and floor math is applied once:
    - Player card attacks: `EffectResolver.resolved_attack_damage()` now accepts optional `enemy_state`; weak+frail cancellation is computed inside this function before returning
    - Enemy intent attacks: `IntentLibrary.execute_attack()` handles weak+frail cancellation, then calls `apply_damage_to_player(..., skip_frail = true)` to prevent double-application
    - `CardPlayService._apply_frail()` removed — frail no longer applied downstream; `resolved_attack_damage()` owns all outgoing-damage multipliers
    - `EffectResolver.apply_damage_to_player()` now accepts `skip_frail: bool = false` for intent-damage paths that already handled frail
  - Stun is consumed at the start of the enemy turn, before intent execution; intent index still advances via `_next_intent_index()`
  - Both Weakness and Stun decay by 1 at round start (player via `start_player_round`, enemies via `tick_enemy_status_effects`)
  - Card #7 "Mana Leech" (Apply Weak 2 to SingleEnemy) is `supported_in_v1`; card #6 "Last Breath Ritual" still has unsupported `SacrificeAllSummons` so remains excluded from runtime deck

### Test Cards Added
  - `cards.json`: Added card `"23"` — **Cripple**, Skill, 1 mana, targeted, Apply Weak 3 to SingleEnemy
  - `cards.json`: Added card `"24"` — **Concuss**, Attack, 2 mana, targeted, Deal 6 damage + Apply Stun 1 to SingleEnemy
  - `save_manager.gd` + `data/save_template.json`: Default deck updated to include `"23"` and `"24"` for testing

## 2026-05-16 (Session 4) - Dialogic Textbox Responsive Layout

- Focus:
  - Make the Dialogic2 custom textbox fully responsive to viewport size
  - Fix skew, positioning, font scaling, and choice button layout

### Textbox Responsive Layout
  - `DialogicStuff/TextboxWithPortrait/speaker_portrait_textbox_layer.gd`:
    - Root cause diagnosed: `.tscn` had wrong UID (`uid://bk84r61kckpxa` — the default Dialogic addon script) instead of our custom script's actual UID (`uid://du162elj5meks`), so all prior script edits were silently ignored
    - Fixed UID in `custom_textbox_with_portrait_.tscn` to correctly load our custom script
    - Added `_ready()` connecting `viewport.size_changed` → `_apply_responsive_layout` + `call_deferred` for initial sizing
    - Added `_apply_responsive_layout()`: sizes panel via `offset_left/right/top/bottom` (not `position` — anchor-mode nodes require explicit offsets)
      - Width: `vp.x × 0.70` (15% inset each side)
      - Height: `vp.y × 0.325` (32.5% of viewport)
      - Bottom margin: `vp.y × 0.15` (15% gap from screen bottom)
    - Guard added: returns early if `not is_inside_tree() or get_viewport() == null` (Dialogic calls `_apply_export_overrides` before tree entry)
    - Font scaling: dialog text `vp.y × 0.033`, name label `vp.y × 0.045`
    - In-editor mode still uses `box_size`/`box_distance` exports for preview
    - Stylebox duplicated from default addon resource, `skew` zeroed (was `Vector2(0.073, 0)` causing rhombus shape), content margins set to 24px L/R, 18px T/B

### Custom VN Choices Layout
  - `DialogicStuff/CustomChoices/custom_vn_choice_layer.tscn`: new custom copy of `vn_choice_layer.tscn`
    - Reuses `vn_choice_layer.gd` (no script changes)
    - `Choices` VBoxContainer anchor changed from dead-center (`preset 8`) to right-aligned: right edge at 85% of viewport width (matching chatbox right edge), top at 30% of viewport height
    - 340px wide, grows downward to fit buttons
  - `DialogicStyle.tres`: updated choices layer reference to custom scene; overrides set `boxes_min_size = Vector2(340, 60)`, `font_size_custom = 30`

## 2026-05-15 (Session 3) - Burn, Rage, Search, Frail, Enemy Random Intents

- Focus:
  - Implement Burn, Rage, Frail status effects and their card test cases
  - Implement SearchDeck mechanic with interactive draw pile overlay
  - Give the test goblin random intent selection with a Cripple intent

- Completed:

### Burn Status Effect
  - `turn_manager.gd`: Added `tick_enemy_burn()` — deals Burn stacks as damage at **end of enemy turn**; stacks never decrement (persistent)
  - `card_play_service.gd`: Added `"burn"` case to debuff match — stacks additive on target enemy
  - `battle_controller.gd`: `burn: 0` initialized in enemy state; `tick_enemy_burn` called after enemy intent loop; `BRN X` shown in enemy stats label
  - `cards.json`: Added card `"19"` — **Ignite**, Skill, 1 mana, targeted, Apply Burn 3 to SingleEnemy

### Rage Player Buff
  - `effect_resolver.gd`: Added rage consumption in `resolved_attack_damage()` — if `player_state["rage"] > 0`, applies `floor(total × 1.5)` then decrements rage by 1; applies after all additive bonuses
  - `battle_setup_service.gd`: `GainRage` effect extracted to `runtime_card["rage_gain"]`
  - `card_play_service.gd`: `rage_gain` applied to `player_state["rage"]` on card play
  - `content_db.gd`: `"GainRage"` added to `V1_SUPPORTED_EFFECTS`
  - `card_ui.gd`: `set_damage_preview` passes `rage_stacks` → `_format_effects` → `_format_single_effect`; DealDamage shows `floor(buffed × 1.5)` when rage > 0
  - `battle_controller.gd`: `rage: 0` initialized in player state; `RAGE X` shown in waifu stats label; `_rebuild_hand_cards()` passes `rage_stacks` to `set_damage_preview`
  - `cards.json`: Added card `"20"` — **Fury**, Skill, 1 mana, Gain 2 Rage

### Search Card Mechanic
  - `battle_state_machine.gd`: Added `PHASE_SEARCHING` state; `enter_searching()`, `is_searching()`; `can_play_cards()` and `can_end_turn()` both return false while searching
  - `battle_setup_service.gd`: `SearchDeck` effect extracted to `runtime_card["search_filter"]` (lowercased filter string)
  - `card_play_service.gd`: `search_filter` included in `play_card()` return dict so battle_controller can open overlay post-play
  - `content_db.gd`: `"SearchDeck"` added to `V1_SUPPORTED_EFFECTS`
  - `card_ui.gd`: `"SearchDeck"` case added to `_format_single_effect()` displaying "Search your Draw Pile for a X."
  - `battle_controller.gd`:
    - Added `_open_search_overlay(filter_type)` — filters `_draw_pile` by card type, enters searching state, builds and adds overlay node
    - Added `_build_search_overlay(filter_type, cards)` — dynamically constructs `Control → CenterContainer → PanelContainer → VBox → ScrollContainer(SCROLL_MODE_DISABLED) → HFlowContainer` with title, card grid, Cancel button, and disabled Confirm button
    - Added `_on_search_card_input()` — click highlights selected card (gold tint), enables Confirm
    - Added `_on_search_confirm_pressed()` — removes chosen card from `_draw_pile` at correct index, adds to hand (or discard if full), closes overlay
    - Added `_close_search_overlay(completed)` — frees overlay node, clears state, re-enters `PHASE_PLAYER_TURN`, refreshes UI
    - `_play_card_by_id()` checks `search_filter` in result after normal refresh and opens overlay if non-empty
  - `cards.json`: Added card `"21"` — **Scout**, Skill, 1 mana, SearchDeck filter=Skill
  - **Layout fix**: `ScrollContainer.horizontal_scroll_mode = SCROLL_MODE_DISABLED` required so `HFlowContainer` knows its width and wraps correctly
  - **Centering fix**: `CenterContainer(PRESET_FULL_RECT)` wrapping `PanelContainer` instead of `PRESET_CENTER` anchors on PanelContainer directly

### Frail Debuff
  - `card_play_service.gd`: Added `_apply_frail(damage, enemy_state)` helper — returns `floor(damage × 1.25)` if enemy has frail > 0; applied to all attack damage paths before `apply_damage_to_enemy`; `"frail"` case added to debuff match for stacking
  - `effect_resolver.gd`: `apply_damage_to_player()` now applies `floor(damage × 1.25)` if `player_state["frail"] > 0` — enables Cripple intent to amplify enemy attacks on the player
  - `turn_manager.gd`: `tick_enemy_status_effects()` decrements `enemy_state["frail"]` by 1 each round start (no damage); `start_player_round()` decrements `player_state["frail"]` by 1 each round start
  - `battle_controller.gd`: `frail: 0` initialized in both player and enemy states; `FRL X` shown in player waifu stats and enemy stats labels; `selection_mode` stored from enemy data in `_build_enemy_states()`
  - `card_ui.gd`: `set_damage_preview` extended with `frail_active: bool` — propagates through `_format_effects` and `_format_single_effect`; DealDamage shows `floor(buffed × 1.25)` when frail_active; hover over frail enemy during drag calls `set_damage_preview` with `frail_active = true` via `_highlight_hovered_enemy()`
  - `cards.json`: Added card `"22"` — **Expose**, Skill, 1 mana, targeted, Apply Frail 3 to SingleEnemy

### Enemy Random Intent Selection
  - `enemy_ai.gd`: `_next_intent_index()` checks `enemy_state["selection_mode"]`; returns `randi() % intents.size()` for `"random"` mode, sequential cycle otherwise
  - `enemy_library.gd`: Added `"cripple"` intent pattern — type `"debuff"`, applies `frail 2` to player
  - `intent_library.gd`: `execute_debuff()` now fully implemented — applies `frail` stacks to player or enemy based on `params["target"]`; extensible for future debuffs
  - `enemies.json`: Test Goblin updated to `"selection_mode": "random"` with 3 intents: `light_attack (5)`, `heavy_attack (8)`, `cripple (FRL 2 to player)` — equal 33% probability each turn

### CardUI Container Sizing Fix
  - `card_ui.gd`: `setup()` now sets `custom_minimum_size = Vector2(scaled_width, scaled_height)` alongside `size` — fixes cards being collapsed to zero size when placed inside `HFlowContainer` or any other Container node (affects search overlay and deck viewer)

- Architecture Notes:
  - Frail multiplier (`×1.25`) is applied at the call site in `card_play_service` for player attacks and inside `apply_damage_to_player` for enemy attacks — poison/burn ticks bypass both paths intentionally (status damage is not "attack" damage)
  - Rage multiplier (`×1.5`) is applied in `effect_resolver.resolved_attack_damage` after all additive bonuses; stacks consumed one per attack card played
  - Search overlay is fully dynamic (no scene changes) — built and freed each use; `PHASE_SEARCHING` blocks end-turn and card play while open
  - Enemy `selection_mode` is stored in runtime enemy state so `EnemyAI` can read it without querying `enemies.json` again
  - `_highlight_hovered_enemy()` now also drives the drag card preview update — single loop, no redundant iteration

- Cards Added This Session: Ignite (19), Fury (20), Scout (21), Expose (22)

- Next Session:
  - Implement Weakness debuff (player deals −25% damage) as counterpart to Frail
  - Implement Bleed (damage at round start, persistent) and Stun (skip enemy turn)
  - Wire consumable and relic slots
  - Build deck editor and card reward screen

---

## 2026-05-15 (Session 2) - Strength Mechanic, Starter Cards, Damage Preview UI

- Focus:
  - Implement Strength buff mechanic from card rules (v1.8)
  - Add Warcry test card (+2 Strength, encounter-duration)
  - Fix deck loading pipeline so real cards appear instead of fallback Strike/Guard
  - Add live damage preview on attack cards showing actual final damage with color coding

- Completed:

### Strength System
  - `content_db.gd`: Added `"GainStrength"` to `V1_SUPPORTED_EFFECTS`
  - `effect_resolver.gd`: Added `player_state` parameter to `resolved_attack_damage()`; Strength and Strength_Round both added to attack damage math
  - `card_play_service.gd`: Handles `strength_gain` (encounter) and `strength_gain_round` (round) runtime card fields; applies to `player_state` on card play
  - `battle_setup_service.gd`: `_to_runtime_card()` extracts `GainStrength` effect into `strength_gain` or `strength_gain_round` based on `"duration"` field (`"encounter"` | `"round"`)
  - `turn_manager.gd`: `strength_round` reset to 0 at start of every player round alongside block reset
  - `battle_controller.gd`: `_player_state` initialised with `"strength": 0` and `"strength_round": 0`; stats label shows `| STR X` when non-zero

### Strength Duration Architecture
  - Three duration tiers fully supported:
    - `"encounter"` → `player_state["strength"]` (persists until battle ends) — used by Warcry
    - `"round"` → `player_state["strength_round"]` (reset each round start) — ready for future cards
    - Permanent waifu/artifact → applied to `player_state["strength"]` at `_initialize_battle()` when relic system is built; existing `passive_attack_damage` waifu path continues to function

### Warcry Test Card
  - `cards.json`: Added card `"16"` — Warcry, Skill, 1 mana, Common; effect `{ "type": "GainStrength", "value": 2, "duration": "encounter" }`
  - `card_ui.gd`: Added `"GainStrength"` case to `_format_single_effect()` displaying "Gain X Strength."

### Starter Card Entries + Deck Pipeline Fix
  - `cards.json`: Added `"S1"` (Strike — DealDamage 6) and `"D1"` (Defend — GainBlock 5) as proper card entries that pass `supported_in_v1`
  - `save_manager.gd` `_default_profile()`: Default deck changed to `12×S1 + 8×D1 + 2×16` (22 cards); matches fallback deck proportions with Warcry added
  - `data/save_template.json`: Kept in sync with `_default_profile()`
  - Root cause fixed: `_default_profile()` is the only source of truth for default/reset decks — `save_template.json` is documentation only; always update the GDScript source

### Damage Preview UI
  - `card_ui.gd`: `EffectText` node type changed from `Label` to `RichTextLabel` (BBCode enabled) in both `Card.tscn` and script type annotation
  - Font size override key updated: `"font_size"` → `"normal_font_size"` for RichTextLabel
  - Text color property updated in scene: `font_color` → `default_color`
  - `_format_effects()`: Wraps output in `[center]...[/center]` BBCode to preserve horizontal centering
  - `_format_single_effect()`: DealDamage now calls `_color_damage_number()` to wrap the value in BBCode color tags
  - `_color_damage_number()`: Gold (`#ffcc33`) when bonus > 0, Red (`#ff4444`) when bonus < 0, plain when zero
  - `set_damage_preview(bonus)`: Simplified — only passes effective bonus to `_format_effects`; non-attack cards receive bonus 0
  - `battle_controller.gd`: `_get_total_attack_bonus()` helper mirrors `EffectResolver` math exactly — `strength + strength_round + all passive_attack_damage from waifu_scaled_effects`
  - Preview set in `_rebuild_hand_cards()` on each freshly created card (fixes timing bug where preview was set on cards about to be destroyed by rebuild)

- Architecture Notes:
  - `save_template.json` has no runtime effect — `SaveManager._default_profile()` is authoritative
  - `supported_in_v1` flag remains as metadata in `ContentDB` but no longer gates card inclusion in `_build_runtime_deck()`; `_to_runtime_card()` handles unsupported effects gracefully (stored but not executed)
  - `_get_total_attack_bonus()` is the single source of truth for displayed and resolved attack bonus — both must stay in sync with `EffectResolver.resolved_attack_damage()`

- Next Session:
  - Implement `ApplyDebuff` in `CardPlayService` (Bleed, Poison, Weakness, Frail, Stun)
  - Add status tick at round start (Bleed, Poison, Regen damage/healing)
  - Add Weakness mechanic (−25% damage) feeding into `_get_total_attack_bonus()` as negative bonus
  - Wire consumable and relic slots in top bar
  - Build deck editor / card reward screen

---

## 2026-05-15 - Battle UI Top Bar Reorganization, Relic Row, Deck Viewer Overlay

- Focus:
  - Reorganize persistent header row: left-to-right order of waifu portraits → consumables → battle info → deck button
  - Add Slay the Spire-style relic/buff strip row between header and battle area
  - Add in-battle deck viewer overlay showing all cards as real CardUI instances
  - Add fallback portrait art for main waifu and both sub-waifu slots
  - Polish layout: spacers between groups, hand hangs lower, bottom bar taller

- Completed:
  - **`BattleScene.tscn` — header row restructure**:
    - Removed `PlayerGroupHeader` ("Main Waifu + Summons") and `EnemyGroupHeader` ("Enemies") labels
    - Replaced `PersistentBox1/2/3` labels with `TextureRect` nodes (`MainWaifuPortraitRect`, `SideWaifu1PortraitRect`, `SideWaifu2PortraitRect`) using `sidewaifutest.png` as placeholder/fallback
    - Added `MainSubWaifuSpacer` (20px) between main waifu and sub-waifu group
    - Added `WaifuConsumableSpacer` (20px) between sub-waifu group and consumables
    - Added 3 consumable slots (`ConsumableSlot1-3`, 65px min-width each) using `consumabletest.png`
    - Added `BattleInfoPanel` (expands to fill) + `BattleInfoLabel` showing Floor / Turn / elapsed time
    - Added `DeckViewButton` (TextureButton, `discardpile.png`, 65px min-width) as final top-bar item
  - **`BattleScene.tscn` — relic row**:
    - Added `RelicsRow` (HBoxContainer, stretch ratio 0.05) between PersistentHeaderRow and CombatRow
    - 3 relic slots (55px min-width each) using `relictest.png`, followed by `RelicsSpacer` (expand) — relics anchor left, blank space fills right (STS style)
  - **`BattleScene.tscn` — deck viewer overlay**:
    - Added `DeckOverlay` (Control, full-rect anchors, `z_index = 100`, hidden by default) as direct child of scene root
    - `DeckDimBg` (ColorRect, 75% black) dims the battle scene behind the panel
    - `DeckPanel` (PanelContainer, anchored to 10–90% width, 5–95% height) centered on screen
    - `DeckHeader` (HBoxContainer): `DeckTitleLabel` (expands) + `DeckCloseButton` (52px "X")
    - `DeckScrollContainer` (vertical scroll only, `horizontal_scroll_mode = 0`) → `DeckCardGrid` (HFlowContainer, cards wrap to new rows)
  - **`BattleScene.tscn` — row ratio rebalance**:
    - PersistentHeaderRow: `0.07 → 0.09`
    - RelicsRow: new `0.05`
    - CombatRow: `0.60 → 0.52` (battle area gives space to hand and relics)
    - HandHudRow: `0.25 → 0.26` (~13% taller — cards sit lower and raise battlefield zones)
  - **`battle_controller.gd` — waifu portrait fallback**:
    - Added `DEFAULT_SIDE_WAIFU_ART_PATH` constant (`sidewaifutest.png`)
    - Added `_set_texture_with_fallback(target, path, fallback)` helper
    - Updated `_apply_waifu_art()` to use fallback helper for all three portrait slots
    - `@onready` refs updated to point to new TextureRect nodes
  - **`battle_controller.gd` — battle info bar**:
    - Added `_battle_elapsed_time: float` tracked in `_process()` (pauses when `_battle_over`)
    - Reset to `0.0` in `_initialize_battle()`
    - Added `_format_battle_time(seconds)` helper → `"M:SS"` format
    - `_refresh_ui()` now drives `_battle_info_label.text` → `"Floor 1  •  Turn N  •  M:SS"`
  - **`battle_controller.gd` — deck viewer**:
    - Added `_full_deck: Array[Dictionary]` — snapshot of resolved deck from setup payload taken before shuffle in `_initialize_battle()`
    - Added `@onready` refs for all deck overlay nodes
    - `_open_deck_overlay()`: sets title with card count, instantiates `Card.tscn` at `CardSize.FULL` for every card in `_full_deck`, sets `custom_minimum_size = size` (so `HFlowContainer` respects card dimensions), sets `mouse_filter = PASS` for scroll passthrough, then shows overlay
    - `_close_deck_overlay()`: hides overlay, frees all card instances
    - Both wired in `_ready()` via `.pressed.connect()`
  - **`battle_controller.gd` — hand hang**:
    - `_arrange_hand_cards()`: `bottom_y = container_height + card_height * 0.15` — cards hang ~15% of card height below the hand container edge, exposing more of the battlefield; hover still raises them into full view

- Architecture Notes:
  - `_full_deck` is sourced from `_build_deck_from_setup(setup)` before shuffle — canonical save-file card order, independent of mid-battle pile state; no direct save/content queries in new code
  - Deck overlay button wired directly (internal battle UI), consistent with `_end_turn_button` pattern — no SignalBus needed for intra-scene UI
  - `CardSize.FULL` used for deck viewer (explicitly "card library / rewards" per `card_ui.gd` comments)
  - `custom_minimum_size = card_ui.size` required after `setup()` so `HFlowContainer` uses the card's dimensions for wrapping layout (containers ignore the `size` property directly)
  - All new placeholder assets (`sidewaifutest.png`, `consumabletest.png`, `relictest.png`) are placeholders — future save/setup payload data will replace them through existing `_apply_waifu_art()` / setup pipeline patterns

- Next Session:
  - Wire consumable slots to save/inventory data when consumable system is implemented
  - Wire relic slots to player relic inventory when relic system is implemented
  - Add floor tracking to `GameState`/`BattleSetupService` so info bar shows real floor number
  - Load main waifu portrait from save file via `BattleSetupService` payload

## 2026-05-14 - Hand Layout Polish, Drag Threshold, Pile UI Overhaul

- Focus:
  - Fix hand cards clustering to right half on round 2+
  - Tighten hand layout: reduce tilt spillage, increase arc, enforce overlap
  - Fix non-targeted card drag distance being far too long
  - Overhaul draw/discard pile UI: overlaid centered number on image
  - Fix pile art being overridden at runtime by wrong asset
  - Add per-waifu pile art system via `pile_art_path` field
  - Shrink persistent header bar

- Completed:
  - Fixed `battle_controller.gd` — `_rebuild_hand_cards()` root cause fix:
    - `queue_free()` does not remove nodes from the scene tree immediately
    - Old cards were still children when `_arrange_hand_cards()` counted them
    - New cards were placed in the right-half slots of the combined old+new set
    - Fix: call `_hand_container.remove_child(child)` before `child.queue_free()`
  - Hand layout polish in `_arrange_hand_cards()`:
    - Reduced `max_rotation` from `12.0°` to `7.0°` — less aggressive tilt
    - Added dynamic `h_padding = card_height * sin(7°) + 8px ≈ 54px` on each side
      - Edge card tops guaranteed to stay within hand panel bounds at any count
    - Increased arc lift from `35px` to `70px` — more pronounced natural hand curve
    - Added `max_step = card_width * 0.65` cap — cards always overlap regardless of hand size
      - Small hands (2–3 cards) now fan together in the center instead of spreading apart
  - Drag threshold for non-targeted cards (block etc.):
    - Old: `hand_top - card_height * 0.8` — required dragging ~680px above resting position
    - New: `hand_top + card_height * 0.5` — plays when card center clears hand container top
    - Much shorter intentional drag; snap-back still reliable for accidental lifts
  - Draw/Discard pile UI overhaul in `BattleScene.tscn`:
    - Removed `DrawPileVBox` and `DiscardPileVBox` — label now direct child of PanelContainer
    - PanelContainer stacks all children at same rect — label overlays image automatically
    - Label: 48px white font, black outline (size 6), centered horizontally and vertically
    - Label text changed from `"Draw: N"` / `"Discard: N"` to just the number `"N"`
    - Updated `@onready` paths in `battle_controller.gd` (removed VBox segment)
    - Updated `_refresh_ui` to assign `str(pile.size())` directly
  - Fixed pile art being overridden at runtime in `_apply_waifu_art()`:
    - Was calling `_set_texture_if_valid` with `DEFAULT_PILE_ART_PATH` (cascade_orb.png) as fallback
    - Now only overrides pile textures when `sub_portrait_path != ""` — scene default preserved
  - Added `pile_art_path` field to all waifus in `waifus.json` (currently all `discardpile.png`)
  - Updated `battle_setup_service.gd` — `sub_waifu_portrait_path` now reads `pile_art_path` first,
    falls back to `portrait_path` — future waifus can have unique pile art per waifu
  - Reduced `PersistentHeaderRow` stretch ratio: `0.15 → 0.07` (thin info strip at top)

- Bugs Fixed:
  - Hand right-half bug: `queue_free()` timing — nodes stayed in children array until end of frame
  - Pile art always showing `cascade_orb.png`: `_apply_waifu_art()` overrode scene texture unconditionally

- Architecture Notes:
  - Pile art is now data-driven per waifu via `pile_art_path` in `waifus.json`
  - Scene sets the safe default; runtime only overrides when a valid path is provided
  - Hand fan padding scales automatically with rotation angle — no magic numbers

## 2026-05-13 - Card UI Polish & Effect Text Fix
- Focus:
  - Fix card scaling issues (cards not resizing properly)
  - Fix missing effect text on cards
  - Polish hand layout: size, z-index stacking, hover effects
  - Update card art to Nyxcardsizetemplate.png
- Completed:
  - Fixed `demon-lords-commander/scripts/battle/card_ui.gd`:
    - `size = Vector2(...)` instead of `custom_minimum_size` — actual fix for cards not scaling
    - Removed `size_flags_*` from Card.tscn to allow free resizing
    - Font scaling: CardName (64→24px), ManaCost (72→27px), EffectText (64→24px) at 0.324 scale
  - Fixed `demon-lords-commander/scripts/core/battle_setup_service.gd`:
    - Added `runtime_card["effects"] = effects.duplicate(true)` in `_to_runtime_card()`
      - Root cause: runtime cards had no `effects` array → card_ui got empty array → no text
    - Added `effects` arrays to fallback Strike/Guard cards too
  - Hand layout polish in `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - Even spread: cards distributed evenly across container width (step = (width - card) / (count-1))
    - Z-index stacking: each card slot gets `base_z = i * 5`, rightmost on top
      - Prevents border-over-art bleed from left cards onto right cards
      - Text z-index = 5 (internal) so it stays within its card but above its own border
    - Natural hand curve: center cards lifted 35px higher than edge cards
    - Hover effect: lift 15px + scale 1.06x + z-index boost of +50
    - Snap back after drag re-arranges the hand
    - Window resize auto-rearranges via `_hand_container.resized` signal
  - Scene changes in `demon-lords-commander/scenes/BattleScene.tscn`:
    - HandCards: HBoxContainer → Control (manual positioning for fan layout)
    - Removed PlayerHPPanel + PlayerHPLabel (HP display removed from bottom row)
    - DrawPilePanel & DiscardPilePanel: width 110 → 220 (doubled)
    - DrawPileArt & DiscardPileArt: texture changed to discardpile.png (user edit)
  - Card art: all cards now use `Nyxcardsizetemplate.png` (fallback + all JSON entries)
  - SCALE_HAND values iterated: 0.23 → 0.46 → 0.37 → 0.324 (final: ~35% viewport = ~378px at 1080p)
- Bugs Fixed:
  - Parse error: `_hand_container` type mismatch HBoxContainer → Control
  - Cards not scaling: `custom_minimum_size` blocked `size` from working (scene had 784×1168 min)
  - No effect text: `_to_runtime_card()` never copied `effects` array to runtime cards
  - Text buried under borders: internal text z-index too low, then too high, now balanced at 5
- Architecture Notes:
  - Card text z-index hierarchy: CardName/ManaCost/EffectText all at z=5 internal
    - Effective z = base_z + 5, so right card text (e.g., 50) renders above left card border (7)
    - But left card text (5) stays below right card border (7) — no forward bleed
  - Hover temporarily boosts z-index by +50 for clear visibility
  - `pivot_offset` at bottom-center makes rotation and scaling fan naturally from the bottom

## 2026-05-12 - Card Hand Fan Layout (Slay the Spire Style)
- Focus:
  - Increase card size to ~25% of viewport height (~270px at 1080p)
  - Implement Slay the Spire-style hand fan: overlapping cards with rotation arc
  - Cards can extend above/below hand container, must stay within width
- Completed:
  - Updated `demon-lords-commander/scripts/battle/card_ui.gd`:
    - `SCALE_HAND` increased from 0.15 to 0.23 (1168 * 0.23 = ~269px)
  - Updated `demon-lords-commander/scenes/BattleScene.tscn`:
    - Changed `HandCards` node type from `HBoxContainer` to `Control`
    - Removed `theme_override_constants/separation` (not applicable to Control)
    - Parent PanelContainer still fills the hand area as before
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - Added `_arrange_hand_cards()` function:
      - Calculates card overlap dynamically based on hand size and container width
      - Default overlap: 55% (cards occupy 45% of their width each step)
      - Tightens overlap down to 80% if hand is too wide for container
      - Centers the entire fan horizontally in the hand area
      - Applies rotation: up to +/- 12 degrees, linear from center to edges
      - Applies arc vertical offset: center cards lower, edge cards ~20px higher
      - Sets pivot to bottom-center of card so rotation fans naturally from the bottom
      - Bottom edge of all cards aligns to bottom of hand container
    - `_ready()`: connected `_hand_container.resized` signal to `_arrange_hand_cards()` for auto-relayout on window resize
    - `_rebuild_hand_cards()`: calls `_arrange_hand_cards()` after all cards added
    - `_start_card_drag()`: calls `_arrange_hand_cards()` after removing dragged card (closes the gap)
    - `_snap_card_back()`: calls `_arrange_hand_cards()` after returning dragged card
- Architecture Notes:
  - HandCards is now a plain Control node — children are positioned manually, not by container layout
  - Cards use `position` (not `layout_mode` anchors) since they're inside a non-container parent
  - `pivot_offset = Vector2(card_width/2, card_height)` makes rotation happen around bottom-center
  - `rotation_degrees` creates the fan effect; `arc_offset` adds subtle vertical curve
  - Cards extend above the hand container (no clipping) into the combat area above
  - No z-index changes needed: HandHudRow renders after CombatRow in tree order
- Future Work:
  - Hover effect: lift card straight up, remove rotation, slight scale increase
  - Card play animation from hand position to target
  - Hand shake / wobble when attempting to play an unplayable card

## 2026-05-12 - CardUI Scene Implementation (Reusable Card Template)
- Focus:
  - Implement a reusable, scalable CardUI scene for displaying cards with proper art, borders, names, costs, and effects
  - Replace hand card code-generation with scene instantiation
  - Add art_path and border_path to cards.json for data-driven card visuals
  - Ensure cards scale properly while maintaining aspect ratio (max 400px at 1920x1080)
- Completed:
  - Updated `demon-lords-commander/data/cards.json`:
    - Added `"art_path"` and `"border_path"` fields to all 15 card entries
    - Both fields point to temp assets (`cardarttest.png`, `cardbaseorange.png`) as placeholders
    - Fields are optional — code falls back to defaults if missing
  - Updated `demon-lords-commander/scripts/core/content_db.gd`:
    - Added validation for optional `art_path` and `border_path` fields (must be strings if present)
  - Created `demon-lords-commander/scripts/battle/card_ui.gd` (new file):
    - `class_name CardUI` with `CardSize` enum: `HAND` (~175px), `PREVIEW` (~350px), `FULL` (~400px)
    - `setup(card_data, size_preset)` API: configures border, art, name, mana cost, effect text
    - Proportional font scaling: font sizes scale with card size preset
    - `_safe_load_texture(path, fallback)`: loads textures with automatic fallback if missing/invalid
    - `set_unplayable_tint(enabled)`: fades card to 40% opacity when unplayable
    - `_format_effects(effects)`: human-readable effect text generator supporting all current effect types
      - DealDamage, GainBlock, DrawCards, GainMana, LoseHP, Lifesteal, ApplyDebuff, Summon, etc.
    - `get_card_id()` / `get_card_data()` accessors
  - Redesigned `demon-lords-commander/scenes/Card.tscn`:
    - Replaced absolute pixel offsets with anchor-based layout (proportional 0.0-1.0 anchors)
    - Root Control: `custom_minimum_size = Vector2(784, 1168)` (base design size)
    - `CardBorder` (TextureRect): `anchors_preset = FULL_RECT`, `expand_mode = FIT_WIDTH`, `stretch_mode = KEEP_ASPECT`
    - `CardArt` (TextureRect): proportional anchors for art area, keeps aspect ratio
    - `CardName` (Label): top area with proportional anchors, black font with outline
    - `ManaCost` (Label): top-center area, white font with outline
    - `EffectText` (Label): bottom area with autowrap, smaller font (40px base)
    - Attached `card_ui.gd` script with exported node references
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - Added `CardUIScene = preload("res://scenes/Card.tscn")` constant
    - Refactored `_rebuild_hand_cards()`: now instantiates `Card.tscn` instead of building from code
    - Calls `card_ui.call("setup", card, 0)` and `card_ui.call("set_unplayable_tint", not can_play)` via dynamic calls
    - Drag-and-drop metadata and signal connections remain unchanged
  - Updated `demon-lords-commander/GAME_SYSTEM_MAP.md`:
    - Added `CardUI` (`card_ui.gd` + `Card.tscn`) to Battle Sub-Services section
    - Added to File Priority list as item #10
    - Renumbered subsequent sections (29 total files)
- Architecture Notes:
  - CardUI uses `custom_minimum_size` + anchor layout for proportional scaling (no `scale` property)
  - Font sizes are dynamically adjusted via `add_theme_font_size_override()` based on size preset
  - `size_flags_horizontal = SIZE_SHRINK_CENTER` prevents HBoxContainer from stretching cards
  - All temp assets used as placeholders; swapping art/border is just a JSON path change
- Future Work:
  - Unique border art per card type (currently all use `cardbaseorange.png`)
  - Unique card art per card (currently all use `cardarttest.png`)
  - Border color tinting by card type (field reserved in JSON, not yet implemented)
  - Hover preview showing FULL-size card above the hand

## 2026-05-12 - Card Scene Added to Game Systems Map
- Focus:
  - Review game systems map for completeness
  - Note the new `Card.tscn` reusable card UI template
- Map Changes (`GAME_SYSTEM_MAP.md`):
  - Added `scenes/Card.tscn` to Scenes section (file #23)
    - Description: reusable card UI template (border, art, name, mana cost, effect text)
    - Uses MainTheme.tres
    - Contains CardBorder, CardArt, CardName, ManaCost, EffectText nodes
  - Updated Data/Content section numbering (24-28 instead of 23-27)
  - Updated Pre-Edit Checklist step 4 to reflect "all 28 project files"
- Current File Count: 28 total (7 Core, 8 Battle System, 3 UI/Presentation, 5 Scenes, 5 Data/Content)
- Note: `Card.tscn` is currently unused — BattleController dynamically creates card UIs via code in `_rebuild_hand_cards()`. This scene could be used as a template for future card instantiation.

## 2026-05-10 - Game Systems Map Update (Critical)
- Focus:
  - Future AI sessions must be able to discover all project files from the map alone
  - Add all missing battle sub-services, UI scripts, scenes, and data files to `GAME_SYSTEM_MAP.md`
- Map Changes (`GAME_SYSTEM_MAP.md`):
  - **Runtime Flow diagram**: Added all battle sub-services as child nodes under `BattleController`:
    - `CardPlayService`, `EffectResolver`, `TurnManager`, `BattleStateMachine`, `EnemyAI`
    - `EnemyAI` connects to `EnemyLibrary` and `IntentLibrary`
    - Added `VictoryScene` → `victory_screen.gd` flow from `MainController`
  - **System Ownership**: Added two new sub-sections:
    - `Battle Sub-Services` (7 entries): `CardPlayService`, `EffectResolver`, `TurnManager`, `BattleStateMachine`, `EnemyAI`, `EnemyLibrary`, `IntentLibrary`
    - `UI Scripts` (3 entries): `title_screen.gd`, `victory_screen.gd`, `main_waifu_sprites.gd`
  - **File Priority**: Restructured into 5 groups (Core, Battle System, UI/Presentation, Scenes, Data/Content). All 27 project files now documented:
    - Core (7): project.godot, signal_bus, game_state, battle_setup_service, content_db, save_manager, main_controller
    - Battle System (8): battle_controller, card_play_service, effect_resolver, turn_manager, battle_state_machine, enemy_ai, enemy_library, intent_library
    - UI / Presentation (3): title_screen.gd, victory_screen.gd, main_waifu_sprites.gd
    - Scenes (4): Main.tscn, TitleScreen.tscn, BattleScene.tscn, VictoryScreen.tscn
    - Data / Content (5): cards.json, waifus.json, enemies.json, save_template.json, MainTheme.tres
  - **Where To Add New Features**: Added guidance for card play effects, turn mechanics, battle phases, enemy AI, UI screens, and theme styles
  - **Pre-Edit Checklist**: Added step 4 — "Check the File Priority list above — all project .gd, .tscn, .json, and .tres files are documented there"
- Alignment Check Results:
  - All recent edits (`battle_controller.gd`, `card_play_service.gd`, `BattleScene.tscn`, `MainTheme.tres`, `main_waifu_sprites.gd`) remain within their ownership boundaries
  - No core service files touched; no new SignalBus contracts needed

## 2026-05-10 - Drag-and-Drop Card Play (Slay the Spire Style)
- Focus:
  - Implement drag-and-drop card play mechanics similar to Slay the Spire
  - Targeted cards (attacks) must be dropped on an enemy
  - Non-targeted cards (block, etc.) play when dragged far enough out of the hand
- Completed:
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - Added drag state vars: `_drag_card_ui`, `_drag_card_id`, `_drag_active`, etc.
    - Added `_process()`: updates dragged card position to follow mouse every frame
    - Added `_start_card_drag(card_ui)`: stores metadata, reparents card to root, scales it up 1.1x, sets z_index=10
    - Added `_end_card_drag()`: checks drop target or drag threshold, either plays or snaps back
    - Added `_find_enemy_drop_target()`: checks if mouse is over any visible, living enemy card rect
    - Added `_highlight_hovered_enemy()`: tints enemy cards yellow when hovered with a targeted card
    - Added `_snap_card_back()`: reparents card back to hand container at original index, resets scale/z_index
    - Added `_play_dragged_card(target_index)`: frees dragged card UI and calls `_play_card_by_id`
    - Added `_is_card_targeted(card_data)`: returns true if `type == "attack"` or `damage > 0`
    - Modified `_rebuild_hand_cards()`: each card stores `card_id` and `card_data` in metadata, connects `gui_input` signal
    - All card internal nodes set `mouse_filter = IGNORE` so the card Control captures all input
    - Cards with insufficient mana are visually faded (40% alpha) and cannot be dragged
    - Refactored `_on_card_pressed()` → `_play_card_by_id(card_id, target_enemy_index = -1)`
  - Updated `demon-lords-commander/scripts/battle/card_play_service.gd`:
    - `play_card()` now accepts optional `target_enemy_index: int = -1`
    - `_resolve_card_effects()` routes damage:
      - If `target_enemy_index >= 0`: applies damage only to that specific living enemy
      - Otherwise: applies AoE damage to all living enemies (backward compatible)
    - Block, draw, and mana effects remain unchanged (always self-targeted)
- Drag Rules:
  - **Targeted cards** (attack/damage): must be dropped directly onto an enemy card's rect
    - Dead enemies are ignored
    - Invisible enemy cards are ignored
    - Hovered enemies glow yellow
    - If dropped outside any enemy, card snaps back to hand
  - **Non-targeted cards** (block, draw, gain_mana): play if dragged upward so card bottom is above `hand_top - card_height * 0.8`
    - This means the card must be ~80% out of the hand area
    - If not dragged far enough, card snaps back to hand
  - **Insufficient mana**: cards are faded and cannot be dragged
  - **Visual feedback**: dragged cards scale to 1.1x and lift above other UI (z_index=10)
- Notes:
  - The `_on_card_pressed()` click handler was removed; cards are now purely drag-and-drop
  - Snap-back preserves original hand position using `move_child()` to restore index
  - Future: add drag preview animation, trail particles, or card hover tooltip

## 2026-05-10 - Smaller Battle Fonts + Non-Button Hand Cards
- Focus:
  - Reduce font sizes across the entire battle scene (text was too large)
  - Convert hand cards from clickable Buttons to non-interactive Controls for future drag-and-drop
- Completed:
  - Updated `demon-lords-commander/assets/art/ui/MainTheme.tres`:
    - Added `BattleSmallest` (16px), `BattleSmall` (18px), `BattleMedium` (20px), `BattleButton` (20px) variations
    - `BattleButton` inherits Button styles but with 20px font instead of 72px
    - TitleScreen/VictoryScreen variations remain unchanged at original sizes
  - Updated `demon-lords-commander/scenes/BattleScene.tscn`:
    - All labels now use battle-specific smaller sizes:
      - `MainWaifuCard/StatsLabel`: `BattleMedium` (20px, was 48px)
      - `Summon1/2/3Card/StatsLabel`: `BattleSmall` (18px, was 32px)
      - Enemy `IntentLabel` + `StatsLabel`: `BattleSmallest` (16px, was 24px)
      - `DrawPileCountLabel`, `ManaLabel`, `PlayerHPLabel`, `DiscardPileCountLabel`: `BattleSmall` (18px, was 32px)
      - `EndTurnButton`: `BattleButton` (20px, was 72px)
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - Renamed `_rebuild_hand_buttons()` → `_rebuild_hand_cards()`
    - Cards are now built as `Control` nodes containing:
      - `PanelContainer` (card background)
      - `VBoxContainer` (vertical layout)
      - `TextureRect` (card art from `cardarttest.png`)
      - `Label` with `BattleSmall` theme (name + cost)
    - Removed `Button.pressed` click handler — cards are no longer clickable
    - Unplayable cards (insufficient mana / battle over) fade to 40% alpha as visual feedback
    - `_on_card_pressed()` function is preserved in the file for future drag-and-drop hookup
- Notes:
  - Cards are now visual-only; no click-to-play until drag-and-drop is implemented
  - All Merriweather font sizes in battle scene are now 16-20px, much more appropriate for dense UI
  - TitleScreen and VictoryScreen still use large 48-140px variations for title/menu text
- Focus:
  - Fix null instance error from `battle_controller.gd` unable to find labels after VBox reorganization
  - Apply `MainTheme.tres` to the ENTIRE battle scene, not just enemy cards
- Completed:
  - Fixed `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - Updated `_populate_enemy_ui_arrays()` to use `InfoVBox/StatsLabel` and `InfoVBox/IntentLabel` paths
    - This resolved the `Invalid assignment of property or key 'text' with value of type 'String' on a base object of type 'null instance'` error
  - Updated `demon-lords-commander/scenes/BattleScene.tscn`:
    - Added `theme = ExtResource("6_mtres")` to the root `BattleScene` node — cascades to all children
    - Removed ALL hardcoded `theme_override_colors/font_color = Color(1, 1, 1, 1)` from every label (theme already defines white)
    - Applied `theme_type_variation` to every label and button in the scene:
      - `MainWaifuCard/StatsLabel`: `&"Medium"` (48px Merriweather)
      - `Summon1/2/3Card/StatsLabel`: `&"Small"` (32px)
      - Enemy `IntentLabel` + `StatsLabel` (in `InfoVBox`): `&"Smallest"` (24px)
      - `DrawPileCountLabel`, `ManaLabel`, `PlayerHPLabel`, `DiscardPileCountLabel`: `&"Small"` (32px)
      - `EndTurnButton`: `&"Buttonlarge"` (72px Merriweather with styled textures)
  - Updated `demon-lords-commander/scripts/battle/main_waifu_sprites.gd`:
    - Changed `$StatsLabel` and `get_node_or_null("IntentLabel")` to `find_child("...")` lookups
    - Works whether labels are direct children or nested in `InfoVBox`
- Notes:
  - Entire battle scene now uses Merriweather font from `MainTheme.tres` with consistent sizing
  - `TitleScreen.tscn`, `VictoryScreen.tscn`, and `BattleScene.tscn` all share the same theme
  - No more hardcoded font colors anywhere in the battle scene

## 2026-05-10 - Enemy Intent Positioning + Resolution Fix
- Focus:
  - Move enemy intent labels above the enemy portrait (above the enemy's head)
  - Fix intent display to show resolved pattern names and values instead of raw JSON data
  - Ensure portrait scaling never overlaps top labels
- Completed:
  - Updated `demon-lords-commander/scenes/BattleScene.tscn`:
    - Moved all 4 `IntentLabel` nodes from bottom (anchors_preset=12) to top (anchors_preset=10), positioned above the portrait
    - Moved all 4 `StatsLabel` nodes just below the intent labels (offset_top=22, offset_bottom=37)
    - Set `bottom_reserved = 0.0` on all enemy cards since labels are no longer at the bottom
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - `_refresh_ui()` now calls `_enemy_ai.get_current_intent(enemy_state, intent_index)` for each enemy
    - Displays the resolved `display_name` from `EnemyLibrary` intent patterns
    - Shows actual `damage` and `block` values from resolved `params` (e.g., "Intent: Light Attack (5 dmg)")
    - Removed broken raw-intent lookup that was reading non-existent `name`/`damage`/`block` keys on pattern_id objects
  - Updated `demon-lords-commander/scripts/battle/main_waifu_sprites.gd`:
    - Added `@onready var intent_label` reference (null-safe via `get_node_or_null`)
    - `_position_portrait()` now computes the bottom of BOTH labels and uses the maximum as the start of the portrait area
    - Prevents sprite overlap even if either label wraps to multiple lines
- In Progress:
  - Per-enemy targeting for card attacks (currently AoE)
- Next Session:
  - Add per-enemy target selection UI so attacks can hit a single enemy
  - Add `portrait_path` or `sprite_frames_path` to enemy data for per-enemy art
- Notes/Risks:
  - Enemy intent system is now fully wired: `enemies.json` pattern_id → `EnemyLibrary` resolution → `EnemyAI` execution → `BattleController` display
  - Intent labels at the top with stats just below them creates a clean "intent above head, stats below" layout for each enemy

## 2026-05-10 - Multiple Enemy Support + Sprite Anchor System
- Focus:
  - Support up to 4 enemies on the field like the player side
  - Keep sprites inside their card boxes and scale with screen size
  - Future-proof enemy data for different sprite sizes and anchors
- Completed:
  - Updated `demon-lords-commander/scenes/BattleScene.tscn`:
    - Added `EnemyCard2`, `EnemyCard3`, `EnemyCard4` matching player summon layout
    - Added `LeftSpacer` and `RightSpacer` to `EnemyCardsRow` for dynamic centering
    - Attached `main_waifu_sprites.gd` to all 4 enemy cards with `bottom_reserved = 35.0`
    - Added `theme_override_constants/separation = 8` to enemy row
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd`:
    - Replaced single `_enemy_state` with `_enemy_states` array
    - Removed global `_intent_index`; each enemy now tracks its own `intent_index`
    - Added `_populate_enemy_ui_arrays()` to discover all 4 enemy card nodes
    - Enemy turn now loops through all living enemies and resolves each intent sequentially
    - Victory condition requires **all** enemies to be dead (`_all_enemies_dead()`)
    - `_refresh_ui()` now displays each enemy individually and hides unused slots
    - Added `_update_enemy_board_layout()` that adjusts spacers based on active enemy count
  - Updated `demon-lords-commander/scripts/core/battle_setup_service.gd`:
    - Now accepts `enemy_ids` array in payload (falls back to single `enemy_id` for backward compatibility)
    - Builds `enemies` array in setup payload
    - Updated validation to check the `enemies` array and each enemy's required fields
  - Updated `demon-lords-commander/scripts/battle/card_play_service.gd`:
    - Changed signature to accept `enemy_states: Array[Dictionary]`
    - Attack damage is now applied to **all living enemies** (interim AoE targeting)
  - Updated `demon-lords-commander/scripts/battle/main_waifu_sprites.gd`:
    - Added `@export_enum("bottom", "center") var sprite_anchor` for ground vs flying enemies
    - Added `@export var bottom_reserved` to keep space for intent labels below the portrait
    - Portrait positioning now respects `bottom_reserved` and switches between bottom-anchor and center-anchor logic
  - Added `sprite_anchor` field to `demon-lords-commander/data/enemies.json` for both existing enemies (default "bottom")
  - Updated `demon-lords-commander/scripts/core/content_db.gd` to validate `sprite_anchor` is "bottom" or "center"
  - Updated `demon-lords-commander/scripts/core/battle_setup_service.gd` to pass `sprite_anchor` through to battle controller
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd` to assign `sprite_anchor` to each enemy card at runtime
- In Progress:
  - Per-enemy targeting for card attacks (currently AoE to all living enemies)
- Next Session:
  - Add per-enemy target selection UI so attacks can hit a single enemy
  - Add `portrait_path` or `sprite_frames_path` to enemy data for per-enemy art
  - Add `sprite_scale` or custom `min_size` overrides per enemy for very large/small foes
- Notes/Risks:
  - Enemy art is still hardcoded in the scene (shared `SpriteFrames` sub-resource). Adding per-enemy art will require either runtime sprite_frames assignment or PackedScene instantiation.
  - All attack cards currently hit every living enemy; single-target cards will need a target-selection phase before damage resolution.

## 2026-05-10 - Enemy Intent Library System + Victory Screen
- Focus:
  - Split enemy logic and intent into reusable library system
  - Create first test enemy for gameplay loop validation
  - Add basic victory screen flow
- Completed:
  - Created `intent_library.gd` with reusable intent types (attack, block, buff, debuff) and execution logic
  - Created `enemy_library.gd` with intent pattern templates that enemies can reference
  - Refactored `enemy_ai.gd` to use IntentLibrary and EnemyLibrary for separation of concerns
  - Updated `enemies.json` to use pattern_id references instead of inline intent data
  - Added enemy schema validation to `content_db.gd`
  - Added Test Goblin enemy (20 HP, 5 damage attack) to `enemies.json`
  - Updated SaveManager defaults and save_template.json to use test goblin
  - Updated battle_controller.gd fallback enemy to use test goblin
  - Added `reset_save()` function to SaveManager
  - Added "Reset Save" button to title screen UI
  - Fixed parse errors in intent_library.gd (replaced inline functions with regular methods)
  - Added class_name declarations to IntentLibrary and EnemyLibrary
  - Fixed battle_controller.gd phase stuck on end_check after card play
  - Added victory screen system:
    - Added `victory_screen_requested` and `return_to_title_requested` signals to SignalBus
    - Created VictoryScreen.tscn with "YOU WIN" text and return button
    - Created victory_screen.gd script
    - Updated battle_controller.gd to emit victory signal on win
    - Updated main_controller.gd to handle victory screen navigation
- In Progress:
  - Testing complete game loop with Test Goblin
- Next Session:
  - Implement enemy intent preview UI (show what enemy will do next turn)
  - Add more enemy variety with different intent patterns
  - Implement battle end rewards/outcome handling
  - Art pass on battle scene
- Notes/Risks:
  - Save file still contains hardcoded test data for deck/waifu selection (missing UI systems)
  - Enemy intent system is now modular and extensible for future content
  - Victory screen is temporary placeholder for future rewards system

## Entry Template

```md
## YYYY-MM-DD - Session Title
- Focus:
- Completed:
  - ...
- In Progress:
  - ...
- Next Session:
  - ...
- Notes/Risks:
  - ...
```

## 2026-05-10 - Title Input Trace Upgrade
- Focus:
  - Capture mouse events earlier in the input chain to determine if clicks are blocked before button signals.
- Completed:
  - Updated `demon-lords-commander/scripts/ui/title_screen.gd`:
    - added startup logging of New Game `mouse_filter` and `focus_mode`,
    - added `_input` left-click logging (pre-GUI consumption),
    - kept existing `gui_input`, `button_down`, `pressed`, and `_unhandled_input` logs.
  - Verified no linter errors after instrumentation update.
- In Progress:
  - Isolating whether input is blocked at window/input layer or at Control-node GUI routing.
- Next Session:
  - Use next log sample to classify failure point and either:
    - fix UI input blockers in `TitleScreen.tscn`, or
    - instrument `GameState` and `MainController` if press events are confirmed.
- Notes/Risks:
  - Temporary debug verbosity is high by design for fast diagnosis and will be removed after fix confirmation.

## 2026-05-10 - Deep Title Input Diagnostics
- Focus:
  - Determine whether New Game click events are reaching the button or being intercepted before signal emission.
- Completed:
  - Expanded `demon-lords-commander/scripts/ui/title_screen.gd` diagnostics:
    - connected and logged `_new_game_button.button_down`,
    - connected and logged `_new_game_button.gui_input` for left mouse click,
    - added `_unhandled_input` global click log with hovered control name,
    - extended `_ready` log to include New Game button state (`disabled`, `visible`).
  - Kept existing New Game pressed/signal logs in place.
  - Verified no linter errors after diagnostics update.
- In Progress:
  - Collecting next run logs to locate where input stops (global click -> button gui_input -> button_down -> pressed).
- Next Session:
  - If global clicks log but button logs do not, inspect layout/input blockers in `TitleScreen.tscn`.
  - If button logs fire but no phase transition occurs, instrument `GameState` and `MainController` events next.
- Notes/Risks:
  - Debug logs are intentionally verbose and should be removed once the click path is stable.

## 2026-05-10 - Title Screen Click Debug Added
- Focus:
  - Add direct runtime visibility to title-button click handling for New Game troubleshooting.
- Completed:
  - Updated `demon-lords-commander/scripts/ui/title_screen.gd` with debug prints:
    - on `_ready` to confirm button signal hookups are active,
    - before and after `SignalBus.request_new_game()` in `_on_new_game_pressed`.
  - Verified no linter errors in the updated file.
- In Progress:
  - Tracing full New Game event chain from title click to phase change and battle scene transition.
- Next Session:
  - If click logs fire but battle still does not load, add logs in `GameState`, `BattleSetupService`, and `MainController` to pinpoint break location.
  - Optionally surface setup-failure reason in visible title UI text for faster manual testing.
- Notes/Risks:
  - Debug `print` calls are temporary diagnostics and should be removed after flow is stable.

## 2026-05-10 - New Game Click Reliability Fix
- Focus:
  - Resolve "New Game does nothing" behavior caused by phase state becoming stuck at `hub`.
- Completed:
  - Updated `demon-lords-commander/scripts/core/game_state.gd`:
    - In `_on_new_game_requested`, if already in `PHASE_HUB`, force `PHASE_TITLE` first, then set `PHASE_HUB`.
    - Applied the same guard in `_on_continue_requested`.
  - This guarantees a fresh phase transition edge so `MainController` re-runs battle setup requests.
  - Verified no linter errors after the change.
- In Progress:
  - Re-testing startup and transition robustness under repeated title-screen clicks.
- Next Session:
  - Add short debug logs around phase changes and battle setup failure reason for faster diagnosis.
  - If click issue persists, surface setup-failure reason in UI (not only warnings) so it is visible in play mode.
- Notes/Risks:
  - This fixes a likely stuck-state path; additional runtime logs may still be needed if setup fails for data reasons.

## 2026-05-10 - Battle Controller Cleanup Pass
- Focus:
  - Remove redundant legacy methods from `battle_controller.gd` now that dedicated battle services are wired.
- Completed:
  - Removed unused class variable `_player_cards_row` from `demon-lords-commander/scripts/battle/battle_controller.gd`.
  - Removed obsolete helper methods no longer needed after service extraction:
    - `_apply_start_of_turn_waifu_effects`
    - `_draw_cards`
    - `_draw_one_card`
    - `_resolved_attack_damage`
    - `_resolve_card`
    - `_apply_damage_to_enemy`
    - `_apply_damage_to_player`
  - Kept battle flow behavior intact through existing service calls (`TurnManager`, `CardPlayService`, `EnemyAI`, `EffectResolver`).
  - Verified no linter errors after cleanup.
- In Progress:
  - Preparing runtime visibility improvements for fast in-editor battle verification.
- Next Session:
  - Add temporary debug logs for phase transitions, intent execution, and battle-end payload.
  - Run a smoke test of full flow: title -> new game -> battle -> victory/defeat -> return.
  - If stable, start extracting battle-end rewards/outcome handling into a dedicated service.
- Notes/Risks:
  - UID texture warnings in `BattleScene.tscn` are still deferred and can be cleaned later in-editor.

## 2026-05-10 - Card Pipeline Service + Battle Setup Guard
- Focus:
  - Improve test-battle reliability by splitting card play flow and validating setup payloads before battle scene entry.
- Completed:
  - Added `demon-lords-commander/scripts/battle/card_play_service.gd` for the full single-card play pipeline:
    card lookup, mana legality, effect resolution, draw/block/mana updates, and discard move.
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd` to delegate card play to `CardPlayService`.
  - Added setup contract validation in `demon-lords-commander/scripts/core/battle_setup_service.gd`:
    - schema key `schema_version`,
    - required field checks (`waifu_id`, `enemy`, `deck`),
    - enemy payload sanity checks and non-empty deck requirement,
    - fail-fast path via `battle_setup_failed` if validation fails.
  - Verified no linter errors in changed files.
- In Progress:
  - Stabilizing battle orchestration while removing legacy helper paths from controller.
- Next Session:
  - Remove now-redundant legacy card helper methods from `battle_controller.gd`.
  - Add temporary debug logs for phase transitions and intent execution to speed up test verification.
  - Create a small smoke-test checklist for a full battle run (new game -> victory/defeat -> return flow).
- Notes/Risks:
  - Save/content fallback behavior still exists by design; it keeps flow playable but can mask upstream data problems.

## 2026-05-10 - Warning Cleanup (Seed Rename)
- Focus:
  - Remove non-critical engine warning noise while keeping momentum on battle development.
- Completed:
  - Renamed `new_campaign(seed: int = -1)` to `new_campaign(run_seed_value: int = -1)` in `demon-lords-commander/scripts/core/game_state.gd`.
  - Updated internal usage in that function accordingly.
  - Verified no linter issues after change.
- In Progress:
  - Preparing next battle implementation pass for a stable test battle loop.
- Next Session:
  - Run an in-editor test battle and verify phase transitions/logs (`round_start -> player_turn -> enemy_turn -> end_check`).
  - Extract card play pipeline into a dedicated service.
  - Add battle setup payload validation/version key.
- Notes/Risks:
  - Remaining warnings were intentionally deferred per request.

## 2026-05-10 - Enemy AI + Battle Phase Machine Extraction
- Focus:
  - Continue splitting battle runtime into clear service ownership with explicit turn phases.
- Completed:
  - Added `demon-lords-commander/scripts/battle/enemy_ai.gd` for enemy intent selection and intent index rotation.
  - Added `demon-lords-commander/scripts/battle/battle_state_machine.gd` with explicit phases:
    `round_start`, `player_turn`, `enemy_turn`, `end_check`, `battle_over`.
  - Updated `demon-lords-commander/scripts/battle/battle_controller.gd` to:
    - delegate enemy turn execution to `enemy_ai.gd`,
    - gate card play/end-turn actions through phase checks,
    - transition through explicit battle phases during round flow,
    - display current phase in the persistent status UI.
  - Verified no linter errors in changed battle scripts.
- In Progress:
  - Continuing decomposition of battle controller responsibilities while preserving current behavior.
- Next Session:
  - Extract card play pipeline and battle-end handling into dedicated services.
  - Add explicit signal contract section for battle events (commands vs notifications).
  - Introduce battle payload validation/version checks before battle scene entry.
- Notes/Risks:
  - Legacy helper methods still exist in `battle_controller.gd`; cleanup can continue once behavior is validated in playtesting.

## 2026-05-10 - Battle System Foundation Review + Initial Split
- Focus:
  - Review architecture and stabilize battle-system workflow for iterative development.
- Completed:
  - Reviewed `GAME_SYSTEM_MAP.md`, project overview, and current core runtime files.
  - Confirmed playable battle loop wiring through `SignalBus` + `BattleSetupService` + `BattleController`.
  - Added this shared changelog process for continuity between sessions.
- In Progress:
  - Splitting `battle_controller.gd` into smaller battle services while keeping behavior stable.
- Next Session:
  - Finalize service split with clear ownership (`TurnManager`, `EffectResolver`, then `EnemyAI`/state machine).
  - Add explicit `battle_setup_payload` schema contract + validator.
  - Define battle signal contract list (command vs notification).
- Notes/Risks:
  - Current runtime still relies on some fallback data paths; these can hide setup/data errors.
