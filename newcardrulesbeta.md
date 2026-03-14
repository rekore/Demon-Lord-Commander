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
  - Add cards via rewards (common after short/medium, rarer/epic bosses), including **Card Packs** (see Progression & Economy).
  - Removal/Upgrades: Available in hub (smithy, shrine, etc.)—costs gold, favors, or waifu-specific resources.
  - **Duplicate Handling (Post-Collection)**: Once the player has collected **4 copies** of any card in their Library, any additional copies of that card received as rewards are automatically converted into **Waifu Skin Currency** instead of being added to the Library:
    - Common card duplicate → 1 Skin Currency
    - Mythic card duplicate → 20 Skin Currency
    - (Rarities in between and exact skin costs to be determined later)
  - **Note**: *Add systems to prevent extreme bloat (e.g., "retire for gift" mechanic, archetype-locked upgrades).*

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
- **Core Card Effects & Keywords** (comprehensive expandable foundation – designed to support hundreds of unique card designs):
  - Most cards combine **1–3 effects** from different categories below + archetype flavor (bleed, fire, summon, shadow, etc.).
  - **Mana Generation & Manipulation** (mana-gain cards):
    - Gain +X Mana this turn (or next turn).
    - Permanent +1 Mana for the combat.
    - Mana Ramp (gain +1 Mana each turn, stacking).
    - Refund Mana on conditions (e.g., “If this kills an enemy, refund 2 Mana”).
    - Mana Drain (steal mana from enemy intents or convert enemy buffs into your mana).
    - Conditional mana burst (e.g., “Gain 3 Mana if you have a summon alive”).
  - **Sacrifice & Self-Harm Effects** (dark fantasy “blood pact” cards – hurt yourself for huge enemy debuffs/power):
    - Pay HP to apply strong debuffs (e.g., “Lose 8 HP: Apply 4 Vulnerable and 3 Weak to all enemies”).
    - Self-damage for massive damage spikes or status (e.g., “Lose 10 HP: Deal 25 damage to all enemies”).
    - Sacrifice cards from hand/discard to trigger effects.
    - Convert HP into Mana, Block, or extra draws (“Lose 5 HP: Gain 2 Mana and draw 2 cards”).
    - Blood Magic triggers (“Whenever you lose HP this turn, apply +1 Bleed to all enemies”).
  - **Buffs (Player-scaling positives)**:
    - Strength, Dexterity, Vigor, Focus, archetype scalers.
    - Temporary or permanent stacking buffs.
  - **Debuffs & Status Effects**:
    - Vulnerable, Weak, Frail.
    - Poison, Bleed, Corruption, Decay, Curse stacks.
    - Stun, Freeze, Taunt, Mark (sets up follow-up damage).
    - Haunted / Possessed (negative triggers on enemy).
  - **Card Flow & Manipulation**:
    - Draw +X, Discard X, Exhaust, Retain, Copy, Scry X.
    - Mill (force discard on self or enemy effects).
    - Recycle from Exhaust or Discard pile.
  - **Turn & Action Economy**:
    - Extra Turn (rare, high-risk).
    - Extra card plays per turn.
    - Skip enemy turn (very rare).
  - **Persistent / Power Effects & Summons**:
    - Power cards grant ongoing effects (e.g., “At start of turn: draw 1, gain 1 Strength”).
    - **Summons / Minions** (max 3 active):
      - On-summon, While-alive field effects, On-death effects.
      - Can be sacrificed for big payoffs.
  - **Healing & Life Manipulation**:
    - Direct healing.
    - Lifesteal (damage = heal).
    - Max HP increases (temporary or permanent).
    - Damage transfer (player → summon or enemy).
  - **Reaction & Trigger Effects**:
    - On Play / On Exhaust / On Discard / On Summon / When taking damage / When enemy attacks.
  - **Multi-Target, Area & Special**:
    - Hit all enemies.
    - Chain / random target effects.
    - Transform card types temporarily.
    - Generate curses or negative cards.
- **Design Note**: Powerful effects (extra turn, big self-damage, massive mana ramps) must carry meaningful risk or cost to preserve the dark fantasy tone and tight decision-making. Effects scale with waifus, summons, and mission modifiers for extra depth.
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
  - Heal HP (base 25% of max HP; can be increased via gifts, cards, waifu effects, or other sources).
  - Remove curse card.
  - Minor upgrade/draw cards.
- **Mission-Specific Effects/Modifiers**:
  - Environmental (e.g., "Cursed Forest: All cards cost +1 if not shadow-typed").
  - Waifu-tied (e.g., with selected waifu: Certain archetype deals extra, but rests empower enemies).
  - Scaling (longer missions = tougher enemy buffs per battle).
  - **Note**: *Each mission has 1-3 modifiers chosen based on story/waifu/region. Effects encourage deck swaps.*

## 5. Waifu System (Passive & Synergy Layer)
- 5 recruitable waifus, each with unique archetype/effect.
- **Bond Level**: Increases via rests, gifts, choices—scales effect strength (low = neutral/weak; high = powerful + risks).
- **Mission Waifu Selection**:
  - Before starting a mission, the player selects **one Main Waifu** whose full passive/synergy effects are active throughout the mission.
  - The player also selects **up to 2 Backup Waifus**.
  - Backup Waifus provide **weaker/secondary synergy effects** (exact mechanics TBD), adding another layer of strategic depth and encouraging consideration of waifu combinations.
  - Main Waifu determines the primary thematic/strength direction of the run; Backups offer complementary bonuses or situational triggers.
  - (Potential future: rivalries, exclusions, or bond penalties for certain combinations to be decided later.)
- **Activation**: Waifus provide global passives/relic-like effects during missions they're selected for (Main + Backups).
- **Dark Fantasy Twist**: Low bond = drawbacks (curse cards, mana penalties, betrayal events).
- **Synergies**: Certain cards trigger extra effects if the Main Waifu (or potentially Backups) is bonded/high bond (e.g., archetype cards gain bonuses; summon cards gain bonus HP or effects with certain waifus).
- **Note**: *Decide exact strength difference between Main and Backup effects, and whether Backups can trigger at reduced potency or only under specific conditions.*

## 6. Progression & Economy
- **Rewards**: Cards (to library), **Gifts** (permanent passives, gained from mission completions, NPC quests, treasure finds, events), gold, waifu gifts, story unlocks, **Waifu Skin Currency** (from duplicate cards beyond 4 copies), **Card Packs**.
- **Card Packs**:
  - Mission rewards can include packs of various color/tier levels.
  - Higher color scale = increased chance of rare, epic, mythic, or special cards.
  - Opening packs adds cards directly to the Library (with duplicate conversion rules applying).
- **Hub Town/Camp**: Deck editing, shop, upgrades, waifu interactions (including skin equipping), mission board.
- **Gifts**: Permanent passive bonuses (e.g., +1 mana, improved draw, archetype boosts, summon HP bonuses) replacing previous relic system.
- **Archetypes/Keywords**: Encourage specialization (bleed, fire, summon, control, etc.) with cross-synergies via waifus.
- **Waifu Skins**: Cosmetic customization for waifus unlocked/purchased with Skin Currency (costs and exact currency values per rarity TBD).

## 7. Balance & Philosophy Notes
- Emphasize tight, satisfying combat decisions over RNG.
- Persistent library = long-term identity; deck caps + 4-copy limit force curation.
- Mission variety + modifiers + waifu selection (Main + Backups) + summon management = reason to maintain multiple decks and strategies.
- Dark tone: Risk/reward in everything—powerful cards/waifus/summons often have curses/backlash.
- Who doesn’t love opening card packs? — Use pack excitement to reward progression while keeping core deck identity through curation.
- **Expansion Points**:
  - *Full card type/keyword list refinements.*
  - *Mana & scaling details.*
  - *Enemy design principles.*
  - *NG+ or multiple playthroughs?*
  - *Exact Backup Waifu synergy mechanics and potency.*
  - *Waifu skin costs and currency economy tuning.*
  - *Summon balance: HP values, typical durations, archetype fit.*
  - *Pack tier/color details, drop rates, and rarity probabilities.*