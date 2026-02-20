# Variable Tracker for Demon Lord's Beloved Commander

## Flags (Bool) - Event-Based

## Counters (Int) - Progressive
- var_corruption: 0 (MC-only demon influence; 0-100; amplifies negative swings)

## States (Dict) - Waifu/Faction Evolutions
- var_waifu_status: {} (Axis-derived states, e.g., {"clara": "serene"})

## Emotional Axes (Dict) - Choice-Driven Meters
- var_waifu_axes: {} (Per-waifu meters, e.g., {"clara": {"trust": 0, "intimacy": 0, "doubt": 0, "devotion": 0}})
  - Swings occur on direct choices/favoritism (no decay); e.g., +5-15 positives, -5-15 negatives.
  - Thresholds unlock flags/states (e.g., intimacy >70 = adult branch).
  - MC corruption >50 doubles negative swings.

## Notes
- Update this file as we add new vars (e.g., via scene proposals).
- All vars are Godot/Dialogic compatible; use [set_variable] or [add_variable] in .dtl.