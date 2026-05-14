class_name CardUI
extends Control

# Card size presets. All maintain the base 784x1168 aspect ratio.
enum CardSize {
	HAND,    # ~35% viewport height (~378px at 1080p) — cards in player hand
	PREVIEW, # ~350px tall — hover / selection preview
	FULL     # ~400px tall — card library / rewards (max at 1920x1080)
}

const BASE_WIDTH: float = 784.0
const BASE_HEIGHT: float = 1168.0
const MAX_HEIGHT_AT_1080P: float = 400.0

# Scale factors derived from max height constraint
const SCALE_HAND: float = 0.324
const SCALE_PREVIEW: float = 0.30
const SCALE_FULL: float = MAX_HEIGHT_AT_1080P / BASE_HEIGHT  # ≈ 0.342

const DEFAULT_ART_PATH: String = "res://assets/art/cards/Nyxcardsizetemplate.png"
const DEFAULT_BORDER_PATH: String = "res://assets/art/cards/cardbaseorange.png"

@export var CardBorder: TextureRect
@export var CardArt: TextureRect
@export var CardName: Label
@export var ManaCost: Label
@export var EffectText: Label

var _card_data: Dictionary = {}


func setup(card_data: Dictionary, size_preset: CardSize = CardSize.HAND) -> void:
	_card_data = card_data

	# Apply size based on preset (scales internal elements via anchors + font overrides)
	var scale_factor: float = _get_scale_for_preset(size_preset)
	var scaled_width: float = BASE_WIDTH * scale_factor
	var scaled_height: float = BASE_HEIGHT * scale_factor
	size = Vector2(scaled_width, scaled_height)

	# Scale fonts proportionally (use larger bases so text stays readable)
	var font_scale: float = scale_factor
	CardName.add_theme_font_size_override("font_size", int(64 * font_scale))
	ManaCost.add_theme_font_size_override("font_size", int(72 * font_scale))
	EffectText.add_theme_font_size_override("font_size", int(64 * font_scale))

	# Set border texture (with fallback)
	var border_path: String = card_data.get("border_path", DEFAULT_BORDER_PATH)
	CardBorder.texture = _safe_load_texture(border_path, DEFAULT_BORDER_PATH)

	# Set art texture (with fallback)
	var art_path: String = card_data.get("art_path", DEFAULT_ART_PATH)
	CardArt.texture = _safe_load_texture(art_path, DEFAULT_ART_PATH)

	# Set text fields
	CardName.text = card_data.get("name", "Unknown")
	ManaCost.text = str(card_data.get("cost", 0))
	EffectText.text = _format_effects(card_data.get("effects", []))


func set_unplayable_tint(enabled: bool) -> void:
	if enabled:
		modulate = Color(1, 1, 1, 0.4)
	else:
		modulate = Color.WHITE


func get_card_id() -> String:
	return String(_card_data.get("id", ""))


func get_card_data() -> Dictionary:
	return _card_data


func _get_scale_for_preset(preset: CardSize) -> float:
	match preset:
		CardSize.HAND:
			return SCALE_HAND
		CardSize.PREVIEW:
			return SCALE_PREVIEW
		CardSize.FULL:
			return SCALE_FULL
		_:
			return SCALE_HAND


func _safe_load_texture(path: String, fallback: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	# Fallback
	if ResourceLoader.exists(fallback):
		return load(fallback) as Texture2D
	return null


func _format_effects(effects: Array) -> String:
	if effects.is_empty():
		return ""

	var lines: PackedStringArray = PackedStringArray()
	for raw_effect: Variant in effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect as Dictionary
		var effect_type: String = String(effect.get("type", ""))
		var line: String = _format_single_effect(effect_type, effect)
		if line != "":
			lines.append(line)

	return "\n".join(lines)


func _format_single_effect(effect_type: String, effect: Dictionary) -> String:
	match effect_type:
		"DealDamage":
			var value: int = int(effect.get("value", 0))
			var target: String = String(effect.get("target", "SingleEnemy"))
			var target_str: String = _format_target(target)
			return "Deal %d damage to %s." % [value, target_str]
		"GainBlock":
			var value: int = int(effect.get("value", 0))
			return "Gain %d Block." % value
		"DrawCards":
			var value: int = int(effect.get("value", 0))
			return "Draw %d cards." % value
		"GainMana":
			var value: int = int(effect.get("value", 0))
			return "Gain %d Mana." % value
		"LoseHP":
			var value: int = int(effect.get("value", 0))
			return "Lose %d HP." % value
		"Lifesteal":
			var percentage: int = int(effect.get("percentage", 0))
			return "Lifesteal %d%%." % percentage
		"ApplyDebuff":
			var debuff: String = String(effect.get("debuff", ""))
			var stacks: int = int(effect.get("stacks", 0))
			var target: String = String(effect.get("target", "SingleEnemy"))
			var target_str: String = _format_target(target)
			if stacks > 0:
				return "Apply %d %s to %s." % [stacks, debuff, target_str]
			else:
				var duration: int = int(effect.get("duration", 0))
				return "Apply %s (%d turns) to %s." % [debuff, duration, target_str]
		"Summon":
			var summon_name: String = String(effect.get("summonName", ""))
			var summon_hp: int = int(effect.get("summonHP", 0))
			return "Summon %s (%d HP)." % [summon_name, summon_hp]
		"SacrificeAllSummons":
			return "Sacrifice all summons."
		"ExhaustRandomCard":
			var count: int = int(effect.get("count", 1))
			return "Exhaust %d random card(s) from hand." % count
		"Exhaust":
			return "Exhaust this card."
		"CopyCard":
			var count: int = int(effect.get("count", 1))
			return "Copy %d card(s) from hand." % count
		"AddCurseToDeck":
			var count: int = int(effect.get("count", 1))
			return "Add %d curse(s) to deck." % count
		"PermanentBuff":
			var buff: String = String(effect.get("buff", ""))
			var value: int = int(effect.get("value", 0))
			return "Permanent %s +%d." % [buff, value]
		"ExtraTurn":
			return "Take an extra turn."
		_:
			return "[%s]" % effect_type


func _format_target(target: String) -> String:
	match target:
		"SingleEnemy":
			return "an enemy"
		"AllEnemies":
			return "all enemies"
		"Player":
			return "self"
		"SameAsPrevious":
			return "same target"
		"PlayerHand":
			return "hand"
		"ThisCard":
			return "this card"
		_:
			return target
