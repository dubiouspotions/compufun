class_name DevMenu
extends CanvasLayer
## The Dev menu, F3 or Cmd+3 (debug builds only): tools for making the game, as opposed to the F2 or Cmd+2 debug
## menu's switches for playing it. One button per tool; a tool opens over the game and closes
## itself.

## The tools, in order; each button shows the scene's file name.
@export var tools: Array[PackedScene] = []

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
	if key != null and not key.echo and key.is_action_pressed(&"dev_menu") and OS.is_debug_build():
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _open(tool: PackedScene) -> void:
	_panel.visible = false
	for child in get_children():
		if child.scene_file_path == tool.resource_path:
			return
	add_child(tool.instantiate())
