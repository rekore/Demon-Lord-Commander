extends Control

@onready var _return_button: Button = $OverallVerticalContainer/ButtonsHBox/Button


func _ready() -> void:
	_return_button.pressed.connect(_on_return_pressed)


func _on_return_pressed() -> void:
	SignalBus.request_return_to_title()
