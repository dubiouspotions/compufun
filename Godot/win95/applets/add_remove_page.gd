extends PropertyPage
## Add/Remove Programs > Install/Uninstall: the computer's removable programs (the folders in
## C:\Program Files) by name. Add/Remove... asks, and on Yes uninstalls the selected program at
## once, as Win95 runs a program's uninstaller without waiting for Apply.

const _MESSAGE := preload("res://win95/message_box.tscn")

var _computer: ComputerState
var _programs: Array[Win95File] = []

@onready var _list: ItemList = %Programs
@onready var _add_remove: Button = %AddRemove


func load_from(computer: ComputerState) -> void:
	_computer = computer
	_list.item_selected.connect(func(_index: int) -> void: _add_remove.disabled = false)
	_add_remove.pressed.connect(_confirm)
	computer.changed.connect(_fill)
	_fill()


func _fill() -> void:
	_programs = _computer.removable_programs()
	_list.clear()
	for program in _programs:
		_list.add_item(program.name)
	_add_remove.disabled = true


func _confirm() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		return
	var program := _programs[selected[0]]
	var desktop := _desktop()
	if desktop == null:
		push_error("Add/Remove Programs: not on a Win95Desktop, so it can't ask to remove %s" % program.name)
		return
	var box: Node = desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	box.answered.connect(func(button: String) -> void:
		if button == "Yes":
			_computer.uninstall(program))
	box.ask("Confirm File Deletion", "Are you sure you want to completely remove '%s' and all of its components?" % program.name, ["Yes", "No"] as Array[String])


func _desktop() -> Win95Desktop:
	var node := get_parent()
	while node != null and not node is Win95Desktop:
		node = node.get_parent()
	return node as Win95Desktop
