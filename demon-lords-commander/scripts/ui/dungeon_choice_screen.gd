extends Control

const MAIN_THEME_PATH: String = "res://assets/art/ui/MainTheme.tres"

const TYPE_DISPLAY: Dictionary = {
	"battle_normal": {"label": "COMBAT", "color": Color(0.9, 0.35, 0.25)},
	"battle_elite":  {"label": "ELITE",  "color": Color(0.75, 0.2, 0.85)},
	"battle_boss":   {"label": "BOSS",   "color": Color(1.0,  0.15, 0.15)},
	"event":         {"label": "EVENT",  "color": Color(0.3,  0.75, 0.95)},
	"rest":          {"label": "REST",   "color": Color(0.3,  0.75, 0.5)},
	"bond":          {"label": "BOND",   "color": Color(0.95, 0.4,  0.65)}
}

var _main_theme: Theme = null
var _choices: Array = []


func _ready() -> void:
	if FileAccess.file_exists(MAIN_THEME_PATH):
		_main_theme = load(MAIN_THEME_PATH)
	_build_static_ui()


func set_choices(choices: Array) -> void:
	_choices = choices
	_populate_cards()


# ---------------------------------------------------------------------------
# Static shell
# ---------------------------------------------------------------------------

func _build_static_ui() -> void:
	if _main_theme != null:
		theme = _main_theme

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_top", 60)
	outer_margin.add_theme_constant_override("margin_bottom", 60)
	outer_margin.add_theme_constant_override("margin_left", 80)
	outer_margin.add_theme_constant_override("margin_right", 80)
	add_child(outer_margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 20)
	outer_margin.add_child(root_vbox)

	var title_label: Label = Label.new()
	title_label.text = "Choose Your Path"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	root_vbox.add_child(title_label)

	var sep: HSeparator = HSeparator.new()
	root_vbox.add_child(sep)

	var top_spacer: Control = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 10)
	root_vbox.add_child(top_spacer)

	var cards_hbox: HBoxContainer = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 40)
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.name = "CardsHBox"
	root_vbox.add_child(cards_hbox)

	var bottom_spacer: Control = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 10)
	root_vbox.add_child(bottom_spacer)


# ---------------------------------------------------------------------------
# Dynamic card population
# ---------------------------------------------------------------------------

func _populate_cards() -> void:
	var cards_hbox: HBoxContainer = get_node_or_null("CardsHBox")
	if cards_hbox == null:
		await get_tree().process_frame
		cards_hbox = _find_cards_hbox()
	if cards_hbox == null:
		push_warning("DungeonChoiceScreen: Could not find CardsHBox.")
		return

	for child: Node in cards_hbox.get_children():
		child.queue_free()

	for node_data: Variant in _choices:
		if node_data is Dictionary:
			var card: Control = _build_choice_card(node_data as Dictionary)
			cards_hbox.add_child(card)


func _find_cards_hbox() -> HBoxContainer:
	for child: Node in get_children():
		var result: HBoxContainer = _search_for_hbox(child)
		if result != null:
			return result
	return null


func _search_for_hbox(node: Node) -> HBoxContainer:
	if node is HBoxContainer and node.name == "CardsHBox":
		return node as HBoxContainer
	for child: Node in node.get_children():
		var result: HBoxContainer = _search_for_hbox(child)
		if result != null:
			return result
	return null


func _build_choice_card(node_data: Dictionary) -> Control:
	var node_type: String = String(node_data.get("type", "battle_normal"))
	var floor_num: int = int(node_data.get("floor", 1))
	var label_text: String = String(node_data.get("label", "Unknown Path"))
	var is_boss: bool = bool(node_data.get("is_boss", false))
	var type_info: Dictionary = TYPE_DISPLAY.get(node_type, {"label": "UNKNOWN", "color": Color.WHITE})
	var type_label_text: String = String(type_info.get("label", "UNKNOWN"))
	var type_color: Color = type_info.get("color", Color.WHITE) as Color

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 360)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var inner_margin: MarginContainer = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_top", 24)
	inner_margin.add_theme_constant_override("margin_bottom", 24)
	inner_margin.add_theme_constant_override("margin_left", 20)
	inner_margin.add_theme_constant_override("margin_right", 20)
	panel.add_child(inner_margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	inner_margin.add_child(vbox)

	var type_badge: Label = Label.new()
	type_badge.text = "[ %s ]" % type_label_text
	type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_badge.add_theme_font_size_override("font_size", 22)
	type_badge.add_theme_color_override("font_color", type_color)
	vbox.add_child(type_badge)

	var icon_container: CenterContainer = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 100)
	icon_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_container)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = String(node_data.get("icon_path", ""))
	if icon_path != "" and FileAccess.file_exists(icon_path):
		icon_rect.texture = load(icon_path)
	else:
		var placeholder: PlaceholderTexture2D = PlaceholderTexture2D.new()
		placeholder.size = Vector2(80, 80)
		icon_rect.texture = placeholder
	icon_container.add_child(icon_rect)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var vague_label: Label = Label.new()
	vague_label.text = label_text
	vague_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vague_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vague_label.add_theme_font_size_override("font_size", 24)
	vague_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	vbox.add_child(vague_label)

	var floor_label: Label = Label.new()
	floor_label.text = "Floor %d" % floor_num
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_font_size_override("font_size", 18)
	floor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if is_boss:
		floor_label.add_theme_color_override("font_color", type_color)
	vbox.add_child(floor_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var enter_btn: Button = Button.new()
	if is_boss:
		enter_btn.text = "Face Boss"
	elif node_type == "bond":
		enter_btn.text = "Approach"
	elif node_type == "event":
		enter_btn.text = "Investigate"
	elif node_type == "rest":
		enter_btn.text = "Rest"
	else:
		enter_btn.text = "Enter"
	enter_btn.custom_minimum_size = Vector2(160, 44)
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter_btn.add_theme_font_size_override("font_size", 22)
	enter_btn.pressed.connect(_on_card_selected.bind(node_data))
	vbox.add_child(enter_btn)

	return panel


# ---------------------------------------------------------------------------
# Signal emission
# ---------------------------------------------------------------------------

func _on_card_selected(node_data: Dictionary) -> void:
	SignalBus.request_dungeon_node_select(node_data)
