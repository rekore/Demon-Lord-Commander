Rules Bible: [Game Name TBD] - Core Card Game Mechanics (v1.8)
1. Overview & Data Integrity

    Genre: Single-player turn-based deckbuilding RPG.

    Persistence: Final battle HP is written to GameState.player.current_hp immediately upon battle end.

    Math: All values use Floor logic (round down) calculated at the end of the operation.

2. Deck & Hand Management

    Size: 20 min / 100 max. Max 4 copies (1 for Mythics).

    Cycling: Discard shuffles into Draw only when a draw is attempted and Draw is empty.

    Max Hand: 10 cards.

    Draw Accounting: A draw attempt is considered "spent" even if the card is sent to Discard due to a full hand. This ensures "On Draw" triggers remain consistent.

    Fatigue (The Void): If starting a turn with 0 cards in Hand/Draw/Discard, take escalating damage (2, 4, 6...) upon ending the turn.

3. Combat Lifecycle
Phase 1: Round Start (Pre-Turn)

    Status Tick (In): Resolve Bleed, Poison, and Regen. Death here ends combat.

    Intent Reveal: Enemy action displayed. (Intent is selected based on the current index).

    Reset: Mana set to Base; Block set to 0.

    Draw: Player draws 5.

Phase 2: Player Action Loop

    Legality: Must pay full Mana + Blood Price. Cannot play if Blood Price ≥ Current HP.

    Echo: Deducts costs once, but resolves card effects twice.

    Targeting: Single-target cards require explicit selection. AOE ignores selection.

    Damage Rule: Player attacks do not pierce. Excess damage is lost.

Phase 3: Enemy Turn

    Resolution: Enemy performs Intent.

    Intent Advancement: At the end of the Enemy Turn, the intent index advances by 1 (wrapping to 0 at the end of the array).

    Stun: Enemy skips current Intent and advances index immediately.

    Retaliate: Triggers only if damage penetrates Block and hits Summon/Player HP.

    Status Tick (Out): Resolve Burn.

4. Damage, Summons, & Protection

Board Slots: [Player] [Summon 1] [Summon 2] [Summon 3]

    Priority: Block → Summons (Right to Left) → Player HP.

    Enemy Pierce: Enemy damage carries over to the next unit on the left.

    Summon Reindex: If a Summon dies, board slots reindex immediately before carryover damage is applied to the next target.

    Taunt Priority: Most recently summoned unit with Taunt takes the right-most "hit-first" position.

    Vulnerability: +50% damage burden applied to the current active target.

5. Technical Logic & Edge Cases
A. Death Check Granularity

Death checks occur immediately after each damage instance. This includes:

    Each hit of a multi-hit attack.

    Each individual target resolution in an AOE.

    Each resolution of an Echoed card.
    Units at HP ≤ 0 are removed from the board before any subsequent damage resolves.

B. Healing & Status Bounds

    Healing Bounds: All healing/Regen is capped at Max HP. current_hp = min(current_hp + heal_val, max_hp).

    Status Floor: Decrementing statuses (Poison, Regen) cannot go below 0.

C. Retaliate Safety Rule

Retaliate cannot trigger another Retaliate. Retaliate damage is flagged as "Reaction Damage" to prevent infinite recursive loops.
6. Expanded Glossary

    Bleed: Damage at Round Start. Persistent.

    Poison: Damage at Round Start. Decrements by 1.

    Burn: Damage at End of Enemy Turn. Persistent.

    Rage: Next attack card +50% damage.

    Search: Target a specific card type in the Draw Pile.

    Ethereal: Exhausts automatically at turn end.

    Chain: Resolves targets in the specific priority order defined on the card text.

    Strength: adds X damage to every instance of an attacks damage

    Weakness: deal 25% less damage

    Frail: take 25% more damage from incoming attacks

    Draw: Draws X cards



