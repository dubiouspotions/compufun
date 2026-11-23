class_name DevMenu
extends CanvasLayer
## The Dev menu, F3 or Cmd+3 (debug builds only): tools for making the game, as opposed to the F2 or Cmd+2 debug
## menu's switches for playing it. One button per tool; a tool opens over the game and closes
## itself. F4 or Cmd+4 shows and hides the Story Lab.

## The tools, in order; each button shows the scene's file name.
@export var tools: Array[PackedScene] = []
## The tool that F4 shows and hides.
@export var story_lab: PackedScene

@onready var _panel: Control = %Panel
@onready var _list: VBoxContainer = %Tools


func _ready() -> void:
	_panel.visible = false
	for tool in tools:
		var button := Button.new()
		button.text = tool.resource_path.get_file().get_basename().capitalize()
		button.pressed.connect(_open.bind(tool))
		_list.add_child(button)
	var checkout := CheckButton.new()
	checkout.text = "Story Lab: save to checkout"
	checkout.tooltip_text = "Write story edits into res://story/ instead of keeping drafts, to commit them with git"
	checkout.button_pressed = StoryDrafts.saves_to_checkout()
	checkout.toggled.connect(_save_to_checkout)
	_list.add_child(checkout)
	_play_drafts()


# A writer's drafts play from the start, not only once the Story Lab opens.
func _play_drafts() -> void:
	if StoryDrafts.saves_to_checkout() or get_tree().get_script() != null:  # a test's SceneTree plays the files as they are
		return
	var drafts := StoryDrafts.new()
	for error: String in drafts.load_drafts():
		push_error("Dev menu: a Story Lab draft doesn't read: " + error)
	if drafts.texts().is_empty():
		return
	for error: String in Game.load_story(drafts.texts()):
		push_error("Dev menu: the game can't play the Story Lab drafts: " + error)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or not OS.is_debug_build():
		return
	if key.is_action_pressed(&"dev_menu"):
		_panel.visible = not _panel.visible
	elif key.is_action_pressed(&"story_lab") and story_lab != null:
		var open := _child(story_lab) as CanvasItem
		if open != null and open.visible:
			open.hide()
		else:
			_open(story_lab)
	else:
		return
	get_viewport().set_input_as_handled()


func _open(tool: PackedScene) -> void:
	_panel.visible = false
	var open := _child(tool)
	if open == null:
		add_child(tool.instantiate())
	elif open is CanvasItem:
		(open as CanvasItem).show()


func _child(tool: PackedScene) -> Node:
	for child in get_children():
		if child.scene_file_path == tool.resource_path:
			return child
	return null


func _save_to_checkout(on: bool) -> void:
	var failed := StoryDrafts.set_saves_to_checkout(on)
	if failed != "":
		push_error("Dev menu: Save to checkout isn't remembered: " + failed)
	var lab := _child(story_lab) if story_lab != null else null
	if lab != null:
		lab.set(&"to_checkout", on)
	if on and not StoryDrafts.warned_about_checkout():
		var warning := AcceptDialog.new()
		warning.title = "Save to checkout"
		warning.dialog_text = "The Story Lab now writes its edits into res://story/ in this checkout, and keeps no drafts.\nCommit them with git, or revert them there."
		add_child(warning)
		warning.popup_centered()
		failed = StoryDrafts.set_warned_about_checkout()
		if failed != "":
			push_error("Dev menu: the checkout warning will show again: " + failed)
