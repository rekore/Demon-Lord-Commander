# Rules Bible: [Game Name TBD] - Core Card Game Mechanics
## 1. Overview
- Single-player turn-based deckbuilding RPG in a dark fantasy world.
- Core loop: Explore story → Accept missions (quests) → Build/swap deck from Library → Fight battles (Slay the Spire-style combat) → Win rewards → Persist progress (library grows, waifus bond, story advances).
- Combat is strictly 1v1 or 1vMulti-enemy boss/encounter style—no party members in fights; power comes from deck + waifu effects.
- Persistent campaign: No roguelike resets. Death = game over / reload checkpoint, but library and story progress saved.

## 2. Deck & Library System
- **Library**: Unlimited collection of all acquired cards. Grows permanently via mission rewards, events, shops, waifu gifts, etc.
- **Deck Building**:
  - Minimum deck size: 20 cards.
  - Maximum deck size: 100 cards.
  - **Maximum copies of any single card in a deck: 4** (regardless of rarity).
  - Players freely edit decks outside combat (in hub town, camp, between missions).
  - Tools: Sorting/filtering by type, cost, archetype, keyword; favorites; templates for quick swaps.
- **Deck Usage**: Select one deck per mission. Can't change mid-mission (encourages planning around mission effects/length).
- **Card Acquisition/Removal**:
  - Add cards via rewards (common after short/medium, rarer/epic bosses).
  - Removal/Upgrades: Available in hub (smithy, shrine, etc.)—costs gold, favors, or waifu-specific resources.
  - **Duplicate Handling (Post-Collection)**: Once the player has collected **4 copies** of any card in their Library, any additional copies of that card received as rewards are automatically converted into **Waifu Skin Currency** instead of being added to the Library:
    - Common card duplicate → 1 Skin Currency
    - Mythic card duplicate → 20 Skin Currency
    - (Rarities in between and exact skin costs to be determined later)
  - **Note**: *Add systems to prevent extreme bloat (e.g., "retire for relic" mechanic, archetype-locked upgrades).*

## 3. Combat Mechanics (Core Loop)
- Turn-based, mana-based card play (inspired by Slay the Spire).
- Player starts each battle with:
  - Base mana: 3 (upgradable via gifts/cards/waifus).
  - Draw: 5 cards per turn (modifiable).
- Cards types (broad categories—expand later):
  - Attack: Deal damage.
  - Skill/Defense: Block, draw, buffs/debuffs.
  - Power: Persistent effects for battle (or sometimes campaign?).
  - Special: Waifu-synergy, summons, curses, etc.
- **Damage & Protection Priority**:
  - Incoming damage first depletes player's current **Block** (temporary shield that resets to 0 at start of player turn unless modified).
  - After Block is depleted, damage hits player's **HP**.
  - **Summons** (if active) take damage **only after** player Block is gone and before player HP is hit (they act as an additional damage buffer layer).
- Keywords/mechanics to include (**expandable list**—core effects on cards, relics, waifus, mission modifiers):
  - **Buffs (Player-scaling positives, usually stackable)**:
    - Strength: +X damage on all Attacks this combat (or next few turns).
    - Dexterity: +X Block on all Skills this combat.
    - Vigor / Focus / archetype scalers (e.g., +X Bleed/Poison applied).
    - Artifact: Immune to debuffs for X turns.
  - **Debuffs (Enemy-scaling negatives, visible on intents)**:
    - Vulnerable: Enemy takes +50% damage.
    - Weak: Enemy deals -25–40% damage.
    - Poison / Bleed: DoT stacks, damage at start/end of enemy turn.
    - Frail: Reduced Block gain.
  - **Card Flow & Economy Manipulation**:
    - Draw +X cards (immediate or end-of-turn).
    - Discard X cards (from hand; can be targeted or random).
    - Exhaust: Card removed from combat (to Exhaust pile; can't be redrawn this fight).
    - Retain: Card stays in hand instead of discarding at end of turn.
    - Copy: Create a temporary duplicate of a card in hand/discard/draw pile (often Exhausts after play).
    - Scry X: Look at top X cards, discard/keep/rearrange some.
  - **Turn & Action Economy**:
    - Extra Turn: Immediately take another full turn (very high-power, rare; often costs big resources or has backlash).
    - Gain Mana: +X Mana this turn or permanent in combat.
    - Lose Mana: Penalty (mission modifiers or curses).
  - **Persistent / Power Effects**:
    - Power cards grant ongoing effects (e.g., at start of turn: draw 1, gain 1 Strength).
    - **Summons / Minions**:
      - Summon cards create temporary creatures on the field (max **3 summons** active at once; new summons beyond limit replace oldest or fail).
      - Summons have their own HP and take damage **after player Block is depleted** but **before player HP** is hit.
      - Summons can have:
        - On-summon effects (immediate trigger).
        - While-alive field effects (e.g., "While this summon is alive, your Block does not reset at the start of your turn", "Enemies deal -X damage", "Gain +1 Mana at start of turn").
        - On-death effects (trigger when killed).
      - Summons usually Exhaust or auto-remove at end of combat.
  - **Special / Waifu-Synergy Triggers**:
    - On Play / On Exhaust / On Discard triggers (e.g., "Whenever you Exhaust a card, gain 3 Block").
    - Archetype bonuses (e.g., "Bleed cards gain +1 if a bonded waifu is active").
    - Curse / Backlash: Powerful effects that add negative cards to deck or reduce max HP.
- Enemy intents visible (damage preview, buffs, etc.).
- Win condition: Reduce all enemies to 0 HP.
- Player HP: Persistent max HP (increases via story/gifts); current HP carries between battles in a mission unless rested/healed.
- **Death**: Mission fail → retry mission or story consequences (waifu bond loss, etc.).

## 4. Mission Structure
Missions = dedicated "dungeons" or boss arcs (e.g., "Hunt the Boar" = boar boss + minions/environment).
Four styles by length/difficulty:
- **Short**: 3 battles, no rests. Quick, burst-focused. Ideal for testing decks/waifus.
- **Medium**: 6 battles, 1 rest. Balanced pacing.
- **Long**: 9 battles, 2 rests. Endurance test.
- **Epic**: 12 battles, 2 rests. Saga-level, high stakes/rewards.
- **Rest Sites**: Between battles—options like:
  - Heal HP: Base recovery of 25% of max HP (can be buffed by outside sources such as waifus, gifts, or modifiers).
  - Remove curse card.
  - Minor upgrade/draw cards.
- **Mission-Specific Effects/Modifiers**:
  - Environmental (e.g., "Cursed Forest: All cards cost +1 if not shadow-typed").
  - Waifu-tied (e.g., with bonded waifu: Bleed deals extra, but rests empower enemies).
  - Scaling (longer missions = tougher enemy buffs per battle).
  - **Note**: *Each mission has 1-3 modifiers chosen based on story/waifu/region. Effects encourage deck swaps.*

## 5. Waifu System (Passive & Synergy Layer)
- 5 recruitable waifus, each with unique archetype/effect (as previously defined).
- **Bond Level**: Increases via rests, gifts, choices—scales effect strength (low = neutral/weak; high = powerful + risks).
- **Mission Waifu Selection**:
  - Before starting a mission, the player selects **one Main Waifu** whose full passive/synergy effects are active throughout the mission.
  - The player also selects **up to 2 Backup Waifus**.
  - Backup Waifus provide **weaker/secondary synergy effects** (exact mechanics TBD), adding another layer of strategic depth and encouraging consideration of waifu combinations.
  - Main Waifu determines the primary thematic/strength direction of the run; Backups offer complementary bonuses or situational triggers.
  - (Potential future: rivalries, exclusions, or bond penalties for certain combinations to be decided later.)
- **Activation**: Waifus provide global passives/gift-like effects during missions they're selected for (Main + Backups).
- **Dark Fantasy Twist**: Low bond = drawbacks (curse cards, mana penalties, betrayal events).
- **Synergies**: Certain cards trigger extra effects if the Main Waifu (or potentially Backups) is bonded/high bond (e.g., bleed cards with bonded waifu = lifesteal; summon cards gain bonus HP or effects with certain waifus).
- **Note**: *Decide exact strength difference between Main and Backup effects, and whether Backups can trigger at reduced potency or only under specific conditions.*

## 6. Progression & Economy
- **Rewards**: Cards (to library), gifts (permanent passives), **card packs** (multiple colors/tiers – higher-tier colors increase the chance of rare cards), waifu gifts, story unlocks, **Waifu Skin Currency** (from duplicate cards beyond 4 copies).
- **Hub Town/Camp**: Deck editing, shop, upgrades, waifu interactions (including skin equipping), mission board.
- **Gifts**: Permanent bonuses (e.g., +1 mana, artifact draw, archetype boosts, summon HP bonuses). Obtained from completing missions via NPCs or found in treasure.
- **Archetypes/Keywords**: Encourage specialization (bleed, fire, summon, control, etc.) with cross-synergies via waifus.
- **Waifu Skins**: Cosmetic customization for waifus unlocked/purchased with Skin Currency (costs and exact currency values per rarity TBD).

## 7. Balance & Philosophy Notes
- Emphasize tight, satisfying combat decisions over RNG.
- Persistent library = long-term identity; deck caps + 4-copy limit force curation.
- Mission variety + modifiers + waifu selection (Main + Backups) + summon management = reason to maintain multiple decks and strategies.
- Dark tone: Risk/reward in everything—powerful cards/waifus/summons often have curses/backlash.
- **Expansion Points**:
  - *Full card type/keyword list refinements.*
  - *Mana & scaling details.*
  - *Enemy design principles.*
  - *NG+ or multiple playthroughs?*
  - *Exact Backup Waifu synergy mechanics and potency.*
  - *Waifu skin costs and currency economy tuning.*
  - *Summon balance: HP values, typical durations, archetype fit.*
  - *Card pack tier/color probabilities and contents.*
  