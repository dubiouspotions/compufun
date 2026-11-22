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

