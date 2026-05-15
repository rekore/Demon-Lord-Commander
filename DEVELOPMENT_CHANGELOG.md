# Development Changelog

This file tracks coding progress between long breaks.
After each meaningful session, add a new entry at the top.

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
