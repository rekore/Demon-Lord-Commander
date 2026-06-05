extends Control

const MAX_ZOOM: float = 3.0
const PAN_MARGIN: float = 700.0
var _min_zoom: float = 0.3

@onready var _breadcrumb_label: Label = $UIOverlay/BreadcrumbLabel
@onready var _back_button: Button = $UIOverlay/BackButton
@onready var _actions_panel: VBoxContainer = $UIOverlay/ActionsPanel
@onready var _battle_test_button: Button = $UIOverlay/BattleTestButton

@onready var _map_viewport: Control = $MapViewport
@onready var _map_content: Control = $MapViewport/MapContent
@onready var _background: TextureRect = $MapViewport/MapContent/Background
@onready var _fog_overlay: Control = $MapViewport/MapContent/FogOverlay
@onready var _pois_container: Control = $MapViewport/MapContent/POIsContainer

var _current_location_data: Dictionary = {}
var _map_size: Vector2 = Vector2(2000, 1500)
var _pan_offset: Vector2 = Vector2.ZERO
var _zoom_level: float = 1.0
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _pan_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_battle_test_button.pressed.connect(_on_battle_test_pressed)
	_map_viewport.resized.connect(_on_map_viewport_resized)
	SignalBus.poi_discovered.connect(_on_poi_discovered)

	_map_size = ContentDB.get_map_size()
	_resize_map_content(_map_size)

	_zoom_level = 1.0
	_refresh_ui()


func _on_poi_discovered(_poi_id: String) -> void:
	if GameState.current_location_id == "world_map":
		_refresh_ui()


func _on_map_viewport_resized() -> void:
	if GameState.current_location_id == "world_map":
		_recalculate_min_zoom()
		_clamp_pan()
		_update_map_transform()
	else:
		_fit_map_to_viewport()


func _resize_map_content(size: Vector2) -> void:
	_map_size = size
	_map_content.custom_minimum_size = _map_size
	_map_content.size = _map_size
	_background.size = _map_size
	_fog_overlay.size = _map_size
	_pois_container.size = _map_size


func _recalculate_min_zoom() -> void:
	var viewport_size: Vector2 = _map_viewport.size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var fit_zoom_x: float = viewport_size.x / _map_size.x
	var fit_zoom_y: float = viewport_size.y / _map_size.y
	var base_min: float = max(fit_zoom_x, fit_zoom_y)
	_min_zoom = min(base_min * 1.5, 1.0)


func _fit_map_to_viewport() -> void:
	var viewport_size: Vector2 = _map_viewport.size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var fit_zoom_x: float = viewport_size.x / _map_size.x
	var fit_zoom_y: float = viewport_size.y / _map_size.y
	_zoom_level = min(fit_zoom_x, fit_zoom_y)
	_zoom_level = clamp(_zoom_level, _min_zoom, MAX_ZOOM)
	_clamp_pan()
	_update_map_transform()


func _center_viewport_on(pos: Vector2) -> void:
	var viewport_size: Vector2 = _map_viewport.size
	_pan_offset = (viewport_size / 2.0) - (pos * _zoom_level)
	_clamp_pan()
	_update_map_transform()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_mouse(1.1, get_local_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_mouse(0.9, get_local_mouse_position())
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if _is_dragging:
				_drag_start_pos = get_local_mouse_position()
				_pan_start = _pan_offset
	elif event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = get_local_mouse_position() - _drag_start_pos
		_pan_offset = _pan_start + delta
		_clamp_pan()
		_update_map_transform()


func _zoom_at_mouse(factor: float, mouse_pos: Vector2) -> void:
	var old_zoom: float = _zoom_level
	var new_zoom: float = clamp(old_zoom * factor, _min_zoom, MAX_ZOOM)
	if abs(new_zoom - old_zoom) < 0.001:
		return
	var f: float = new_zoom / old_zoom
	_pan_offset = _pan_offset * f + mouse_pos * (1.0 - f)
	_zoom_level = new_zoom
	_clamp_pan()
	_update_map_transform()


func _update_map_transform() -> void:
	_map_content.position = _pan_offset
	_map_content.scale = Vector2(_zoom_level, _zoom_level)
	_update_poi_scales()


func _update_poi_scales() -> void:
	var inv_zoom: float = 1.0 / _zoom_level
	for child: Node in _pois_container.get_children():
		if not (child is Control):
			continue
		var c: Control = child as Control
		if not c.has_meta("map_pos"):
			continue
		var map_pos: Vector2 = c.get_meta("map_pos") as Vector2
		c.scale = Vector2(inv_zoom, inv_zoom)
		c.position = map_pos - c.size * inv_zoom * 0.5


func _clamp_pan() -> void:
	var viewport_size: Vector2 = _map_viewport.size
	var content_pixels: Vector2 = _map_size * _zoom_level
	var margin: float = PAN_MARGIN if GameState.current_location_id == "world_map" else 0.0

	if content_pixels.x <= viewport_size.x:
		_pan_offset.x = (viewport_size.x - content_pixels.x) / 2.0
	else:
		_pan_offset.x = clamp(_pan_offset.x, viewport_size.x - content_pixels.x - margin, margin)

	if content_pixels.y <= viewport_size.y:
		_pan_offset.y = (viewport_size.y - content_pixels.y) / 2.0
	else:
		_pan_offset.y = clamp(_pan_offset.y, viewport_size.y - content_pixels.y - margin, margin)


func _refresh_ui() -> void:
	var loc_id: String = GameState.current_location_id
	_current_location_data = ContentDB.get_location(loc_id)
	if _current_location_data.is_empty():
		push_warning("WorldMap: unknown location '%s'" % loc_id)
		return

	_update_background()
	_update_breadcrumb()
	_update_back_button()

	if loc_id == "world_map":
		_battle_test_button.visible = true
		_show_world_map_view()
	else:
		_battle_test_button.visible = false
		_show_interior_view()


func _show_world_map_view() -> void:
	_clear_map_children()

	var texture: Texture2D = _background.texture
	if texture != null:
		_resize_map_content(texture.get_size())
	else:
		_resize_map_content(ContentDB.get_map_size())

	_recalculate_min_zoom()
	_build_fog_patches()
	_build_poi_buttons()

	# Center on last visited location or first discovered POI (new game)
	_zoom_level = 1.0
	_center_viewport_on(_get_world_map_focus_pos())


func _show_interior_view() -> void:
	_clear_map_children()
	_rebuild_location_buttons()
	_build_interior_poi_buttons()

	var texture: Texture2D = _background.texture
	if texture != null:
		# Background image drives the content size; buttons sit at their map coords on top
		_resize_map_content(texture.get_size())
	else:
		# No background: auto-fit content to button bounds with padding
		var min_pos: Vector2 = Vector2(INF, INF)
		var max_pos: Vector2 = Vector2(-INF, -INF)
		for child: Node in _pois_container.get_children():
			if not (child is Control):
				continue
			var c: Control = child as Control
			var c_min: Vector2
			var c_max: Vector2
			if c.has_meta("map_pos"):
				var mp: Vector2 = c.get_meta("map_pos") as Vector2
				c_min = mp - c.size * 0.5
				c_max = mp + c.size * 0.5
			else:
				c_min = c.position
				c_max = c.position + c.size
			min_pos = min_pos.min(c_min)
			max_pos = max_pos.max(c_max)

		var padding: float = 100.0
		var content_size: Vector2
		if min_pos.x < INF:
			var offset: Vector2 = Vector2(padding, padding) - min_pos
			for child: Node in _pois_container.get_children():
				if not (child is Control):
					continue
				var c: Control = child as Control
				if c.has_meta("map_pos"):
					var mp: Vector2 = c.get_meta("map_pos") as Vector2
					c.set_meta("map_pos", mp + offset)
				else:
					c.position += offset
			content_size = (max_pos - min_pos) + Vector2(padding * 2, padding * 2)
		else:
			content_size = Vector2(800, 600)
		_resize_map_content(content_size)

	_fit_map_to_viewport()


func _build_interior_poi_buttons() -> void:
	var loc_id: String = GameState.current_location_id
	var btn_size: Vector2 = _get_button_size()
	for raw_poi: Variant in ContentDB.get_pois_for_location(loc_id):
		if not (raw_poi is Dictionary):
			continue
		var poi: Dictionary = raw_poi as Dictionary
		var poi_id: String = String(poi.get("id", ""))
		if poi_id == "":
			continue

		var btn: Button = Button.new()
		var name_value: Variant = poi.get("name", "???")
		btn.text = String(name_value) if name_value != null else "???"
		btn.custom_minimum_size = btn_size
		btn.size = btn_size
		var font_size: int = max(16, int(_map_viewport.size.y * 0.018))
		btn.add_theme_font_size_override("font_size", font_size)
		var pos: Dictionary = poi.get("position", {})
		var imap_pos: Vector2 = Vector2(int(pos.get("x", 0)), int(pos.get("y", 0)))
		btn.set_meta("map_pos", imap_pos)
		btn.position = imap_pos - btn_size * 0.5

		var int_icon_value: Variant = poi.get("icon_path", "")
		var int_icon_path: String = String(int_icon_value) if int_icon_value != null else ""
		if int_icon_path != "" and FileAccess.file_exists(int_icon_path):
			btn.text = ""
			_setup_icon_label_button(btn, int_icon_path, int(btn_size.y) - 8, String(poi.get("name", "???")), max(14, int(_map_viewport.size.y * 0.016)))

		btn.mouse_entered.connect(func(): btn.modulate = Color(1.4, 1.3, 0.5, 1.0))
		btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)

		var action: String = String(poi.get("action", "navigate"))
		if action == "battle":
			var battle_id: String = String(poi.get("battle_id", "tutorial_battle"))
			var enemy_id: String = String(poi.get("enemy_id", ""))
			btn.pressed.connect(_on_interior_battle_poi_clicked.bind(battle_id, enemy_id))
		else:
			var target_id: String = String(poi.get("target_location_id", ""))
			btn.pressed.connect(_on_poi_clicked.bind(target_id))

		_pois_container.add_child(btn)


func _on_interior_battle_poi_clicked(battle_id: String, enemy_id: String) -> void:
	var payload: Dictionary = {}
	if enemy_id != "":
		payload["enemy_id"] = enemy_id
	SignalBus.request_battle_start(battle_id, payload)


func _clear_map_children() -> void:
	for child: Node in _fog_overlay.get_children():
		child.queue_free()
	for child: Node in _pois_container.get_children():
		child.queue_free()


func _build_fog_patches() -> void:
	for raw_region: Variant in ContentDB.get_map_fog_regions():
		if not (raw_region is Dictionary):
			continue
		var region: Dictionary = raw_region as Dictionary
		var id_value: Variant = region.get("id", "")
		var region_id: String = String(id_value) if id_value != null else ""
		if region_id == "" or LocationService.is_fog_region_revealed(region_id):
			continue

		var fog_patch: ColorRect = ColorRect.new()
		var pos: Dictionary = region.get("position", {})
		var size_dict: Dictionary = region.get("size", {})
		fog_patch.position = Vector2(int(pos.get("x", 0)), int(pos.get("y", 0)))
		fog_patch.size = Vector2(int(size_dict.get("width", 100)), int(size_dict.get("height", 100)))
		fog_patch.color = Color(0.02, 0.02, 0.05, 0.92)
		fog_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fog_overlay.add_child(fog_patch)


func _setup_icon_label_button(btn: Button, icon_path: String, icon_px: int, label_text: String, font_size: int) -> void:
	# Strip all button background/border styleboxes so only the icon shows
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Icon container: glow panel lives here so it only wraps the icon, not the label
	var icon_container: Control = Control.new()
	icon_container.custom_minimum_size = Vector2(icon_px, icon_px)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow_panel: Panel = Panel.new()
	glow_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_panel.visible = false
	var glow_style: StyleBoxFlat = StyleBoxFlat.new()
	glow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glow_style.set_border_width_all(2)
	glow_style.border_color = Color(1.0, 0.85, 0.3, 1.0)
	glow_style.set_corner_radius_all(4)
	glow_style.shadow_color = Color(1.0, 0.75, 0.1, 0.85)
	glow_style.shadow_size = 10
	glow_style.shadow_offset = Vector2.ZERO
	glow_panel.add_theme_stylebox_override("panel", glow_style)
	icon_container.add_child(glow_panel)

	var img: Image = Image.new()
	if icon_path != "" and FileAccess.file_exists(icon_path) and img.load(icon_path) == OK:
		img.resize(icon_px, icon_px, Image.INTERPOLATE_LANCZOS)
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = ImageTexture.create_from_image(img)
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(icon_rect)

	vbox.add_child(icon_container)

	var label_container: PanelContainer = PanelContainer.new()
	var label_bg: StyleBoxFlat = StyleBoxFlat.new()
	label_bg.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	label_bg.set_corner_radius_all(3)
	label_bg.set_content_margin_all(4.0)
	label_container.add_theme_stylebox_override("panel", label_bg)
	label_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_container.add_child(label)
	vbox.add_child(label_container)

	btn.add_child(vbox)

	# Hover wired here for icon buttons; glow border replaces modulate tint
	btn.mouse_entered.connect(func(): glow_panel.visible = true)
	btn.mouse_exited.connect(func(): glow_panel.visible = false)


func _get_world_map_focus_pos() -> Vector2:
	var loc_id: String = SaveManager.profile.get("current_location_id", "world_map")
	while loc_id != "" and loc_id != "world_map":
		for raw_poi: Variant in ContentDB.get_map_pois():
			if not (raw_poi is Dictionary):
				continue
			var poi: Dictionary = raw_poi as Dictionary
			if String(poi.get("target_location_id", "")) == loc_id:
				var ppos: Dictionary = poi.get("position", {})
				return Vector2(int(ppos.get("x", 0)), int(ppos.get("y", 0)))
		var loc_data: Dictionary = ContentDB.get_location(loc_id)
		var parent_val: Variant = loc_data.get("parent", "")
		loc_id = String(parent_val) if parent_val != null else ""
	var discovered: Array = SaveManager.profile.get("discovered_pois", [])
	for raw_poi: Variant in ContentDB.get_map_pois():
		if not (raw_poi is Dictionary):
			continue
		var poi: Dictionary = raw_poi as Dictionary
		if discovered.has(String(poi.get("id", ""))):
			var ppos: Dictionary = poi.get("position", {})
			return Vector2(int(ppos.get("x", 0)), int(ppos.get("y", 0)))
	return _map_size * 0.5


func _get_button_size() -> Vector2:
	var vw: float = _map_viewport.size.x
	var vh: float = _map_viewport.size.y
	var w: float = max(180.0, vw * 0.09)
	var h: float = max(55.0, vh * 0.06)
	return Vector2(w, h)


func _build_poi_buttons() -> void:
	var base_size: Vector2 = _get_button_size()
	var font_size: int = max(18, int(_map_viewport.size.y * 0.02))
	var icon_px_f: float = base_size.x * 0.88
	var label_row_h: float = max(30.0, float(font_size) * 1.6)
	var icon_h: float = icon_px_f + label_row_h
	for raw_poi: Variant in ContentDB.get_map_pois():
		if not (raw_poi is Dictionary):
			continue
		var poi: Dictionary = raw_poi as Dictionary
		var id_value: Variant = poi.get("id", "")
		var poi_id: String = String(id_value) if id_value != null else ""
		if poi_id == "" or not LocationService.is_poi_visible(poi_id):
			continue

		var icon_value: Variant = poi.get("icon_path", "")
		var icon_path: String = String(icon_value) if icon_value != null else ""
		var has_icon: bool = icon_path != "" and FileAccess.file_exists(icon_path)
		var btn_size: Vector2 = Vector2(base_size.x, icon_h) if has_icon else base_size

		var btn: Button = Button.new()
		btn.custom_minimum_size = btn_size
		btn.size = btn_size

		var name_value: Variant = poi.get("name", "???")
		var poi_name: String = String(name_value) if name_value != null else "???"
		if has_icon:
			btn.text = ""
			_setup_icon_label_button(btn, icon_path, int(icon_px_f), poi_name, font_size)
			# hover wired inside _setup_icon_label_button
		else:
			btn.text = poi_name
			btn.add_theme_font_size_override("font_size", font_size)
			btn.mouse_entered.connect(func(): btn.modulate = Color(1.4, 1.3, 0.5, 1.0))
			btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)

		var pos: Dictionary = poi.get("position", {})
		var map_pos: Vector2 = Vector2(int(pos.get("x", 0)), int(pos.get("y", 0)))
		btn.set_meta("map_pos", map_pos)
		btn.position = map_pos - btn_size * 0.5

		var target_value: Variant = poi.get("target_location_id", "")
		var target_id: String = String(target_value) if target_value != null else ""
		btn.pressed.connect(_on_poi_clicked.bind(target_id))
		_pois_container.add_child(btn)


func _rebuild_location_buttons() -> void:
	for child: Node in _pois_container.get_children():
		child.queue_free()

	var children: Array = _current_location_data.get("children", [])
	for child_id: Variant in children:
		var child_id_str: String = String(child_id) if child_id != null else ""
		var child_data: Dictionary = ContentDB.get_location(child_id_str)
		if child_data.is_empty():
			continue
		if child_id_str == "" or not LocationService.is_location_visible(child_id_str):
			continue
		_create_location_button(child_data)


func _create_location_button(loc_data: Dictionary) -> void:
	var btn_size: Vector2 = _get_button_size()
	var btn: Button = Button.new()
	var name_value: Variant = loc_data.get("name", "???")
	btn.text = String(name_value) if name_value != null else "???"
	btn.custom_minimum_size = btn_size
	btn.size = btn_size
	var font_size: int = max(16, int(_map_viewport.size.y * 0.018))
	btn.add_theme_font_size_override("font_size", font_size)

	var pos: Dictionary = loc_data.get("position", {})
	var pos_x: int = int(pos.get("x", 0))
	var pos_y: int = int(pos.get("y", 0))
	var map_pos: Vector2 = Vector2(pos_x, pos_y)
	btn.set_meta("map_pos", map_pos)
	btn.position = map_pos - btn_size * 0.5

	btn.mouse_entered.connect(func(): btn.modulate = Color(1.4, 1.3, 0.5, 1.0))
	btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)

	var id_value: Variant = loc_data.get("id", "")
	var loc_id: String = String(id_value) if id_value != null else ""
	btn.pressed.connect(_on_location_clicked.bind(loc_id))
	_pois_container.add_child(btn)


func _update_background() -> void:
	var art_value: Variant = _current_location_data.get("art_path", "")
	var art_path: String = String(art_value) if art_value != null else ""
	if art_path != "" and FileAccess.file_exists(art_path):
		var image: Image = Image.new()
		var err: Error = image.load(art_path)
		if err == OK:
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			_background.texture = texture
			_background.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		else:
			push_warning("WorldMap: failed to load image '%s' (error %d)" % [art_path, err])
			_background.texture = null
	else:
		_background.texture = null


func _update_breadcrumb() -> void:
	var parts: Array[String] = []
	var current_id: String = GameState.current_location_id
	while current_id != "":
		var loc: Dictionary = ContentDB.get_location(current_id)
		if loc.is_empty():
			break
		var name_value: Variant = loc.get("name", current_id)
		parts.append(String(name_value) if name_value != null else current_id)
		var parent_value: Variant = loc.get("parent", "")
		current_id = String(parent_value) if parent_value != null else ""
	parts.reverse()
	_breadcrumb_label.text = " > ".join(parts) if parts.size() > 0 else ""


func _update_actions() -> void:
	for child: Node in _actions_panel.get_children():
		child.queue_free()


func _update_back_button() -> void:
	var parent_value: Variant = _current_location_data.get("parent", "")
	var parent_id: String = String(parent_value) if parent_value != null else ""
	_back_button.visible = parent_id != ""


func _on_poi_clicked(target_location_id: String) -> void:
	SignalBus.request_location_change(target_location_id)
	_refresh_ui()
	SaveManager.save_profile()


func _on_location_clicked(location_id: String) -> void:
	var loc_data: Dictionary = ContentDB.get_location(location_id)
	var dialogue_val: Variant = loc_data.get("dialogue_on_enter", "")
	var dialogue_id: String = String(dialogue_val) if dialogue_val != null else ""
	if dialogue_id != "":
		SignalBus.request_dialogue_start(dialogue_id)
		return
	SignalBus.request_location_change(location_id)
	_refresh_ui()
	SaveManager.save_profile()


func _on_back_pressed() -> void:
	var parent_value: Variant = _current_location_data.get("parent", "")
	var parent_id: String = String(parent_value) if parent_value != null else ""
	if parent_id != "":
		SignalBus.request_location_change(parent_id)
		_refresh_ui()
		SaveManager.save_profile()


func _on_battle_test_pressed() -> void:
	SignalBus.request_battle_start("tutorial_battle")


func _on_action_pressed(action: String, event: Dictionary) -> void:
	match action:
		"rest":
			print("Rest action triggered at %s" % GameState.current_location_id)
		"talk":
			SignalBus.request_dialogue_start("testshopkeeper")
		"shop":
			SignalBus.request_dialogue_start("testshopkeeper")
		"bond":
			print("Bond action triggered at %s" % GameState.current_location_id)
		"explore":
			print("Explore action triggered at %s" % GameState.current_location_id)
		"battle":
			SignalBus.request_battle_start("tutorial_battle")
		_:
			push_warning("WorldMap: unknown action '%s'" % action)
