extends "res://win95/document_window.gd"
## Notepad: one text field that shows and saves a text file.

## The text that the window opens with, as a customer left it.
@export_multiline var text: String = ""
## The file extensions that this app opens, lower case, without the dot.
@export var opens: Array[String] = ["txt", "ini", "log"]

@onready var _text: TextEdit = %Text


func _ready() -> void:
	super()
	_text.text = text


func _load(from: Win95File) -> void:
	_text.text = from.contents if from != null else ""


func _save(state: ComputerState, into: Win95File) -> void:
	state.write_text(into, _text.text)


func _is_dirty() -> bool:
	return file != null and _text.text != file.contents


func _unsaved_question(path: String) -> String:
	return "The text in the %s file has changed.\n\nDo you want to save the changes?" % path
