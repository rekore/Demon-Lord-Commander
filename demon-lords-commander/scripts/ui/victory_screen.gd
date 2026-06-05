extends Control

@onready var _return_button: Button = $OverallVerticalContainer/ButtonsHBox/Button
@onready var _continue_button: Button = $OverallVerticalContainer/ButtonsHBox/ContinueButton


func _ready() -> void:
	_return_button.pressed.connect(_on_return_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)


func _on_return_pressed() -> void:
	SaveManager.save_profile()
	SignalBus.request_return_to_title()


func _on_continue_pressed() -> void:
	SaveManager.save_profile()
	SignalBus.request_continue()
