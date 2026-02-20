# Relationship System for Demon Lord's Beloved Commander

## Overview
- Hybrid: Multi-axis meters per waifu, driven solely by player choices/dialogue (no decay or time pressure).
- Focus: Make waifus multi-dimensional and alive—swings on favoritism, corruption, factions create harem rivalries/consequences.
- Implementation: Godot autoload script (RelationshipManager.gd) with dict var_waifu_axes.
- Swings: +5-15 positives on good choices; -5-15 negatives on bad/favoritism. Thresholds unlock flags/branches (e.g., intimacy >70 = adult scene).
- MC Tie-In: var_corruption >50 doubles negative swings (dark fantasy amp).
- Cross-Waifu: Favor one? Auto +jealousy for others.

## Per-Waifu Axes
| Waifu | Axis 1: Trust (Universal) | Axis 2: Intimacy (Universal) | Axis 3: Unique Negative/Tension | Axis 4: Unique Positive/Evolution | Swing Examples |
|-------|---------------------------|------------------------------|---------------------------------|-----------------------------------|---------------|
| Clara | Faith in MC (high = tomboy reveals). | Vulnerability/romance (high = private desires). | Doubt/Fear: + on corruption hints or church conflicts. | Devotion: + on purity-support choices. | Favor Lyra? +5 doubt (guild friction). Aid church? +10 devotion, +5 trust. |
| Lyra | Reliability (high = empathy shares). | Affection (high = tsundere to dere). | Jealousy/Guilt: + on harem favoritism or theft reveals. | Curiosity/Loyalty: + on quest shares. | Flirt with Chesy? +10 jealousy. Guild help? +15 loyalty. |
| Nyxelle | "Master" bond (high = magic aids). | Tenderness (high = whimsy to intimate). | Possessiveness/Fear: + on MC independence or corruption spikes. | Wonder/Creativity: + on playful choices. | Ignore in group? +8 possessiveness. Magic collab? +12 wonder. |
| Chesy | Respect/Honor (high = warrior alliance). | Bonded closeness (high = feral ecchi). | Rage/Impulsiveness: + on tribe slights or favoritism. | Honor/Growth: + on honorable acts. | Save rival clan? +10 honor. Favor Clara? +7 rage (beastkin discrimination). |
| Miri | Reclaimed bond (high = devoted sweet). | Obsessive intimacy (high = yandere H). | Jealousy/Obsession: + on any other waifu favor. | Nostalgia/Healing: + on trauma-sharing. | Talk to Nyxelle? +15 jealousy. Reminisce? +10 nostalgia, -5 obsession. |

## Example Godot Script Snippet
```gdscript
# RelationshipManager.gd (Autoload)
var waifu_axes = {
    "clara": {"trust": 0, "intimacy": 0, "doubt": 0, "devotion": 0},
    # Add others...
}

func apply_swing(waifu, axis, value):
    waifu_axes[waifu][axis] += value
    if Global.var_corruption > 50 and value < 0:  # Amplify negatives
        waifu_axes[waifu][axis] += value  # Double
    check_thresholds(waifu)  # e.g., if intimacy >70, set flag_intimate_true

Example .dtl Usage
act1_harem_gathering
~ [Favor Lyra] -> lyra_favor [add_variable("var_waifu_axes["lyra"]["curiosity"]", 10)] [add_variable("var_waifu_axes["miri"]["jealousy"]", 8)]
Notes

Balance: Axes range 0-100 (or -50 to 50); test for swing values.
Updates: Refine axes as we write scenes (e.g., add "fear" if needed).

