extends "res://win95/window.gd"
## The Shut Down Windows dialog. Shut down covers the screen with safe_off until the computer's power
## goes off (ComputerState.shut_down). Restart covers it with safe_off saying [member restart_text],
## then switches the power off and on (ComputerState.restart). Log on closes every window.

@export var safe_off: PackedScene
## What safe_off says while the computer restarts.
@export_multiline var restart_text: String = "Please wait while your computer\nrestarts..."
## How long [member restart_text] shows before the power goes off, in seconds.
@export_range(0.0, 10.0) var restart_wait_seconds: float = 2.0
## How long the power stays off while the computer restarts, in seconds.
@export_range(0.0, 10.0) var restart_off_seconds: float = 1.0
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
		desktop.computer.shut_down()
	elif %Restart.button_pressed:
		(desktop.cover(safe_off).get_node(^"Message") as Label).text = restart_text
		desktop.computer.restart(restart_wait_seconds, restart_off_seconds)
	else:
		desktop.close_all()
