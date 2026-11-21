extends "res://win95/window.gd"
## A Win95 message box with the error icon, a message and OK.


func _ready() -> void:
	super()
	%Ok.pressed.connect(close)


## Shows [param text] under the title [param title].
func show_message(title: String, text: String) -> void:
	%TitleBar.title = title
	%Text.text = text
	reset_size()
