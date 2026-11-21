extends "res://win95/window.gd"
## Notepad: one text field. File > New clears it.

enum FileMenu { NEW, CLOSE }

## The text that the window opens with, as a customer left it.
@export_multiline var text: String = ""
## The file extensions that this app opens, lower case, without the dot.
@export var opens: Array[String] = ["txt", "ini", "log"]

var _app_title: String

@onready var _text: TextEdit = %Text


func _ready() -> void:
	super()
	_app_title = %TitleBar.title
	_text.text = text
	%File.id_pressed.connect(_on_file_menu)


## Shows [param file]'s contents, titled "todo.txt - Notepad" as Win95 does.
func open_file(file: Win95File) -> void:
	%TitleBar.title = "%s - %s" % [file.name, _app_title]
	_text.text = file.contents


func _on_file_menu(id: int) -> void:
	match id:
		FileMenu.NEW:
			_text.text = ""
		FileMenu.CLOSE:
			close()
