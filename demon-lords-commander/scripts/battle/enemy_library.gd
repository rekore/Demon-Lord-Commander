class_name EnemyLibrary
extends RefCounted

# EnemyLibrary manages enemy definitions and intent pattern resolution.
# This separates enemy data from intent execution logic.

# Intent pattern templates that enemies can reference
var intent_patterns: Dictionary = {
	"heavy_attack": {
		"type": "attack",
		"params": {"damage": 8},
		"display_name": "Heavy Swing"
	},
	"light_attack": {
		"type": "attack",
		"params": {"damage": 5},
		"display_name": "Light Attack"
	},
	"double_attack": {
		"type": "attack",
		"params": {"damage": 6},
		"display_name": "Double Slash"
	},
	"guard_up": {
		"type": "block",
		"params": {"block": 6},
		"display_name": "Guard Up"
	},
	"fortify": {
		"type": "block",
		"params": {"block": 10},
		"display_name": "Fortify"
	},
	"weak_attack": {
		"type": "attack",
		"params": {"damage": 3},
		"display_name": "Weak Strike"
	},
	"cripple": {
		"type": "debuff",
		"params": {"debuff_type": "frail", "stacks": 2, "target": "player"},
		"display_name": "Cripple"
	}
}


func resolve_intent_pattern(pattern_id: String) -> Dictionary:
	var pattern: Dictionary = intent_patterns.get(pattern_id, {})
	if pattern.is_empty():
		push_warning("EnemyLibrary: Unknown intent pattern '%s'" % pattern_id)
		return {}
	return pattern.duplicate(true)


func get_pattern_display_name(pattern_id: String) -> String:
	var pattern: Dictionary = intent_patterns.get(pattern_id, {})
	return String(pattern.get("display_name", "Unknown Pattern"))


func is_valid_pattern(pattern_id: String) -> bool:
	return intent_patterns.has(pattern_id)


# Convert old-style inline intent to new pattern format (for migration)
func convert_legacy_intent(legacy_intent: Dictionary) -> Dictionary:
	var damage: int = int(legacy_intent.get("damage", 0))
	var block: int = int(legacy_intent.get("block", 0))
	var name: String = String(legacy_intent.get("name", "Unknown"))
	
	if damage > 0 and block > 0:
		# Hybrid intent - create custom pattern
		return {
			"type": "custom",
			"params": {"damage": damage, "block": block},
			"display_name": name
		}
	elif damage > 0:
		return {
			"type": "attack",
			"params": {"damage": damage},
			"display_name": name
		}
	elif block > 0:
		return {
			"type": "block",
			"params": {"block": block},
			"display_name": name
		}
	else:
		return {
			"type": "none",
			"params": {},
			"display_name": name
		}
