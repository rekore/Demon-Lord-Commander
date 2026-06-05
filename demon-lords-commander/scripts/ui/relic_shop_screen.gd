extends Control

const MAIN_THEME_PATH: String = "res://assets/art/ui/MainTheme.tres"

var _main_theme: Theme = null

@onready var _relics_container: HBoxContainer = %RelicsContainer
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_cost_label: Label = %rerolllabelcost
@onready var _close_button: Button = %CloseButton
@onready var _gold_label: Label = %GoldLabel
@onready var _shopkeeper_portrait: TextureRect = %ShopkeeperPortrait
@onready var _shopkeeper_name_label: Label = %RelicShopkeeperLabel

const RARITY_COLORS: Dictionary = {
	"common": Color(0.8, 0.8, 0.8),
	"uncommon": Color(0.4, 0.9, 0.4),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.75, 0.1)
}


func _ready() -> void:
	if FileAccess.file_exists(MAIN_THEME_PATH):
		_main_theme = load(MAIN_THEME_PATH)
	_close_button.pressed.connect(_on_close_pressed)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	if SaveManager.profile.get("shop_inventory", []).is_empty():
		RelicShopService.refresh_shop()
	_populate_shop()


func _populate_shop() -> void:
	for child: Node in _relics_container.get_children():
		child.queue_free()

	var inventory: Array = RelicShopService.get_shop_inventory()
	for relic: Variant in inventory:
		if not (relic is Dictionary):
			continue
		_relics_container.add_child(_build_relic_card(relic as Dictionary))

	_refresh_labels()


func _build_relic_card(relic: Dictionary) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _main_theme:
		card.theme = _main_theme

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(0, 180)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var art_path: String = String(relic.get("art_path", ""))
	if art_path != "" and FileAccess.file_exists(art_path):
		icon_rect.texture = load(art_path)
	vbox.add_child(icon_rect)

	var name_label: Label = Label.new()
	name_label.text = String(relic.get("name", "???"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 29)
	vbox.add_child(name_label)

	var rarity: String = String(relic.get("rarity", "common")).to_lower()
	var rarity_label: Label = Label.new()
	rarity_label.text = rarity.capitalize()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 25)
	rarity_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	vbox.add_child(rarity_label)

	var dur_label: Label = Label.new()
	dur_label.text = "Lasts %d mission(s)" % int(relic.get("duration", 1))
	dur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dur_label.add_theme_font_size_override("font_size", 25)
	vbox.add_child(dur_label)

	var desc_label: Label = Label.new()
	desc_label.text = String(relic.get("description", ""))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 25)
	vbox.add_child(desc_label)

	var cost_label: Label = Label.new()
	var cost: int = int(relic.get("cost", 0))
	cost_label.text = "%d Gold" % cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 27)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(cost_label)

	var buy_btn: Button = Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(140, 44)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_btn.add_theme_font_size_override("font_size", 23)
	var relic_id: String = String(relic.get("id", ""))
	buy_btn.pressed.connect(_on_buy_pressed.bind(relic_id, card, buy_btn))
	vbox.add_child(buy_btn)

	return card


func _on_buy_pressed(relic_id: String, card: Control, buy_btn: Button) -> void:
	if RelicShopService.buy_relic(relic_id):
		card.modulate = Color(0.45, 0.45, 0.45, 0.75)
		buy_btn.disabled = true
		buy_btn.text = "Owned"
		_refresh_labels()


func _on_reroll_pressed() -> void:
	var success: bool = RelicShopService.reroll_shop()
	if success:
		_populate_shop()


func _refresh_labels() -> void:
	_gold_label.text = "Gold: %d" % int(SaveManager.profile.get("gold", 0))
	var reroll_cost: int = RelicShopService.get_reroll_cost()
	_reroll_cost_label.text = "(%d Gold)" % reroll_cost
	var gold: int = int(SaveManager.profile.get("gold", 0))
	_reroll_button.disabled = gold < reroll_cost


func _on_close_pressed() -> void:
	queue_free()
