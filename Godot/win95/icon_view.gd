class_name IconView
extends FlowContainer
## A grid of FileIcons that the player selects by clicking. Use a VFlowContainer for the desktop
## (column by column) and an HFlowContainer for folder windows (row by row).

## The player double-clicked an icon.
signal item_opened(item: FileIcon)
## Icons were added or removed.
signal items_changed

const _FILE_ICON := preload("res://win95/file_icon.tscn")

## Draws the names white, for icons on the desktop wallpaper.
@export var on_desktop := false


func _ready() -> void:
	for child in get_children():
		_wire(child)
	child_entered_tree.connect(func(child: Node) -> void:
		_wire(child)
		items_changed.emit())
	child_exiting_tree.connect(func(_child: Node) -> void: items_changed.emit.call_deferred())


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
	return get_children().filter(func(c: Node) -> bool: return c is FileIcon and not c.is_queued_for_deletion()).size()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_select(null)


func _wire(child: Node) -> void:
	var item := child as FileIcon
	if item == null:
		return
	item.on_desktop = on_desktop
	item.clicked.connect(_select.bind(item))
	item.opened.connect(func() -> void:
		_select(item)
		item_opened.emit(item))


func _select(item: FileIcon) -> void:
	for child in get_children():
		var other := child as FileIcon
		if other:
			other.selected = other == item
