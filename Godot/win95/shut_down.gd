extends "res://win95/window.gd"
## The Shut Down Windows dialog. Shut down covers the screen with safe_off; restart and log on
## close every window.

@export var safe_off: PackedScene


func _ready() -> void:
	super()
	%Yes.pressed.connect(_on_yes)
	%No.pressed.connect(close)


func _on_yes() -> void:
	close()
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("Shut Down: not on a Win95Desktop, so there is nothing to shut down")
		return
	if %ShutDown.button_pressed:
		desktop.cover(safe_off)
	else:
		desktop.close_all()
