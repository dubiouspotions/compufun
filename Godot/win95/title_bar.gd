@tool
extends PanelContainer
## The caption of a Win95 window: an optional 16 px icon, the title and the caption buttons.

signal close_pressed
signal minimize_pressed
signal maximize_pressed
## The player double-clicked the title bar outside the icon, which maximizes or restores a resizable window.
signal double_clicked
## The player pressed the left button on the icon, which opens the window's control menu.
signal icon_pressed
## The player dragged the title bar with the left button by `relative` pixels.
signal drag_moved(relative: Vector2)
## The player released the left button after pressing it on the title bar.
signal drag_ended
## The title, the icon or the active state changed.
signal appearance_changed

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
## Shows the "?" button left of the close button, as on property sheets. Pressing it does nothing.
@export var show_help := false:
	set(value):
		show_help = value
		_sync()


const _RESTORE_GLYPH := preload("res://win95/theme/caption_restore.png")

## The window is maximized: the Maximize button shows the Restore glyph.
var maximized := false:
	set(value):
		maximized = value
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
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		if is_on_icon(get_global_transform() * button.position):
			icon_pressed.emit()
		elif button.double_click:
			double_clicked.emit()
	if button and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		drag_ended.emit()


## True when [param point], in canvas coordinates, is on the shown icon.
func is_on_icon(point: Vector2) -> bool:
	var icon_rect: TextureRect = %Icon
	return icon_rect.is_visible_in_tree() and icon_rect.get_global_rect().has_point(point)


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
	if maximized:
		%Maximize.add_theme_icon_override(&"icon", _RESTORE_GLYPH)
	else:
		%Maximize.remove_theme_icon_override(&"icon")
	%Help.visible = show_help
	%CloseGap.visible = show_minimize or show_maximize or show_help
	appearance_changed.emit()
