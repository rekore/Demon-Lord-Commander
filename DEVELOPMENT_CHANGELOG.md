# Development Changelog

This file tracks coding progress between long breaks.
After each meaningful session, add a new entry at the top.

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
