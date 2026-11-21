class_name IconView
extends FlowContainer
## A grid of FileIcons that the player selects as in Win95: click one, Ctrl-click (Cmd on a Mac)
## to toggle one, Shift-click for a range, or drag a rectangle from empty space; Ctrl-drag toggles.
## Use a VFlowContainer for the desktop (column by column) and an HFlowContainer for folder windows
## (row by row). Right-click asks for a context menu, also after a rectangle dragged with the right
## button; Delete, F2, Enter and Shift+F10 work as in Win95. As in Win95, the selection and the
## focus rectangle show only while the view's window, or for the desktop's view the desktop, is active.

## The player double-clicked an icon.
signal item_opened(item: FileIcon)
## Icons were added or removed.
signal items_changed
## The player right-clicked [param item], or empty space when it is null, at [param at] in canvas
## coordinates; or pressed Shift+F10. A right-click on an unselected icon selects it first.
signal context_requested(item: FileIcon, at: Vector2)
## The player pressed Delete with [param items] selected.
signal delete_requested(items: Array[FileIcon])

const _FILE_ICON := preload("res://win95/file_icon.tscn")
const _BAND_SHADER := preload("res://win95/drag_outline.gdshader")

## Draws the names white, for icons on the desktop wallpaper.
@export var on_desktop := false

## The icon that Shift-click ranges from and that has the focus rectangle: the last one clicked
## without Shift.
var _anchor: FileIcon
var _active := true
var _desktop: Win95Desktop
## The window that holds this view, or null for the desktop's own icons.
var _window: Control
var _band: ColorRect
var _band_start := Vector2.ZERO
var _banding := false
var _band_button := MOUSE_BUTTON_NONE
## The selection when a Ctrl-drag started; the rectangle toggles icons against it.
var _before_band: Array[FileIcon] = []


func _ready() -> void:
	for child in get_children():
		_wire(child)
	child_entered_tree.connect(func(child: Node) -> void:
		if child.is_node_ready():
			return  # the whole desktop re-entered the tree; its icons are wired
		_wire(child)
		items_changed.emit())
	child_exiting_tree.connect(func(_child: Node) -> void: items_changed.emit.call_deferred())
	items_changed.connect(_sync_focus)
	var material := ShaderMaterial.new()
	material.shader = _BAND_SHADER
	material.set_shader_parameter("thickness", 1.0)
	_band = ColorRect.new()
	_band.material = material
	_band.top_level = true
	_band.z_index = 100
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.visible = false
	add_child(_band, false, Node.INTERNAL_MODE_BACK)
	focus_mode = Control.FOCUS_ALL
	_find_desktop()
	_sync_focus()


func _find_desktop() -> void:
	var node: Node = self
	while node != null and not node is Win95Desktop:
		if node.has_signal(&"activated"):
			_window = node as Control
		node = node.get_parent()
	_desktop = node as Win95Desktop
	if _desktop != null:
		_desktop.windows_changed.connect(_sync_active)
		_sync_active()


func _sync_active() -> void:
	var active := _desktop.active_window() == _window
	if active != _active:
		_active = active
		_sync_focus()


# The anchor has the focus rectangle; with no anchor, the first icon, as in a folder just opened.
func _sync_focus() -> void:
	var items := _items()
	var focus: FileIcon = _anchor if is_instance_valid(_anchor) and items.has(_anchor) else items.front() if not items.is_empty() else null
	for item in items:
		item.active = _active
		item.focused = item == focus


## Adds an icon at the end of the grid and returns it.
func add_item(text: String, icon: Texture2D) -> FileIcon:
	var item: FileIcon = _FILE_ICON.instantiate()
	item.text = text
	item.icon = icon
	add_child(item)
	return item


## Removes every icon.
func clear() -> void:
	for child in get_children():
		child.queue_free()


## The number of icons, not counting ones that are being removed.
func item_count() -> int:
	return _items().size()


## The selected icons, in grid order.
func selected_items() -> Array[FileIcon]:
	var selected: Array[FileIcon] = []
	for item in _items():
		if item.selected:
			selected.append(item)
	return selected


## Opens [param item] as a double-click does.
func open_item(item: FileIcon) -> void:
	if item.opens:
		_open_window(item)
	item_opened.emit(item)


func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		_key(key)
		return
	var button := event as InputEventMouseButton
	if button and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		if button.pressed and not _banding:
			grab_focus()
			var additive := button.ctrl_pressed or button.meta_pressed
			_before_band = selected_items()
			if not additive:
				_before_band.clear()
				_select(null)
			_band_start = button.global_position
			_banding = true
			_band_button = button.button_index
		elif not button.pressed and _banding and button.button_index == _band_button:
			_banding = false
			_band.hide()
			if button.button_index == MOUSE_BUTTON_RIGHT:  # on release, like FileIcon
				var selected := selected_items()
				context_requested.emit(selected[0] if not selected.is_empty() else null, button.global_position)
		return
	var motion := event as InputEventMouseMotion
	if motion and _banding:
		var rect := Rect2(_band_start, Vector2.ZERO).expand(motion.global_position).intersection(_visible_rect())
		_band.global_position = rect.position
		_band.size = rect.size
		(_band.material as ShaderMaterial).set_shader_parameter("size", rect.size)
		_band.visible = rect.has_area()
		for item in _items():
			item.selected = _before_band.has(item) != rect.intersects(item.hit_rect())


func _wire(child: Node) -> void:
	var item := child as FileIcon
	if item == null:
		return
	item.on_desktop = on_desktop
	item.clicked.connect(_on_clicked.bind(item))
	item.opened.connect(func() -> void:
		_select(item)
		open_item(item))
	item.context_clicked.connect(func(at: Vector2) -> void:
		grab_focus()
		if not item.selected:
			_select(item)
		context_requested.emit(item, at))


func _key(key: InputEventKey) -> void:
	var selected := selected_items()
	match key.keycode:
		KEY_DELETE:
			if not selected.is_empty():
				delete_requested.emit(selected)
		KEY_A:
			if not (key.ctrl_pressed or key.meta_pressed):
				return
			select_all()
		KEY_F2:
			if selected.size() == 1 and selected[0].renamable:
				selected[0].start_rename()
		KEY_ENTER, KEY_KP_ENTER:
			for item in selected:
				open_item(item)
		KEY_F10, KEY_MENU:
			if key.keycode == KEY_F10 and not key.shift_pressed:
				return
			var item: FileIcon = selected[0] if not selected.is_empty() else null
			var at := item.hit_rect().get_center() if item else get_global_rect().position
			context_requested.emit(item, at)
		_:
			return
	accept_event()


func _on_clicked(additive: bool, extend: bool, on_name: bool, item: FileIcon) -> void:
	grab_focus()
	if additive:
		item.selected = not item.selected
		_anchor = item
		_sync_focus()
	elif extend and is_instance_valid(_anchor):
		var items := _items()
		var from := items.find(_anchor)
		var to := items.find(item)
		for i in items.size():
			items[i].selected = i >= mini(from, to) and i <= maxi(from, to)
	elif on_name and item.selected and item.renamable and selected_items().size() == 1:
		item.start_rename()
	else:
		_select(item)


## The icon with the focus rectangle, or null when the view is empty.
func focus_item() -> FileIcon:
	for item in _items():
		if item.focused:
			return item
	return null


## Moves the focus rectangle to [param item], as a click does, without selecting it.
func set_focus_item(item: FileIcon) -> void:
	_anchor = item
	_sync_focus()


## Selects every icon, as Edit > Select All and Ctrl+A do.
func select_all() -> void:
	for item in _items():
		item.selected = true


## Selects only [param item], or nothing when it is null.
func select_only(item: FileIcon) -> void:
	_select(item)


func _select(item: FileIcon) -> void:
	for other in _items():
		other.selected = other == item
	if item != null:
		_anchor = item
	_sync_focus()


func _items() -> Array[FileIcon]:
	var items: Array[FileIcon] = []
	for child in get_children():
		var item := child as FileIcon
		if item and not item.is_queued_for_deletion():
			items.append(item)
	return items


# In a folder window the scroll area clips the view, so the rectangle stops at its edge.
func _visible_rect() -> Rect2:
	var scroll := get_parent() as ScrollContainer
	return scroll.get_global_rect() if scroll else get_global_rect()


func _open_window(item: FileIcon) -> void:
	var desktop := get_tree().get_first_node_in_group(Win95Desktop.GROUP) as Win95Desktop
	if desktop == null:
		push_error("IconView: no Win95Desktop in the tree to open %s from %s" % [item.opens.resource_path, item.text])
		return
	desktop.open(item.opens)
