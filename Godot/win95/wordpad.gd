extends "res://win95/notepad.gd"
## WordPad: Notepad with the office assistant's frame beside the page. With assistant_present
## false the frame stays and is empty, as a computer with the NoClippy problem shows it.

## The group of every WordPad.
const GROUP: StringName = &"win95_wordpads"

## True while Cambion has taken the assistant from every computer (the corruption sign
## corruption/no_clippy.tscn sets it): every WordPad shows the empty frame.
static var assistant_taken: bool = false:
	set(value):
		if value == assistant_taken:
			return
		assistant_taken = value
		(Engine.get_main_loop() as SceneTree).call_group(GROUP, &"_sync_assistant")

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
	%Helper.visible = assistant_present and not assistant_taken
