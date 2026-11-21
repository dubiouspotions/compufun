class_name Win95Desktop
extends Control
## The desktop that windows open on. Later children draw on top, so the active window is the last.

## The group of the desktop, for icons in any window to find it.
const GROUP: StringName = &"win95_desktop"
## Where the first window opens, and the step between windows, as Win95 cascades them.
@export var cascade_start := Vector2(80, 60)
@export var cascade_step := Vector2(24, 24)
## The height of the taskbar at the bottom; a new window opens above it.
@export var taskbar_height := 28.0

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
	# Late cascade steps would otherwise run off the screen.
	var room := size - Vector2(0, taskbar_height) - window.get_combined_minimum_size()
	window.position = window.position.min(room).max(Vector2.ZERO)
	_wire(window)
	return window


## Closes every open window, as a restart does.
func close_all() -> void:
	for child in get_children():
		if child.has_signal(&"activated") and child.visible:
			child.close()


## Covers the whole Win95 screen, taskbar too, with [param scene] (a shut-down or crash screen)
## and returns it.
func cover(scene: PackedScene) -> Control:
	var screen := scene.instantiate() as Control
	assert(screen != null, "Win95Desktop: %s is not a Control" % scene.resource_path)
	get_parent().add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screen


## The title on the title bar of the window [param scene], without making the window.
static func window_title(scene: PackedScene) -> String:
	return String(_title_bar_property(scene, &"title", scene.resource_path.get_file().get_basename()))


## The icon on the title bar of the window [param scene], or null.
static func window_icon(scene: PackedScene) -> Texture2D:
	return _title_bar_property(scene, &"icon", null) as Texture2D


static func _title_bar_property(scene: PackedScene, property: StringName, fallback: Variant) -> Variant:
	var state := scene.get_state()
	for node in state.get_node_count():
		if state.get_node_name(node) != &"TitleBar":
			continue
		for i in state.get_node_property_count(node):
			if state.get_node_property_name(node, i) == property:
				return state.get_node_property_value(node, i)
	return fallback


func _wire(window: Control) -> void:
	window.activated.connect(func() -> void: move_child(window, -1))
