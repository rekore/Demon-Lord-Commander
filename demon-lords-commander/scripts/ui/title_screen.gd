extends Control

@onready var _new_game_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button
@onready var _continue_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button2
@onready var _options_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button3
@onready var _quit_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button4
@onready var _reset_save_button: Button = $OverallVerticalContainer/ButtonsHBox/VBoxContainer/Button5


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_new_game_button.button_down.connect(_on_new_game_button_down)
	_new_game_button.gui_input.connect(_on_new_game_button_gui_input)
	_continue_button.pressed.connect(_on_continue_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_reset_save_button.pressed.connect(_on_reset_save_pressed)
	print(
		"[TitleScreen] Ready. Buttons connected. NewGame disabled=", _new_game_button.disabled,
		" visible=", _new_game_button.visible,
		" mouse_filter=", _new_game_button.mouse_filter,
		" focus_mode=", _new_game_button.focus_mode
	)


func _on_new_game_pressed() -> void:
	print("[TitleScreen] New Game clicked. Requesting new game via SignalBus.")
	SignalBus.request_new_game()
	print("[TitleScreen] SignalBus.request_new_game() emitted.")


func _on_new_game_button_down() -> void:
	print("[TitleScreen] New Game button_down fired.")


func _on_new_game_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			print("[TitleScreen] New Game gui_input left-click detected.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hovered: Control = get_viewport().gui_get_hovered_control()
			var hovered_name: String = hovered.name if hovered != null else "none"
			print("[TitleScreen] Global left-click. Hovered control=", hovered_name)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hovered: Control = get_viewport().gui_get_hovered_control()
			var hovered_name: String = hovered.name if hovered != null else "none"
			print("[TitleScreen] _input left-click. Hovered control=", hovered_name)


func _on_continue_pressed() -> void:
	SignalBus.request_continue()


func _on_options_pressed() -> void:
	SignalBus.request_options()


func _on_quit_pressed() -> void:
	SignalBus.request_quit()


func _on_reset_save_pressed() -> void:
	print("[TitleScreen] Reset Save clicked.")
	SaveManager.reset_save()
