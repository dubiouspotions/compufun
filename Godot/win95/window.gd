extends PanelContainer
## A Win95 window frame. Dragging the title bar draws Win95's inverted outline, and the window jumps
## to the outline when the player releases the mouse button. A resizable window resizes the same
## way by its frame's edges and corners or a SizeGrip, and its Maximize button or a double-click on
## its title bar fills the desktop above the taskbar.
## Expects a title_bar.tscn instance with the unique name TitleBar.

## The window hid itself because the player closed it.
signal closed
## The window hid itself because the player minimized it. Show it again to restore it.
signal minimized
## The player pressed a mouse button inside the window. The window manager decides what becomes active.
signal activated

const _OUTLINE_SHADER := preload("res://win95/drag_outline.gdshader")
const _OUTLINE_Z := 100
## How far into the frame an edge takes a press, and how far along an edge a corner reaches.
const _EDGE := 4.0
const _CORNER := 16.0
enum { _LEFT = 1, _TOP = 2, _RIGHT = 4, _BOTTOM = 8 }

## The player can resize it by its frame and maximize it. Dialogs keep their size, as in Win95.
@export var resizable := false

## True while the window is minimized: hidden, but still open, with its taskbar button.
var is_minimized := false

## True while it fills the desktop above the taskbar.
var is_maximized := false

var _outline: ColorRect
var _drag_offset := Vector2.ZERO
var _resizing := 0  # the edges that the drag moves
var _resize_from := Rect2()
var _resize_mouse := Vector2.ZERO
var _restored := Rect2()


func _ready() -> void:
	var title_bar: Node = %TitleBar
	title_bar.drag_moved.connect(_on_drag_moved)
	title_bar.drag_ended.connect(_on_drag_ended)
	title_bar.close_pressed.connect(request_close)
	title_bar.minimize_pressed.connect(minimize)
	title_bar.maximize_pressed.connect(toggle_maximized)
	title_bar.double_clicked.connect(toggle_maximized)
	var material := ShaderMaterial.new()
	material.shader = _OUTLINE_SHADER
	_outline = ColorRect.new()
	_outline.material = material
	_outline.top_level = true
	_outline.z_index = _OUTLINE_Z
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.visible = false
	add_child(_outline, false, Node.INTERNAL_MODE_BACK)


# _input sees the press before any button inside the window consumes it.
func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or not is_visible_in_tree():
		return
	if get_global_rect().has_point(button.position) and not _covered_at(button.position):
		activated.emit()


## The player asked to close the window, with its X or a Close menu item. A window with unsaved
## work overrides this to ask first.
func request_close() -> void:
	close()


## Hides the window and emits closed, without asking.
func close() -> void:
	is_minimized = false
	hide()
	closed.emit()


## Hides the window and emits minimized; restore() shows it again.
func minimize() -> void:
	is_minimized = true
	hide()
	minimized.emit()


## Shows a minimized or closed window again.
func restore() -> void:
	is_minimized = false
	show()


# Siblings later in the tree draw on top, so they get the press instead.
func _covered_at(point: Vector2) -> bool:
	var parent := get_parent()
	for i in range(get_index() + 1, parent.get_child_count()):
		var other := parent.get_child(i) as Control
		if other and other.visible and other.get_global_rect().has_point(point):
			return true
	return false


## Fills the desktop above the taskbar, or goes back to where it was. Does nothing unless resizable.
func toggle_maximized() -> void:
	var desktop := get_parent() as Control
	if not resizable or desktop == null:
		return
	if is_maximized:
		position = _restored.position
		size = _restored.size
	else:
		_restored = Rect2(position, size)
		# The frame goes just off the screen, as Win95 hides a maximized window's border.
		var frame := get_theme_stylebox(&"panel").get_margin(SIDE_LEFT)
		var taskbar: float = desktop.get(&"taskbar_height") if desktop.get(&"taskbar_height") != null else 0.0
		position = Vector2(-frame, -frame)
		size = Vector2(desktop.size.x, desktop.size.y - taskbar) + Vector2(frame, frame) * 2.0
	is_maximized = not is_maximized
	%TitleBar.set(&"maximized", is_maximized)
	for grip in find_children("*", "SizeGrip", true, false):
		(grip as Control).visible = not is_maximized


## Starts resizing at [param edges] (a mask of the left, top, right and bottom edges) from the
## mouse at [param at], in canvas coordinates, as a press on the frame or a SizeGrip does.
func begin_resize(edges: int, at: Vector2) -> void:
	if not resizable or is_maximized or edges == 0:
		return
	_resizing = edges
	_resize_from = get_global_rect()
	_resize_mouse = at
	resize_to(at)


## Moves the outline of the resize that begin_resize started to the mouse at [param at].
func resize_to(at: Vector2) -> void:
	if _resizing == 0:
		return
	var delta := at - _resize_mouse
	var rect := _resize_from
	var least := get_combined_minimum_size()
	if _resizing & _LEFT:
		rect.position.x = minf(rect.position.x + delta.x, rect.end.x - least.x)
		rect.size.x = _resize_from.end.x - rect.position.x
	if _resizing & _RIGHT:
		rect.size.x = maxf(rect.size.x + delta.x, least.x)
	if _resizing & _TOP:
		rect.position.y = minf(rect.position.y + delta.y, rect.end.y - least.y)
		rect.size.y = _resize_from.end.y - rect.position.y
	if _resizing & _BOTTOM:
		rect.size.y = maxf(rect.size.y + delta.y, least.y)
	_show_outline(Rect2(rect.position.round(), rect.size.round()))


## Ends the resize: the window takes the outline's place and size.
func end_resize() -> void:
	if _resizing == 0:
		return
	_resizing = 0
	global_position = _outline.global_position
	size = _outline.size
	_outline.hide()


func _gui_input(event: InputEvent) -> void:
	if not resizable or is_maximized:
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	var at := get_global_transform_with_canvas() * mouse.position
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			begin_resize(_edges_at(mouse.position), at)
		else:
			end_resize()
		accept_event()
	elif _resizing != 0:
		resize_to(at)
		accept_event()
	else:
		mouse_default_cursor_shape = _cursor_for(_edges_at(mouse.position))


# The frame's edges that [param point], in the window's own coordinates, is on.
func _edges_at(point: Vector2) -> int:
	var edges := 0
	var near_left := point.x < _CORNER
	var near_right := point.x > size.x - _CORNER
	var near_top := point.y < _CORNER
	var near_bottom := point.y > size.y - _CORNER
	if point.x < _EDGE or (near_left and (point.y < _EDGE or point.y > size.y - _EDGE)):
		edges |= _LEFT
	if point.x > size.x - _EDGE or (near_right and (point.y < _EDGE or point.y > size.y - _EDGE)):
		edges |= _RIGHT
	if point.y < _EDGE or (near_top and (point.x < _EDGE or point.x > size.x - _EDGE)):
		edges |= _TOP
	if point.y > size.y - _EDGE or (near_bottom and (point.x < _EDGE or point.x > size.x - _EDGE)):
		edges |= _BOTTOM
	return edges


static func _cursor_for(edges: int) -> Control.CursorShape:
	if edges == _LEFT or edges == _RIGHT:
		return Control.CURSOR_HSIZE
	if edges == _TOP or edges == _BOTTOM:
		return Control.CURSOR_VSIZE
	if edges == _LEFT | _TOP or edges == _RIGHT | _BOTTOM:
		return Control.CURSOR_FDIAGSIZE
	if edges == _RIGHT | _TOP or edges == _LEFT | _BOTTOM:
		return Control.CURSOR_BDIAGSIZE
	return Control.CURSOR_ARROW


func _show_outline(rect: Rect2) -> void:
	_outline.global_position = rect.position
	_outline.size = rect.size
	(_outline.material as ShaderMaterial).set_shader_parameter("size", rect.size)
	_outline.show()


func _on_drag_moved(relative: Vector2) -> void:
	if is_maximized:
		return
	_drag_offset += relative
	_show_outline(Rect2((global_position + _drag_offset).round(), size))


func _on_drag_ended() -> void:
	if not _outline.visible:
		return
	position = (position + _drag_offset).round()
	_drag_offset = Vector2.ZERO
	_outline.hide()
