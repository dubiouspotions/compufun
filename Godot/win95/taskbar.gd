extends PanelContainer
## The taskbar's task buttons: one per open window, minimized ones too, pressed for the active
## window. A click brings the window to the front, or minimizes it when it is already in front.

const _TASK_BUTTON := preload("res://win95/task_button.tscn")
## Win95's widest task button; they share the room equally when it runs out.
const _MAX_WIDTH := 160.0

@export var desktop: Win95Desktop

## Each window's button, by the window's instance ID: a closed folder window frees itself, and a
## freed object can't be a key.
var _buttons: Dictionary[int, Button] = {}
var _sync_queued := false

@onready var _row: HBoxContainer = %TaskButtons


func _ready() -> void:
	if desktop == null:
		push_error("Taskbar: desktop is not set, so there are no task buttons")
		return
	desktop.windows_changed.connect(_queue_sync)
	(_row.get_parent() as Control).resized.connect(_queue_sync)
	_sync()


func _queue_sync() -> void:
	if not _sync_queued:
		_sync_queued = true
		_sync.call_deferred()


func _sync() -> void:
	_sync_queued = false
	var open := desktop.windows()
	for id: int in _buttons.keys():
		if not is_instance_id_valid(id) or not open.has(instance_from_id(id)):
			_buttons[id].queue_free()
			_buttons.erase(id)
	var active := desktop.active_window()
	var width := _MAX_WIDTH
	if not open.is_empty():
		var gap := _row.get_theme_constant(&"separation")
		width = minf(_MAX_WIDTH, floorf((_room() - gap * (open.size() - 1)) / open.size()))
	for window in open:
		var button: Button = _buttons.get(window.get_instance_id())
		if button == null:
			button = _TASK_BUTTON.instantiate()
			button.clip_text = true
			button.pressed.connect(_on_pressed.bind(window))
			_row.add_child(button)
			_buttons[window.get_instance_id()] = button
			var bar := window.get_node_or_null(^"%TitleBar")
			if bar != null and not bar.appearance_changed.is_connected(_queue_sync):  # a reused window comes back
				bar.appearance_changed.connect(_queue_sync)
		var title_bar := window.get_node_or_null(^"%TitleBar")
		button.text = title_bar.title if title_bar != null else window.name
		button.icon = title_bar.icon if title_bar != null else null
		button.custom_minimum_size.x = width
		button.button_pressed = window == active


# The taskbar and its row grow with their buttons, so start from the screen's width, which doesn't.
func _room() -> float:
	var bar := _row.get_parent() as BoxContainer
	var width := get_parent_control().size.x - offset_left + offset_right - get_theme_stylebox(&"panel").get_minimum_size().x
	var room := width - bar.get_theme_constant(&"separation") * (bar.get_child_count() - 1)
	for other in bar.get_children():
		if other != _row and other is Control and (other as Control).visible:
			room -= (other as Control).get_combined_minimum_size().x
	return room


func _on_pressed(window: Control) -> void:
	if window == desktop.active_window():
		window.call(&"minimize")
	else:
		desktop.activate(window)
