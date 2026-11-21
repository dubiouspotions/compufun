@tool
class_name FileIcon
extends VBoxContainer
## A 32 px icon with its name below, as on the desktop and in folder windows.

## The player clicked the icon once.
signal clicked
## The player double-clicked the icon.
signal opened

const _WRAP_WIDTH := 70.0

static var _selected_material: ShaderMaterial

@export var text := "":
	set(value):
		text = value
		_sync()
## A 32 x 32 texture.
@export var icon: Texture2D:
	set(value):
		icon = value
		_sync()
## White names for the desktop, black names for folder windows.
@export var on_desktop := false:
	set(value):
		on_desktop = value
		_sync()
## The window that a double-click opens on the desktop (Win95Desktop.open); null opens nothing.
@export var opens: PackedScene
## Draws the icon and its name in the selection colour.
@export var selected := false:
	set(value):
		selected = value
		_sync()


func _ready() -> void:
	_sync()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if button.double_click:
			opened.emit()
		else:
			clicked.emit()


func _sync() -> void:
	if not is_node_ready():
		return
	var icon_rect: TextureRect = %Icon
	icon_rect.texture = icon
	icon_rect.material = _selection_material() if selected else null
	var label: Label = %Name
	label.text = text
	if selected:
		label.theme_type_variation = &"IconLabelSelected"
	else:
		label.theme_type_variation = &"DesktopIconLabel" if on_desktop else &"IconLabel"
	# The name box hugs the wrapped text, as Win95 draws the selection behind the name only.
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var block := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, _WRAP_WIDTH, size)
	var box := label.get_theme_stylebox("normal")
	label.custom_minimum_size.x = ceilf(block.x) + box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT)


static func _selection_material() -> ShaderMaterial:
	if _selected_material == null:
		_selected_material = ShaderMaterial.new()
		_selected_material.shader = preload("res://win95/icon_selected.gdshader")
	return _selected_material
