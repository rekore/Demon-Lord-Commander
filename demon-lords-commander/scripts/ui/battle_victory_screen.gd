extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/Card.tscn")
const CardUIScript = preload("res://scripts/battle/card_ui.gd")

# Static refs — built in _build_ui()
var _outer_vbox: VBoxContainer
var _content_vbox: VBoxContainer   # dynamic sections inserted here by set_loot()
var _continue_button: Button

# Dynamic refs — set during set_loot()
var _take_all_btn: Button
var _skip_button: Button

# Runtime state
var _collected_items: Array = []
var _card_chosen: bool = false
var _chosen_card: Dictionary = {}
var _loot_rows: Array = []    # [{row, item, collected}] — all rows across all sections
var _card_panels: Array = []  # [{panel, card}]


func _ready() -> void:
	_build_ui()


func set_loot(loot: Dictionary) -> void:
	# — Auto-collect gold —
	var gold: int = int(loot.get("gold", 0))
	if gold > 0:
		SaveManager.profile["gold"] = int(SaveManager.profile.get("gold", 0)) + gold
		SaveManager.save_profile()

	# — Bucket drops by type —
	var drops: Array = loot.get("drops", [])
	var relics: Array    = []
	var card_packs: Array = []
	var materials: Array = []
	var trash: Array     = []
	for raw: Variant in drops:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		var pool_type: String = String(item.get("_pool_type", ""))
		var item_type: String = pool_type if pool_type != "" else String(item.get("type", "trash"))
		match item_type:
			"relic_run": relics.append(item)
			"card_pack": card_packs.append(item)
			"material":  materials.append(item)
			_:           trash.append(item)

	# — Build sections in priority order —
	if not relics.is_empty():
		_add_item_section("RUN RELICS", relics, Color(0.85, 0.32, 0.92))
	if not card_packs.is_empty():
		_add_item_section("CARD PACKS", card_packs, Color(0.95, 0.72, 0.18))
	_add_card_section(loot.get("card_choices", []))
	if not materials.is_empty():
		_add_item_section("MATERIALS", materials, Color(0.30, 0.75, 0.92))
	if not trash.is_empty():
		_add_item_section("SPOILS", trash, Color(0.52, 0.52, 0.55))

	# — Take All (only when items exist) —
	if not drops.is_empty():
		_take_all_btn = Button.new()
		_take_all_btn.text = "Take All"
		_take_all_btn.custom_minimum_size = Vector2(220, 52)
		_take_all_btn.add_theme_font_size_override("font_size", 20)
		_take_all_btn.pressed.connect(_on_take_all_pressed)
		var ta_center: CenterContainer = CenterContainer.new()
		ta_center.add_child(_take_all_btn)
		_content_vbox.add_child(ta_center)

	# — Gold display at bottom —
	_content_vbox.add_child(_make_separator())
	var gold_lbl: Label = Label.new()
	gold_lbl.text = "+ %d Gold" % gold
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 30)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.10))
	_content_vbox.add_child(gold_lbl)


# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24.0
	scroll.offset_right = -24.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_outer_vbox = VBoxContainer.new()
	_outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(_outer_vbox)

	var top_space: Control = Control.new()
	top_space.custom_minimum_size = Vector2(0, 28)
	_outer_vbox.add_child(top_space)

	var title: Label = Label.new()
	title.text = "VICTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.18))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.38, 0.22, 0.0))
	_outer_vbox.add_child(title)

	# Dynamic reward sections are appended here by set_loot()
	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 18)
	_outer_vbox.add_child(_content_vbox)

	_outer_vbox.add_child(_make_separator())

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.disabled = true
	_continue_button.custom_minimum_size = Vector2(260, 64)
	_continue_button.add_theme_font_size_override("font_size", 26)
	_continue_button.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_continue_button.pressed.connect(_on_continue_pressed)
	var btn_center: CenterContainer = CenterContainer.new()
	btn_center.add_child(_continue_button)
	_outer_vbox.add_child(btn_center)

	var bottom_space: Control = Control.new()
	bottom_space.custom_minimum_size = Vector2(0, 40)
	_outer_vbox.add_child(bottom_space)


# ---------------------------------------------------------------------------
# Section builders (called by set_loot in priority order)
# ---------------------------------------------------------------------------

func _add_item_section(header: String, items: Array, accent_color: Color) -> void:
	_content_vbox.add_child(_make_separator())
	_content_vbox.add_child(_make_section_header(header, accent_color))

	var loot_center: CenterContainer = CenterContainer.new()
	loot_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(loot_center)

	var list: VBoxContainer = VBoxContainer.new()
	list.custom_minimum_size = Vector2(740.0, 0)
	list.add_theme_constant_override("separation", 8)
	loot_center.add_child(list)

	for i: int in range(items.size()):
		var item: Dictionary = items[i] as Dictionary
		var row: Panel = _make_loot_row(item)
		row.modulate.a = 0.0
		row.position.x = -30.0
		list.add_child(row)
		_loot_rows.append({"row": row, "item": item, "collected": false})

		var tw: Tween = create_tween()
		tw.tween_interval(0.08 * float(i))
		tw.tween_property(row, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(row, "position:x", 0.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _add_card_section(card_choices: Array) -> void:
	if card_choices.is_empty():
		_card_chosen = true
		_update_continue()
		return

	_content_vbox.add_child(_make_separator())
	_content_vbox.add_child(_make_section_header("CARD REWARD", Color(0.88, 0.75, 0.40)))

	var card_container: HBoxContainer = HBoxContainer.new()
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	card_container.add_theme_constant_override("separation", 20)
	_content_vbox.add_child(card_container)

	for raw: Variant in card_choices:
		if not (raw is Dictionary):
			continue
		var card: Dictionary = raw as Dictionary
		var card_ui: Control = CARD_SCENE.instantiate() as Control
		card_ui.call("setup", card, CardUIScript.CardSize.FULL)
		card_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		card_ui.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mbe: InputEventMouseButton = event as InputEventMouseButton
				if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
					_on_card_chosen(card_ui, card)
		)
		card_container.add_child(card_ui)
		_card_panels.append({"panel": card_ui, "card": card})

	_skip_button = Button.new()
	_skip_button.text = "Skip Card Reward"
	_skip_button.add_theme_font_size_override("font_size", 16)
	_skip_button.add_theme_color_override("font_color", Color(0.50, 0.50, 0.52))
	_skip_button.pressed.connect(_on_skip_pressed)
	var skip_center: CenterContainer = CenterContainer.new()
	skip_center.add_child(_skip_button)
	_content_vbox.add_child(skip_center)


func _make_loot_row(item: Dictionary) -> Panel:
	var pool_type: String = String(item.get("_pool_type", ""))
	var item_type: String = pool_type if pool_type != "" else String(item.get("type", "trash"))
	var item_name: String = String(item.get("name", "Unknown Item"))
	var item_desc: String = String(item.get("description", ""))
	var sell_val: int = int(item.get("sell_value", 0))

	var type_color: Color = Color(0.52, 0.52, 0.55)
	var badge_text: String = "TRASH"
	match item_type:
		"material":
			type_color = Color(0.30, 0.75, 0.92)
			badge_text = "MATERIAL"
		"consumable":
			type_color = Color(0.28, 0.88, 0.45)
			badge_text = "CONSUMABLE"
		"card_pack":
			type_color = Color(0.95, 0.72, 0.18)
			badge_text = "CARD PACK"
		"relic_run":
			type_color = Color(0.85, 0.32, 0.92)
			badge_text = "RUN RELIC"

	# Outer panel — dark background, left accent border
	var row: Panel = Panel.new()
	row.custom_minimum_size = Vector2(0, 68)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var row_style_normal: StyleBoxFlat = StyleBoxFlat.new()
	row_style_normal.bg_color = Color(0.10, 0.09, 0.15)
	row_style_normal.border_color = type_color
	row_style_normal.border_width_left = 5
	row_style_normal.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", row_style_normal)

	# Hover style
	var row_style_hover: StyleBoxFlat = row_style_normal.duplicate() as StyleBoxFlat
	row_style_hover.bg_color = Color(0.16, 0.14, 0.22)
	row_style_hover.border_color = type_color.lightened(0.2)

	row.mouse_entered.connect(func() -> void:
		if not _is_row_collected(row):
			row.add_theme_stylebox_override("panel", row_style_hover)
		TooltipManager.show_tooltip(item_desc, item_name)
	)
	row.mouse_exited.connect(func() -> void:
		if not _is_row_collected(row):
			row.add_theme_stylebox_override("panel", row_style_normal)
		TooltipManager.hide_tooltip()
	)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mbe: InputEventMouseButton = event as InputEventMouseButton
			if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
				_collect_row(row)
	)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Item name — big
	var name_lbl: Label = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = item_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# Right side: sell value + type badge stacked
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	if sell_val > 0:
		var sell_lbl: Label = Label.new()
		sell_lbl.text = "%dG" % sell_val
		sell_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sell_lbl.add_theme_font_size_override("font_size", 15)
		sell_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.10))
		sell_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_vbox.add_child(sell_lbl)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = badge_text
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_lbl.add_theme_font_size_override("font_size", 14)
	badge_lbl.add_theme_color_override("font_color", type_color)
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(badge_lbl)

	return row


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _collect_row(row: Panel) -> void:
	for i: int in range(_loot_rows.size()):
		var entry: Dictionary = _loot_rows[i]
		if entry["row"] == row and not bool(entry["collected"]):
			_loot_rows[i]["collected"] = true
			_collected_items.append(entry["item"])
			_mark_row_collected(row)
			_check_take_all_done()
			break


func _mark_row_collected(row: Panel) -> void:
	var name_lbl: Node = row.find_child("NameLabel", true, false)
	if name_lbl is Label:
		var lbl: Label = name_lbl as Label
		lbl.text = "✓  " + lbl.text
		lbl.add_theme_color_override("font_color", Color(0.42, 0.88, 0.42))

	var collected_style: StyleBoxFlat = StyleBoxFlat.new()
	collected_style.bg_color = Color(0.08, 0.18, 0.08)
	collected_style.border_color = Color(0.28, 0.68, 0.28)
	collected_style.border_width_left = 5
	collected_style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", collected_style)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _check_take_all_done() -> void:
	var all_done: bool = true
	for entry: Variant in _loot_rows:
		if not bool((entry as Dictionary)["collected"]):
			all_done = false
			break
	if all_done and _take_all_btn != null:
		_take_all_btn.text = "All Taken ✓"
		_take_all_btn.disabled = true


func _on_take_all_pressed() -> void:
	for i: int in range(_loot_rows.size()):
		if not bool(_loot_rows[i]["collected"]):
			_loot_rows[i]["collected"] = true
			_collected_items.append(_loot_rows[i]["item"])
			_mark_row_collected(_loot_rows[i]["row"] as Panel)
	if _take_all_btn != null:
		_take_all_btn.text = "All Taken ✓"
		_take_all_btn.disabled = true


func _on_card_chosen(card_ui: Control, card: Dictionary) -> void:
	_card_chosen = true
	_chosen_card = card

	# Reset all cards so the player can change their mind freely
	for entry: Variant in _card_panels:
		var p: Control = (entry as Dictionary)["panel"] as Control
		p.call("set_unplayable_tint", false)
		p.mouse_filter = Control.MOUSE_FILTER_STOP

	# Highlight chosen, dim the rest
	for entry: Variant in _card_panels:
		var p: Control = (entry as Dictionary)["panel"] as Control
		if p == card_ui:
			p.modulate = Color(0.75, 1.0, 0.75)
		else:
			p.call("set_unplayable_tint", true)

	if _skip_button != null:
		_skip_button.disabled = false
	_update_continue()


func _on_skip_pressed() -> void:
	_card_chosen = true
	_chosen_card = {}
	if _skip_button != null:
		_skip_button.text = "Skipped — click a card to change"
		_skip_button.disabled = true
	# Dim cards but keep them clickable so the player can still pick one
	for entry: Variant in _card_panels:
		var p: Control = (entry as Dictionary)["panel"] as Control
		p.call("set_unplayable_tint", true)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_continue()


func _on_continue_pressed() -> void:
	DungeonService.apply_loot_rewards(_collected_items, _chosen_card)
	SignalBus.broadcast_dungeon_rewards_claimed()


func _update_continue() -> void:
	if _continue_button != null:
		_continue_button.disabled = not _card_chosen


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _is_row_collected(row: Panel) -> bool:
	for entry: Variant in _loot_rows:
		var e: Dictionary = entry as Dictionary
		if e["row"] == row:
			return bool(e["collected"])
	return false


func _make_section_header(text: String, accent_color: Color = Color(0.65, 0.60, 0.55)) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", accent_color)
	return lbl


func _make_separator() -> HSeparator:
	return HSeparator.new()
