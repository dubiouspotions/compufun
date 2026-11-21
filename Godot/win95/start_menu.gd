extends PopupMenu
## The Start menu: the installed programs, by name, then Shut Down. Opens above its parent, the
## Start button, when that is pressed. The programs are the runnable program files on the
## computer's drive C, so renaming or deleting one takes it off the menu. Names and icons come from
## the programs' own title bars.

## The window that Shut Down... opens.
@export var shut_down: PackedScene
@export var shut_down_icon: Texture2D

## The programs that the menu lists; an item's id is its index here.
var _programs: Array[PackedScene] = []

@onready var _button: Button = get_parent()
@onready var _state: ComputerState = owner.get_node_or_null(^"%ComputerState") if owner != null else null


func _ready() -> void:
	if _state == null:
		push_error("Start menu: no %ComputerState in the scene, so it lists no programs")
	else:
		_state.booted.connect(_rebuild)
		_state.changed.connect(_rebuild)
	_rebuild()
	_button.toggled.connect(func(on: bool) -> void:
		if on:
			var corner := Vector2i(_button.get_global_rect().position) - Vector2i(0, int(get_contents_minimum_size().y))
			PopupCatcher.attach(self, owner)
			popup(Rect2i(corner, Vector2i.ZERO))
		else:
			hide())
	popup_hide.connect(func() -> void: _button.set_pressed_no_signal(false))
	id_pressed.connect(_on_id_pressed)


func _rebuild() -> void:
	clear()
	_programs.clear()
	if _state != null:
		for file in _state.installed_programs():
			if not _programs.has(file.program):
				_programs.append(file.program)
	_programs.sort_custom(func(a: PackedScene, b: PackedScene) -> bool:
		return Win95Desktop.window_title(a).naturalnocasecmp_to(Win95Desktop.window_title(b)) < 0)
	for i in _programs.size():
		add_icon_item(Win95Desktop.window_icon(_programs[i]), Win95Desktop.window_title(_programs[i]), i)
	if shut_down:
		if not _programs.is_empty():
			add_separator()
		add_icon_item(shut_down_icon, "Shut Down...", _programs.size())


func _on_id_pressed(id: int) -> void:
	var desktop := get_tree().get_first_node_in_group(Win95Desktop.GROUP) as Win95Desktop
	if desktop == null:
		push_error("Start menu: no Win95Desktop in the tree")
		return
	desktop.open(shut_down if id == _programs.size() else _programs[id])
