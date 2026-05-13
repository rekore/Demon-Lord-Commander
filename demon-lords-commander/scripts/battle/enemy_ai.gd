extends RefCounted

# EnemyAI owns which intent is active and how the enemy turn is resolved.
# This keeps intent sequencing out of the main scene controller script.
# Now uses IntentLibrary and EnemyLibrary for separation of concerns.

var intent_library: IntentLibrary
var enemy_library: EnemyLibrary


func _init():
	intent_library = IntentLibrary.new()
	enemy_library = EnemyLibrary.new()


func get_current_intent(enemy_state: Dictionary, intent_index: int) -> Dictionary:
	var intents: Array = enemy_state.get("intents", [])
	if intents.is_empty():
		return {}
	
	var intent_data: Dictionary = intents[intent_index]
	
	# Check if intent uses pattern reference (new format) or inline data (legacy format)
	if intent_data.has("pattern_id"):
		var pattern_id: String = String(intent_data.get("pattern_id", ""))
		return enemy_library.resolve_intent_pattern(pattern_id)
	else:
		# Legacy format - convert inline intent to new format
		return enemy_library.convert_legacy_intent(intent_data)


func run_enemy_turn(
	enemy_state: Dictionary,
	intent_index: int,
	player_state: Dictionary,
	effect_resolver: RefCounted
) -> Dictionary:
	var current_intent: Dictionary = get_current_intent(enemy_state, intent_index)
	if current_intent.is_empty():
		return {
			"had_intent": false,
			"next_intent_index": intent_index,
			"intent_name": "None"
		}

	var intent_type: String = String(current_intent.get("type", "none"))
	var intent_params: Dictionary = current_intent.get("params", {})
	var intent_display_name: String = String(current_intent.get("display_name", "Unknown Intent"))
	
	# Execute intent using the intent library
	var execution_result: Dictionary = intent_library.execute_intent(
		intent_type,
		enemy_state,
		player_state,
		effect_resolver,
		intent_params
	)

	return {
		"had_intent": true,
		"next_intent_index": _next_intent_index(enemy_state, intent_index),
		"intent_name": intent_display_name,
		"execution_result": execution_result
	}


func _next_intent_index(enemy_state: Dictionary, intent_index: int) -> int:
	var intents: Array = enemy_state.get("intents", [])
	if intents.is_empty():
		return intent_index
	return (intent_index + 1) % intents.size()
