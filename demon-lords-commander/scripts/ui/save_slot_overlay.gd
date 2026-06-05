extends Control

signal slot_selected(slot_index: int, is_new_game: bool)
signal closed

@onready var _title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var _slots_container: VBoxContainer = $Panel/Margin/VBox/ScrollContainer/SlotsVBox
@onready var _close_button: Button = $Panel/Margin/VBox/CloseButton

var _is_new_game_mode: bool = false


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	visible = false


func open(new_game_mode: bool) -> void:
	_is_new_game_mode = new_game_mode
	_title_label.text = "Select Save Slot" if new_game_mode else "Load Save Slot"
	_rebuild_slots()
	visible = true


func _rebuild_slots() -> void:
	for child: Node in _slots_container.get_children():
		child.queue_free()

	for i: int in range(SaveManager.MAX_SLOTS):
		_create_slot_row(i)


func _create_slot_row(slot_index: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 70)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var exists: bool = SaveManager.has_slot(slot_index)
	var meta: Dictionary = SaveManager.get_slot_metadata(slot_index)

	var number_label: Label = Label.new()
	number_label.text = "Slot %d" % (slot_index + 1)
	number_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(number_label)

	var info_label: Label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if exists:
		var waifu_name: String = String(meta.get("waifu_name", "???"))
		var location_name: String = String(meta.get("location_name", "???"))
		info_label.text = "%s — %s" % [waifu_name, location_name]
	else:
		info_label.text = "Empty"
	row.add_child(info_label)

	if _is_new_game_mode:
		var new_btn: Button = Button.new()
		new_btn.text = "New Game" if not exists else "Overwrite"
		new_btn.custom_minimum_size = Vector2(100, 35)
		new_btn.pressed.connect(_on_slot_new_game_pressed.bind(slot_index))
		row.add_child(new_btn)
	else:
		if exists:
			var play_btn: Button = Button.new()
			play_btn.text = "Play"
			play_btn.custom_minimum_size = Vector2(80, 35)
			play_btn.pressed.connect(_on_slot_play_pressed.bind(slot_index))
			row.add_child(play_btn)

			var delete_btn: Button = Button.new()
			delete_btn.text = "Delete"
			delete_btn.custom_minimum_size = Vector2(80, 35)
			delete_btn.pressed.connect(_on_slot_delete_pressed.bind(slot_index))
			row.add_child(delete_btn)
		else:
			var empty_label: Label = Label.new()
			empty_label.text = "—"
			row.add_child(empty_label)

	_slots_container.add_child(row)


func _on_slot_new_game_pressed(slot_index: int) -> void:
	SaveManager.create_new_profile_in_slot(slot_index)
	slot_selected.emit(slot_index, true)
	visible = false


func _on_slot_play_pressed(slot_index: int) -> void:
	SaveManager.load_slot(slot_index)
	slot_selected.emit(slot_index, false)
	visible = false


func _on_slot_delete_pressed(slot_index: int) -> void:
	SaveManager.delete_slot(slot_index)
	_rebuild_slots()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
