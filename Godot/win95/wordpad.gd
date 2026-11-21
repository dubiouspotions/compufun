extends "res://win95/notepad.gd"
## WordPad: Notepad with the office assistant's frame beside the page. With assistant_present
## false the frame stays and is empty, as a computer with the NoClippy problem shows it.

## The group of every WordPad.
const GROUP: StringName = &"win95_wordpads"

## Metadata on the scene tree's root: true while Cambion has taken the assistant from every computer
## (the corruption sign corruption/no_clippy.tscn sets it, then calls _sync_assistant on GROUP). Not a
## static var: a GDScript static leaks the script's dependencies at exit.
const ASSISTANT_TAKEN_META: StringName = &"win95_assistant_taken"

@export var assistant_present: bool = true:
	set(value):
		assistant_present = value
		if is_node_ready():
			_sync_assistant()
## The assistant's picture; null leaves the space blank.
@export var assistant_picture: Texture2D


func _ready() -> void:
	super()
	add_to_group(GROUP)
	%Picture.texture = assistant_picture
	_sync_assistant()


func _sync_assistant() -> void:
	var taken: bool = is_inside_tree() and get_tree().root.get_meta(ASSISTANT_TAKEN_META, false)
	%Helper.visible = assistant_present and not taken
