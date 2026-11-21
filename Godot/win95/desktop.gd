class_name Win95Desktop
extends Control
## The desktop that windows open on. Later children draw on top, so the active window is the last.

## The group of the desktop, for icons in any window to find it.
const GROUP: StringName = &"win95_desktop"
## Where the first window opens, and the step between windows, as Win95 cascades them.
@export var cascade_start := Vector2(80, 60)
@export var cascade_step := Vector2(24, 24)

var _opened: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for child in get_children():
		if child.has_signal(&"activated"):
			_wire(child)


## Shows the window made from [param scene] in front: the one already on the desktop, else a new
## one at the next cascade position. Returns it.
func open(scene: PackedScene) -> Control:
	for child in get_children():
		if child.scene_file_path == scene.resource_path:
			child.show()
			move_child(child, -1)
			return child
	var window := scene.instantiate() as Control
	assert(window != null and window.has_signal(&"activated"), "Win95Desktop: %s is not a window" % scene.resource_path)
	window.position = cascade_start + cascade_step * (_opened % 8)
	_opened += 1
	add_child(window)
	_wire(window)
	return window


func _wire(window: Control) -> void:
	window.activated.connect(func() -> void: move_child(window, -1))
