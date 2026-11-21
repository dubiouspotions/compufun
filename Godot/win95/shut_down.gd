extends "res://win95/window.gd"
## The Shut Down Windows dialog. Shut down covers the screen with safe_off; restart and log on
## close every window.

@export var safe_off: PackedScene
## Plays on Yes, before Windows shuts down, restarts or logs off; null plays nothing.
@export var exit_sound: AudioStream


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
	Win95Desktop.play_sound(exit_sound, desktop)
	if %ShutDown.button_pressed:
		desktop.cover(safe_off)
	else:
		desktop.close_all()
