extends Control

@onready var _new_game_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button
@onready var _continue_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button2
@onready var _load_game_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button3
@onready var _options_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button4
@onready var _quit_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button5
@onready var _reset_save_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button6
@onready var _slot_overlay: Control = $SaveSlotOverlay


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_load_game_button.pressed.connect(_on_load_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_reset_save_button.pressed.connect(_on_reset_save_pressed)
	_slot_overlay.slot_selected.connect(_on_slot_selected)
	_slot_overlay.closed.connect(_on_slot_overlay_closed)


func _on_new_game_pressed() -> void:
	_slot_overlay.open(true)


func _on_continue_pressed() -> void:
	if SaveManager.active_slot_index >= 0:
		SaveManager.load_slot(SaveManager.active_slot_index)
		SignalBus.request_continue()
	else:
		_slot_overlay.open(false)


func _on_load_game_pressed() -> void:
	_slot_overlay.open(false)


func _on_slot_selected(slot_index: int, is_new_game: bool) -> void:
	if is_new_game:
		SignalBus.request_new_game()
	else:
		SignalBus.request_continue()


func _on_slot_overlay_closed() -> void:
	pass


func _on_options_pressed() -> void:
	SignalBus.request_options()


func _on_quit_pressed() -> void:
	SignalBus.request_quit()


func _on_reset_save_pressed() -> void:
	print("[TitleScreen] Reset Save clicked.")
	SaveManager.reset_save()
