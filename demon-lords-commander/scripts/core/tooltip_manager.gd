extends Node

# ---------------------------------------------------------------------------
# TooltipManager — global autoload.
#
# Usage:
#   TooltipManager.show_tooltip(body_text, optional_title)
#   TooltipManager.hide_tooltip()
#
# When a title is supplied the tooltip renders:
#   ┌───────────────────────────────┐
#   │  Item Name              [TAG] │  ← title row
#   │  ───────────────────────────  │  ← separator
#   │  Description text that wraps  │  ← body
#   └───────────────────────────────┘
# Without a title: just the body.
# ---------------------------------------------------------------------------

const INNER_W: float  = 340.0
const PAD: float      = 14.0
const OFFSET: Vector2 = Vector2(18.0, 18.0)
const FADE_TIME: float = 0.10

var _canvas: CanvasLayer
var _panel: PanelContainer   # PanelContainer auto-sizes to children
var _vbox: VBoxContainer
var _title_lbl: Label
var _sep: HSeparator
var _body_lbl: Label
var _tween: Tween


func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 128
	add_child(_canvas)

	# PanelContainer: background is drawn by the StyleBox and size matches children.
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color            = Color(0.07, 0.06, 0.11, 0.85)
	style.border_color        = Color(0.65, 0.58, 0.48)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color        = Color(0.0, 0.0, 0.0, 0.60)
	style.shadow_size         = 8
	style.content_margin_left   = PAD
	style.content_margin_right  = PAD
	style.content_margin_top    = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_vbox)

	_title_lbl = Label.new()
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.custom_minimum_size = Vector2(INNER_W, 0)
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	_title_lbl.add_theme_constant_override("outline_size", 1)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_lbl.visible = false
	_vbox.add_child(_title_lbl)

	_sep = HSeparator.new()
	_sep.visible = false
	_vbox.add_child(_sep)

	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.custom_minimum_size = Vector2(INNER_W, 0)
	_body_lbl.add_theme_font_size_override("font_size", 17)
	_body_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
	_body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_body_lbl)


func show_tooltip(text: String, title: String = "") -> void:
	if text.strip_edges() == "" and title.strip_edges() == "":
		return

	var has_title: bool = title.strip_edges() != ""
	_title_lbl.text    = title
	_title_lbl.visible = has_title
	_sep.visible       = has_title
	_body_lbl.text     = text
	_body_lbl.visible  = text.strip_edges() != ""

	_panel.modulate.a = 0.0
	_panel.visible    = true
	_position_panel()

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_TIME)


func hide_tooltip() -> void:
	_panel.visible = false
	if _tween and _tween.is_valid():
		_tween.kill()


func _process(_delta: float) -> void:
	if _panel.visible:
		_position_panel()


func _position_panel() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var mp: Vector2  = vp.get_mouse_position()
	var pos: Vector2 = mp + OFFSET
	var vp_size: Vector2 = vp.get_visible_rect().size
	var ps: Vector2      = _panel.size
	pos.x = minf(pos.x, vp_size.x - ps.x - 8.0)
	pos.y = minf(pos.y, vp_size.y - ps.y - 8.0)
	pos.x = maxf(pos.x, 4.0)
	pos.y = maxf(pos.y, 4.0)
	_panel.position = pos
