extends Control

@onready var portrait: AnimatedSprite2D = $Portrait
@onready var stats_label: Label = find_child("StatsLabel") as Label
@onready var intent_label: Label = find_child("IntentLabel") as Label

@export var horizontal_padding: float = 6.0
@export var top_padding: float = 4.0
@export var bottom_padding: float = 6.0
@export var bottom_reserved: float = 0.0
@export_enum("bottom", "center") var sprite_anchor: String = "bottom"


func _ready() -> void:
	resized.connect(_on_resized)
	call_deferred("_position_portrait")


func _on_resized() -> void:
	_position_portrait()


func _position_portrait() -> void:
	if portrait == null or stats_label == null:
		return
	if portrait.sprite_frames == null:
		return
	if not portrait.sprite_frames.has_animation(portrait.animation):
		return

	var tex: Texture2D = portrait.sprite_frames.get_frame_texture(portrait.animation, portrait.frame)
	if tex == null:
		return

	var sprite_size: Vector2 = tex.get_size()
	if sprite_size.x <= 0 or sprite_size.y <= 0:
		return

	# Measure actual text height (the label box is 15px but holds 2 lines of text)
	var line_height: float = stats_label.get_line_height()
	var line_count: int = max(1, stats_label.get_line_count())
	var text_height: float = line_height * line_count
	var stats_bottom: float = stats_label.position.y + max(stats_label.size.y, text_height)

	var label_visual_bottom: float = stats_bottom
	if intent_label != null:
		var intent_line_height: float = intent_label.get_line_height()
		var intent_line_count: int = max(1, intent_label.get_line_count())
		var intent_text_height: float = intent_line_height * intent_line_count
		var intent_bottom: float = intent_label.position.y + max(intent_label.size.y, intent_text_height)
		label_visual_bottom = max(stats_bottom, intent_bottom)

	# Available area below the stats text
	var available_width: float = max(0.0, size.x - horizontal_padding * 2.0)
	var available_height: float = max(0.0, size.y - label_visual_bottom - top_padding - bottom_padding - bottom_reserved)

	if available_width <= 0.0 or available_height <= 0.0:
		return

	# Scale to fit while maintaining aspect ratio
	var scale_x: float = available_width / sprite_size.x
	var scale_y: float = available_height / sprite_size.y
	var fit_scale: float = min(scale_x, scale_y)

	portrait.scale = Vector2(fit_scale, fit_scale)

	# Center horizontally, align vertically based on anchor mode
	var scaled_size: Vector2 = sprite_size * fit_scale
	var center_x: float = size.x / 2.0
	var area_top: float = label_visual_bottom + top_padding
	var area_bottom: float = size.y - bottom_padding - bottom_reserved

	var pos_y: float = area_bottom - scaled_size.y / 2.0
	if sprite_anchor == "center":
		var available_center: float = area_top + available_height / 2.0
		pos_y = available_center

	# AnimatedSprite2D draws centered on its position
	portrait.position = Vector2(
		center_x,
		pos_y
	)
