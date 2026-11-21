@tool
extends PanelContainer
## The caption of a Win95 window: an optional 16 px icon, the title and the caption buttons.

signal close_pressed
signal minimize_pressed
signal maximize_pressed
## The player dragged the title bar with the left button by `relative` pixels.
signal drag_moved(relative: Vector2)

@export var title := "":
	set(value):
		title = value
		_sync()
## Shown left of the title; null hides it, as on dialogs.
@export var icon: Texture2D:
	set(value):
		icon = value
		_sync()
## False draws the gray caption of a window that doesn't have focus.
@export var active := true:
	set(value):
		active = value
		_sync()
@export var show_minimize := false:
	set(value):
		show_minimize = value
		_sync()
@export var show_maximize := false:
	set(value):
		show_maximize = value
		_sync()


func _ready() -> void:
	%Close.pressed.connect(close_pressed.emit)
	%Minimize.pressed.connect(minimize_pressed.emit)
	%Maximize.pressed.connect(maximize_pressed.emit)
	_sync()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		drag_moved.emit(motion.relative)


func _sync() -> void:
	if not is_node_ready():
		return
	theme_type_variation = &"TitleBar" if active else &"TitleBarInactive"
	var label: Label = %Title
	label.text = title
	label.theme_type_variation = &"TitleLabel" if active else &"TitleLabelInactive"
	var icon_rect: TextureRect = %Icon
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	%Minimize.visible = show_minimize
	%Maximize.visible = show_maximize
	%CloseGap.visible = show_minimize or show_maximize
