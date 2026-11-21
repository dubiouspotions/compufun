extends PopupMenu
## The Start menu: one item per program, then Shut Down. Opens above its parent, the Start button,
## when that is pressed. The names and icons come from the programs' own title bars.

## The windows that the menu lists, in order.
@export var programs: Array[PackedScene] = []
## The window that Shut Down... opens.
@export var shut_down: PackedScene
@export var shut_down_icon: Texture2D

@onready var _button: Button = get_parent()


func _ready() -> void:
	for program in programs:
		add_icon_item(Win95Desktop.window_icon(program), Win95Desktop.window_title(program))
	if shut_down:
		add_separator()
		add_icon_item(shut_down_icon, "Shut Down...", programs.size())
	_button.toggled.connect(func(on: bool) -> void:
		if on:
			var corner := Vector2i(_button.get_global_rect().position) - Vector2i(0, int(get_contents_minimum_size().y))
			popup(Rect2i(corner, Vector2i.ZERO))
		else:
			hide())
	popup_hide.connect(func() -> void: _button.set_pressed_no_signal(false))
	id_pressed.connect(_on_id_pressed)


func _on_id_pressed(id: int) -> void:
	var desktop := get_tree().get_first_node_in_group(Win95Desktop.GROUP) as Win95Desktop
	if desktop == null:
		push_error("Start menu: no Win95Desktop in the tree")
		return
	desktop.open(shut_down if id == programs.size() else programs[id])
