class_name TouchControls
extends CanvasLayer
## The controls that touch screens get: the trackpad and the keyboard for the Screen View and
## CompuFunDB, and in debug builds the debug strip. They show while the player's last pointer input
## was a finger, and hide at the first real mouse event (docs/ios.md).

## Emitted when [member touch_mode] changes.
signal touch_mode_changed(on: bool)

## Window pixels kept free between the focused text (the caret line in a TextEdit) and the top of
## the OS keyboard.
@export var keyboard_margin: float = 24.0

## True while the last pointer input was a finger. Starts true on a device without a mouse.
var touch_mode: bool = false:
	set(value):
		if value == touch_mode:
			return
		touch_mode = value
		touch_mode_changed.emit(value)

var _lifted: CanvasLayer
var _lifted_from: Vector2


func _process(_delta: float) -> void:
	_lift_above_keyboard()


# Moves the layer of the focused text field up by as much as the OS keyboard covers of it (F9's
# note, the Story Lab's editors), and back down once the keyboard or the focus goes.
func _lift_above_keyboard() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var lifting := _layer_of(focus) if focus is LineEdit or focus is TextEdit else null
	if lifting != _lifted:
		if _lifted != null and is_instance_valid(_lifted):
			_lifted.offset = _lifted_from
		_lifted = lifting
		if lifting != null:
			_lifted_from = lifting.offset
	if lifting == null:
		return
	var lift := 0.0
	var keyboard := DisplayServer.virtual_keyboard_get_height()
	if keyboard > 0:
		var stretch := _scale(focus)
		var bottom := focus.size.y
		if focus is TextEdit:
			var text := focus as TextEdit
			bottom = minf(text.get_caret_draw_pos().y + text.get_line_height() * 0.5, bottom)
		var unlifted := (focus.get_screen_transform() * Vector2(0.0, bottom)).y + (_lifted_from.y - lifting.offset.y) * stretch
		var keyboard_top := float(DisplayServer.window_get_size().y - keyboard)
		lift = maxf(0.0, unlifted + keyboard_margin - keyboard_top) / stretch
	lifting.offset = _lifted_from - Vector2(0.0, lift)


# Window pixels per layer unit: the window's stretch.
static func _scale(control: Control) -> float:
	return control.get_screen_transform().get_scale().y / control.get_global_transform().get_scale().y


static func _layer_of(node: Node) -> CanvasLayer:
	while node != null and not node is CanvasLayer:
		node = node.get_parent()
	return node as CanvasLayer


func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() and not OS.has_feature("pc")


func _input(event: InputEvent) -> void:
	if TouchInput.is_pointer(event):
		touch_mode = TouchInput.is_touch(event)
