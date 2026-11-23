extends "res://win95/window.gd"
## Win95's Close Program dialog, which Ctrl+Alt+Del opens: the open windows by title, then the
## computer's running tasks (BackgroundTask.task_name), the first selected. End Task closes the
## selected window, as its X does, or stops the selected task; Shut Down opens Shut Down Windows.
## Pressing Ctrl+Alt+Del again while it is open restarts the computer ([method restart]).

## The window that Shut Down opens.
@export var shut_down: PackedScene
## How long the desktop stays before the power goes off when Ctrl+Alt+Del restarts, in seconds.
@export_range(0.0, 10.0) var restart_wait_seconds: float = 0.0
## How long the power stays off while it restarts, in seconds.
@export_range(0.0, 10.0) var restart_off_seconds: float = 1.0

## The windows and tasks that the list shows, row by row.
var _entries: Array[Node] = []

@onready var _list: ItemList = %Programs


func _ready() -> void:
	super()
	var desktop := _desktop()
	if desktop == null:
		push_error("Close Program: not on a Win95Desktop, so it has no programs to list")
		return
	%EndTask.pressed.connect(end_task)
	%ShutDown.pressed.connect(_shut_down)
	%Cancel.pressed.connect(close)
	_list.item_activated.connect(func(_index: int) -> void: end_task())
	desktop.windows_changed.connect(_fill)
	if desktop.computer != null:
		desktop.computer.changed.connect(_fill)
	_fill()
	_list.grab_focus.call_deferred()


## What the list shows, row by row: the titles of the open windows, then the running tasks' names.
func program_names() -> PackedStringArray:
	var names := PackedStringArray()
	for i in _list.item_count:
		names.append(_list.get_item_text(i))
	return names


## Selects the row at [param index], as a click does.
func select(index: int) -> void:
	_list.select(index)


## Ends the selected program and closes the dialog: a window closes as its X closes it (one with
## unsaved work asks first); a task stops, and its file is free again.
func end_task() -> void:
	var selected := _list.get_selected_items()
	var entry: Node = _entries[selected[0]] if not selected.is_empty() and selected[0] < _entries.size() else null
	close()
	if entry is BackgroundTask:
		(entry as BackgroundTask).stop()
	elif is_instance_valid(entry):
		entry.call(&"request_close")


## Restarts the computer at once, as pressing Ctrl+Alt+Del a second time does.
func restart() -> void:
	close()
	var desktop := _desktop()
	if desktop != null and desktop.computer != null:
		desktop.computer.restart(restart_wait_seconds, restart_off_seconds)


func _shut_down() -> void:
	close()
	var desktop := _desktop()
	if desktop != null:
		desktop.open(shut_down)


# Keeps the selected row's program selected; the first row when it is gone.
func _fill() -> void:
	var desktop := _desktop()
	if desktop == null or not visible:
		return
	var selected := _list.get_selected_items()
	var kept: Node = _entries[selected[0]] if not selected.is_empty() and selected[0] < _entries.size() else null
	_entries.clear()
	_list.clear()
	for window: Control in desktop.windows():
		if window != self:
			var bar := window.get_node_or_null(^"%TitleBar")
			_entries.append(window)
			_list.add_item(str(bar.get(&"title")) if bar != null else String(window.name))
	if desktop.computer != null:
		for task: BackgroundTask in desktop.computer.tasks():
			_entries.append(task)
			_list.add_item(task.task_name)
	if not _entries.is_empty():
		_list.select(maxi(0, _entries.find(kept)))


func _desktop() -> Win95Desktop:
	return get_parent() as Win95Desktop
