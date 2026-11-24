extends "res://win95/window.gd"
## The PowerPoint dialog that opens with PowerPoint: create a presentation with the AutoContent
## wizard, a template or a blank presentation, or open one. The game builds Blank presentation.

## The player pressed OK with Blank presentation picked.
signal blank_chosen


func _ready() -> void:
	super()
	%Ok.pressed.connect(func() -> void:
		if %Blank.button_pressed:
			blank_chosen.emit()
		close())
	%Cancel.pressed.connect(close)
	closed.connect(queue_free)


func _focus_default() -> void:
	%Ok.grab_focus()
