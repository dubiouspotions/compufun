class_name IconView
extends FlowContainer
## A grid of FileIcons that the player selects as in Win95: click one, Ctrl-click (Cmd on a Mac)
## to toggle one, Shift-click for a range, or drag a rectangle from empty space; Ctrl-drag toggles.
## Use a VFlowContainer for the desktop (column by column) and an HFlowContainer for folder windows
## (row by row).

## The player double-clicked an icon.
signal item_opened(item: FileIcon)
## Icons were added or removed.
signal items_changed

const _FILE_ICON := preload("res://win95/file_icon.tscn")
const _BAND_SHADER := preload("res://win95/drag_outline.gdshader")

## Draws the names white, for icons on the desktop wallpaper.
@export var on_desktop := false

## The icon that Shift-click ranges from: the last one clicked without Shift.
var _anchor: FileIcon
var _band: ColorRect
var _band_start := Vector2.ZERO
var _banding := false
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


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			var additive := button.ctrl_pressed or button.meta_pressed
			_before_band = selected_items()
			if not additive:
				_before_band.clear()
				_select(null)
			_band_start = button.global_position
			_banding = true
		elif _banding:
			_banding = false
			_band.hide()
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
		if item.opens:
			_open_window(item)
		item_opened.emit(item))


func _on_clicked(additive: bool, extend: bool, on_name: bool, item: FileIcon) -> void:
	if additive:
		item.selected = not item.selected
		_anchor = item
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


## Selects only [param item], or nothing when it is null.
func _select(item: FileIcon) -> void:
	for other in _items():
		other.selected = other == item
	if item != null:
		_anchor = item


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
