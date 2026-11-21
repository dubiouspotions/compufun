extends "res://win95/window.gd"
## Notepad: one text field. File > New clears it.

enum FileMenu { NEW, CLOSE }

## The text that the window opens with, as a customer left it.
@export_multiline var text: String = ""

@onready var _text: TextEdit = %Text


func _ready() -> void:
	super()
	_text.text = text
	%File.id_pressed.connect(_on_file_menu)


func _on_file_menu(id: int) -> void:
	match id:
		FileMenu.NEW:
			_text.text = ""
		FileMenu.CLOSE:
			close()
