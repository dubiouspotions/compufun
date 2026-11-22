extends "res://tests/test.gd"
## A click on a window's title bar icon opens the control menu, whose items work and are greyed out
## where they don't apply; a double-click on the icon closes the window instead of maximizing it.

const MOVE: int = 1
const MINIMIZE: int = 3
const MAXIMIZE: int = 4
const CLOSE: int = 6

var _window: Control
var _menu: ContextMenu


func run() -> void:
	var desktop := Control.new()
	desktop.size = Vector2(640, 480)
	root.add_child(desktop)
	_window = load("res://win95/notepad.tscn").instantiate()
	_window.position = Vector2(40, 40)
	desktop.add_child(_window)
	await process_frame
	var bar: Control = _window.get_node("%TitleBar")

	await _click(_icon())
	for child in _window.get_children(true):
		if child is ContextMenu:
			_menu = child
	check("a click on the icon opens the menu", _menu != null and _menu.visible, true)
	if _menu == null:
		return
	check("the items", _labels(), ["&Restore", "&Move", "&Size", "Mi&nimize", "Ma&ximize", "", "&Close"])
	check("greyed out on a window that isn't maximized", _disabled(), [true, true, true, false, false, false, false])
	check("Close is the default, with its key", [_menu._entries[CLOSE].is_default, _menu._entries[CLOSE].shortcut], [true, "Alt+F4"])
	check("the menu sits under the title bar", _menu.position.y, int(bar.get_global_rect().end.y))

	await _click(_row(MOVE))
	check("a greyed-out item keeps the menu open", _menu.visible, true)
	await _click(_row(MAXIMIZE))
	check("Maximize maximizes", _window.is_maximized, true)
	check("and closes the menu", _menu.visible, false)

	await _click(_icon())
	check("greyed out on a maximized window", _disabled(), [false, true, true, false, true, false, false])
	await _click(_row(0))
	check("Restore restores", _window.is_maximized, false)

	await _click(_icon())
	await _click(_row(MINIMIZE))
	check("Minimize minimizes", _window.is_minimized, true)
	_window.restore()
	await process_frame

	await _click(bar.get_global_rect().get_center())
	await _click(bar.get_global_rect().get_center(), true)
	check("a double-click on the title still maximizes", _window.is_maximized, true)
	await _click(bar.get_global_rect().get_center())
	await _click(bar.get_global_rect().get_center(), true)
	check("and restores", _window.is_maximized, false)

	var closed: Array[bool] = []
	_window.closed.connect(func() -> void: closed.append(true))
	await _click(_icon())
	await _click(_icon(), true)
	check("a double-click on the icon closes the window", [closed, _window.visible], [[true], false])
	check("without maximizing it", _window.is_maximized, false)
	check("and the menu is gone", _menu.visible, false)


func _labels() -> Array[String]:
	var labels: Array[String] = []
	for entry: ContextMenu.Entry in _menu._entries:
		labels.append(entry.label)
	return labels


func _disabled() -> Array[bool]:
	var disabled: Array[bool] = []
	for entry: ContextMenu.Entry in _menu._entries:
		disabled.append(entry.disabled)
	return disabled


func _icon() -> Vector2:
	return (_window.get_node("%TitleBar/Row/Icon") as Control).get_global_rect().get_center()


# The middle of row [param index], in root coordinates.
func _row(index: int) -> Vector2:
	return Vector2(_menu.position) + _menu._rows.position + _menu._row_rect(index).get_center()


func _click(at: Vector2, double := false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.double_click = double and pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		root.push_input(event, true)  # root coordinates, past the window's stretch
		await process_frame
