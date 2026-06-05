# Running Plan — Demon Lord's Commander

> **Purpose**: Living document. After each session, update the **Next Up** section with the most valuable things to tackle next, ordered by impact. Archive completed items into the **Done** log below.
>
> Read this at the START of every new session before touching any code.

---

## Next Up (Ordered by Priority)

### 1. Rest Node Screen — HIGH
**Why**: Rest floors currently auto-complete with no effect. Survivability has no recovery mechanism in the dungeon.

**What to build**:
- Simple screen: show current HP, a "Rest (Recover 25% Max HP)" button, and a "Meditate (+1 Max Draw next battle)" button.
- One choice, then `DungeonService.complete_node()`.
- New scene: `scenes/RestScreen.tscn` + `scripts/ui/rest_screen.gd`.
- Wire in `main_controller.gd` `"rest"` case (currently a TODO stub).
- HP recovery writes directly to `GameState.player["current_hp"]` (clamped to max).

---

### 2. More Enemies (5–8 new enemies) — HIGH
**Why**: Two enemies in a 15–50 floor dungeon = immediate repetition death. Every enemy scales automatically — this is purely data work in `enemies.json` + adding sprites.

**Suggested additions** (with distinct intent patterns to create varied feel):
- `enemy_skeleton_warrior` — block-heavy, guard_up + shield_bash + heavy_attack
- `enemy_cave_troll` — high HP, slow but hits hard; slam + rest + double_attack
- `enemy_dark_cultist` — applies debuffs; curse + drain + light_attack
- `enemy_shadow_hound` — fast multi-hit; quick_bite + quick_bite + pounce
- `enemy_necromancer` — summons skeleton adds; summon + curse + light_attack
- `enemy_stone_golem` — elite tier; stomp + guard_up + smash

Each needs: `id`, `name`, `max_hp`, `sprite_anchor`, `intents[]` in `enemies.json`. Sprite can be a placeholder initially.

---

### 3. Event Service (Resolve Event Effects) — MEDIUM
**Why**: Events show correctly in the dungeon UI but all auto-complete with no effect. The data schema is complete — just needs a resolver.

**What to build**:
- New autoload `EventService` (or integrate into `DungeonService`) that reads `event_id` from `pending_node` and resolves choices.
- Implement effect types: `heal_percent`, `damage_percent_max`, `gain_gold`, `lose_gold`, `gain_strength`, `add_floor_modifier`, `nothing`.
- New scene: `scenes/EventScreen.tscn` — shows event name, flavour text, and choice buttons.
- Wire in `main_controller.gd` `"event"` case (currently a TODO stub).

---

### 4. Run Relic Integration in BattleSetupService — MEDIUM
**Why**: Run relics are collected and saved in `current_dungeon_run["run_relics"]` but `BattleSetupService` doesn't read them — they have zero in-battle effect right now.

**What to fix**:
- `BattleSetupService._build_setup_payload()` merge `run_relics` into the `relic_buffs` array alongside shop relics.
- `RelicEffectResolver` (future) will resolve both types identically.

---

### 5. Corruption Meter — MEDIUM
**Why**: Central narrative mechanic per project overview. Affects card abilities, story branches, and ending outcomes. Scaffolding it now prevents painful retrofitting across all systems later.

**What to build**:
- Add `corruption: 0` to `GameState.player` (range 0–100).
- Small HUD display in `BattleScene` (red orb / meter, top corner).
- Basic increment hooks: certain card effects, story event outcomes, high-level dungeon boss kills.
- No card modification logic yet — just the state field and display.

---

### 6. Merchant / Sell Screen — MEDIUM
**Why**: Players collect trash and materials but have no way to spend or sell them yet. Closing this loop gives loot immediate value.

**What to build**:
- Hub-world merchant scene showing `SaveManager.profile["trash"]` inventory with sell prices.
- Selling converts trash → gold via `SaveManager`.
- Stretch: materials → craft permanent relics here.

---

### 7. Dungeon Penalty Curve Tuning — MEDIUM
**Why**: Current penalty formula is a placeholder. At level 100 enemies are 15.85× base — this needs a proper curve so late dungeons are hard but not instantly lethal.

**What to tune**:
- Consider a logarithmic or piecewise curve for HP scaling instead of linear `×0.15 per level`.
- Finalize player penalty caps — current max is draw -3 / mana -2, which may be too mild at level 50+.
- Both formulas live in `BattleSetupService` and `DungeonService` — isolated changes, no ripple effects.

---

### 8. Bond Node / Dialogic Integration — LOW
**Why**: Bond floors auto-complete. Waifu bond levels can't increase during dungeon runs.

**What to build**:
- Trigger a Dialogic timeline when a bond node is entered (waifu-specific short scene).
- At timeline end, increment `SaveManager.profile["bond_levels"][waifu_id]` via signal.
- Wire `main_controller.gd` `"bond"` case to `SignalBus.request_dialogue_start(waifu_id + "_bond_scene")`.

---

## Done Log

### Session 2026-06-03
**Battle Victory Screen + Loot System** (full dungeon loop now playable):
- ✅ `data/loot_items.json` — 13-item global pool: trash (4), materials (4, level-gated), consumables (3), card packs (2)
- ✅ `data/relics.json` — `relic_type` field added to all entries; 5 new run relics with `min_level` + `weight` for drop pool
- ✅ `data/enemies.json` — `bonus_drops[]` on each enemy for thematic weight boosts
- ✅ `data/dungeons.json` — `local_loot[]` on `dungeon_catacombs`: 3 trash + 3 material items unique to this zone
- ✅ `signal_bus.gd` — `dungeon_rewards_claimed` signal + broadcast helper
- ✅ `save_manager.gd` — `materials{}`, `consumables[]`, `trash{}` added to base profile; `run_relics[]` inside `current_dungeon_run`
- ✅ `content_db.gd` — `_ingest_loot_items()`, `get_loot_items_for_level()`, `get_all_cards()`, `get_run_relics_for_level()`
- ✅ `dungeon_service.gd` — `generate_battle_loot()`, `apply_loot_rewards()`, `_build_loot_pool()`, `_loot_weighted_pick()`, `_pick_card_choices()`. Scales with dungeon level + node type.
- ✅ `BattleVictoryScreen.tscn` + `battle_victory_screen.gd` — gold auto-collected; loot pops in with stagger tween; click-to-collect per item; 3 card choices (rarity-weighted, level-scaled); skip option; Continue unlocks after card resolved
- ✅ `main_controller.gd` — victory → generate loot → show `BattleVictoryScreen`; `dungeon_rewards_claimed` → `complete_node()`
- ✅ Architecture confirmed: three relic tiers (`shop`/`run`/`crafted`), two-layer loot pool (global + dungeon-local), enemy bonus weights

**Victory Screen Overhaul + Tooltip System** (same date, later pass):
- ✅ `tooltip_manager.gd` — new global autoload (`TooltipManager`). `PanelContainer` auto-sizes to content, 85% opacity dark bg, amber title + separator + body, follows cursor, clamps to viewport, fade-in tween. Registered in `project.godot`.
- ✅ Card rewards conditional by node type — boss 100%, elite 60%, normal 35%. Section hidden entirely when no card rolled.
- ✅ `battle_victory_screen.gd` fully refactored — `_build_ui()` is now a static skeleton only; `set_loot()` dynamically inserts per-type sections into `_content_vbox` at runtime.
- ✅ Reward display order enforced: **RUN RELICS → CARD PACKS → CARD REWARD → MATERIALS → SPOILS → Gold**. Each section only appears if that type was actually received.
- ✅ Card reward uses real `scenes/Card.tscn` at `CardSize.FULL` — not a bespoke panel builder. No tooltips on cards (card already shows all info).
- ✅ Card re-selection — player can freely change their card pick until they press Continue. Skip also keeps cards clickable so player can reverse the skip.
- ✅ Loot rows: 740px centred column, coloured left-accent border per type, 28px item name, slide-in stagger tween, hover tooltip with name+description.

---

### Session 2026-05-31
**Dungeon Run System Framework** (full pipeline built earlier this date — see `DEVELOPMENT_CHANGELOG.md` for detail):
- ✅ `dungeon_service.gd` autoload — run state, choice generation, boss detection, signal pipeline
- ✅ `DungeonChoiceScreen` — 3-card fog-of-war node picker
- ✅ `level_flag` system — dungeon difficulty overridable by story flags at runtime
- ✅ Player penalties per dungeon level (draw/mana reduction, injected into battle payload)
- ✅ `bond` + `rest` node types added
- ✅ Story boss flags + forced floor system

**Adaptive Generator + Level 1–100 Expansion** (same date):
- ✅ Dungeon levels extended to 1–100 (scaling formula + placeholder penalty curve)
- ✅ `floor_history[]` in run state — tracks last 5 completed node types
- ✅ `ADAPTIVE_RULES` — 6 data-driven rules preventing RNG streaks (elite/rest/bond streaks, combat/event droughts)
- ✅ `_apply_adaptive_weights()` — runs before every non-forced floor generation

**Dynamic Floor Count** (same date):
- ✅ `base_floors` replaces `total_floors`/`boss_floor` in `dungeons.json`
- ✅ Runtime formula: `clamp(base_floors + floori((level-1)/5)*2, 15, 50) + floor_bonus`
- ✅ `add_floor_modifier(n)` — public API for relics/story to adjust floor count mid-run
- ✅ `dungeon_catacombs` updated to `base_floors: 15` with 5-tier floor_configs covering floors 1–999
- ✅ `total_floors`, `boss_floor`, `floor_bonus` added to `SaveManager` default profile and computed fresh at `start_run()`

**Tiered Event System** (same date):
- ✅ Enemy scaling confirmed fully implemented — universal HP + damage multiplier in `BattleSetupService`, zero per-enemy code needed
- ✅ `events.json` — 10 events in 3 tiers: Level 1+ (4), Level 5+ (3), Level 10+ (3)
- ✅ `ContentDB.get_events_for_level(dungeon_level)` confirmed working (was pre-built)
- ✅ `DungeonService._pick_event_for_level()` — weighted random from level-eligible pool
- ✅ `_build_node()` pre-selects event and stores `event_id`/`event_name`/`event_description` in node dict
- ✅ **Blind event choice** — event identity NOT shown on choice card; player sees generic atmospheric label only; event revealed when they enter

**Session Tooling** (same date):
- ✅ `running_plan.md` created — AI-suggested next steps, living document updated each session
- ✅ `GAME_SYSTEM_MAP.md` updated — `running_plan.md` listed at position 0 in File Priority with clear "suggestions only" framing
