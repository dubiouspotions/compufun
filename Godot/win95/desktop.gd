class_name Win95Desktop
extends Control
## The desktop that windows open on. Later children draw on top, so the active window is the last
## visible one, until the player clicks the desktop itself, which makes no window active. It marks
## the active window's title bar active and the others' inactive.

## A window opened, closed, minimized, came back, or became active. The taskbar re-reads windows().
signal windows_changed

## The group of the desktop, for icons in any window to find it.
const GROUP: StringName = &"win95_desktop"
## Where the first window opens, and the step between windows, as Win95 cascades them.
@export var cascade_start := Vector2(80, 60)
@export var cascade_step := Vector2(24, 24)
## The height of the taskbar at the bottom; a new window opens above it.
@export var taskbar_height := 28.0

## The computer whose desktop this is. Windows read and change it through this; its Win95 screen
## sets it before any window opens.
var computer: ComputerState

var _opened: int = 0
## The player clicked the desktop outside every window; the next window that activates ends it.
var _desktop_active := false


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for child in get_children():
		if child.has_signal(&"activated"):
			_wire(child)


## Shows the window made from [param scene] in front, and returns it. With [param reuse], a window
## from that scene that is already on the desktop comes back; otherwise, and for folder windows,
## a new one opens at the next cascade position.
func open(scene: PackedScene, reuse := true) -> Control:
	if reuse:
		for child in get_children():
			if child.scene_file_path == scene.resource_path:
				activate(child)
				return child
	var window := scene.instantiate() as Control
	assert(window != null and window.has_signal(&"activated"), "Win95Desktop: %s is not a window" % scene.resource_path)
	window.position = cascade_start + cascade_step * (_opened % 8)
	_opened += 1
	add_child(window)
	# Late cascade steps would otherwise run off the screen.
	var room := size - Vector2(0, taskbar_height) - window.get_combined_minimum_size()
	window.position = window.position.min(room).max(Vector2.ZERO)
	_lay_out(window)
	_wire(window)
	_desktop_active = false
	_changed()
	return window


# Containers sort their children at the end of the frame; sorting now, top down, gives the new
# window's controls their sizes before the caller fills them. A TextEdit still 8 px wide errors on
# multi-line text.
static func _lay_out(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_lay_out(child)


## Shows [param window], restoring it if it was minimized, and puts it in front.
func activate(window: Control) -> void:
	if not window.visible:
		window.call(&"restore")
	move_child(window, -1)
	_desktop_active = false
	_changed()


## The open windows, minimized ones too, in the order of the desktop's children.
func windows() -> Array[Control]:
	var open: Array[Control] = []
	for child in get_children():
		if child.has_signal(&"activated") and not child.is_queued_for_deletion() and (child.visible or child.get(&"is_minimized")):
			open.append(child)
	return open


## The window in front, or null when the desktop itself is active: the player clicked it, or every
## window is closed or minimized.
func active_window() -> Control:
	if _desktop_active:
		return null
	for i in range(get_child_count() - 1, -1, -1):
		var child := get_child(i)
		if child.has_signal(&"activated") and child.visible and not child.is_queued_for_deletion():
			return child
	return null


# _input sees the press before an icon or the wallpaper consumes it; presses on embedded popups
# never reach it.
func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or _desktop_active or not is_visible_in_tree():
		return
	var desk := get_global_rect()
	desk.size.y -= taskbar_height
	if not desk.has_point(button.position):
		return
	for window in windows():
		if window.visible and window.get_global_rect().has_point(button.position):
			return
	_desktop_active = true
	_changed()


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
	window.activated.connect(func() -> void:
		if active_window() != window:
			activate(window))
	window.visibility_changed.connect(_changed)
	window.tree_exited.connect(_changed)


func _changed() -> void:
	if not is_inside_tree():
		return
	var active := active_window()
	for window in windows():
		var title_bar := window.get_node_or_null(^"%TitleBar")
		if title_bar != null:
			title_bar.active = window == active
	windows_changed.emit()
