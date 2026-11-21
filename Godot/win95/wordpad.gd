extends "res://win95/notepad.gd"
## WordPad: Notepad with the office assistant's frame beside the page. With assistant_present
## false the frame stays and is empty, as a computer with the NoClippy problem shows it.

@export var assistant_present: bool = true:
	set(value):
		assistant_present = value
		if is_node_ready():
			_sync_assistant()
## The assistant's picture; null leaves the space blank.
@export var assistant_picture: Texture2D


func _ready() -> void:
	super()
	%Picture.texture = assistant_picture
	_sync_assistant()


func _sync_assistant() -> void:
	%Helper.visible = assistant_present
