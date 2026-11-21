extends PanelContainer
## A Win95 window frame. Dragging the title bar draws Win95's inverted outline, and the window jumps
## to the outline when the player releases the mouse button.
## Expects a title_bar.tscn instance with the unique name TitleBar.

## The window hid itself because the player closed it.
signal closed
## The window hid itself because the player minimized it. Show it again to restore it.
signal minimized
## The player pressed a mouse button inside the window. The window manager decides what becomes active.
signal activated

const _OUTLINE_SHADER := preload("res://win95/drag_outline.gdshader")
const _OUTLINE_Z := 100

## True while the window is minimized: hidden, but still open, with its taskbar button.
var is_minimized := false

var _outline: ColorRect
var _drag_offset := Vector2.ZERO


func _ready() -> void:
	var title_bar: Node = %TitleBar
	title_bar.drag_moved.connect(_on_drag_moved)
	title_bar.drag_ended.connect(_on_drag_ended)
	title_bar.close_pressed.connect(request_close)
	title_bar.minimize_pressed.connect(minimize)
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


func _on_drag_moved(relative: Vector2) -> void:
	_drag_offset += relative
	_outline.global_position = (global_position + _drag_offset).round()
	_outline.size = size
	(_outline.material as ShaderMaterial).set_shader_parameter("size", size)
	_outline.show()


func _on_drag_ended() -> void:
	if not _outline.visible:
		return
	position = (position + _drag_offset).round()
	_drag_offset = Vector2.ZERO
	_outline.hide()
