@tool
class_name FileIcon
extends VBoxContainer
## A 32 px icon with its name below, as on the desktop and in folder windows.

## The player clicked the icon once.
signal clicked
## The player double-clicked the icon.
signal opened
## The player renamed the icon; text is already new_text.
signal name_edited(old_text: String, new_text: String)

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
## A click on the name of the selected icon edits the name, as in Win95.
@export var renamable := true
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
		if selected and renamable and not button.double_click and %Name.get_global_rect().has_point(button.global_position):
			start_rename()
		elif button.double_click:
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


## Replaces the name with a text field. Enter or leaving the field keeps the new name; Esc cancels.
func start_rename() -> void:
	var label: Label = %Name
	if not label.visible:
		return
	var field := LineEdit.new()
	field.text = text
	field.custom_minimum_size.x = maxf(label.size.x, 70.0)
	field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_sibling(field)
	label.hide()
	field.grab_focus()
	field.select_all()
	var finish := func(keep: bool) -> void:
		if not is_instance_valid(field) or field.is_queued_for_deletion():
			return
		var old_text := text
		var new_text := field.text.strip_edges()
		field.queue_free()
		label.show()
		if keep and new_text != "" and new_text != old_text:
			text = new_text
			name_edited.emit(old_text, new_text)
	field.text_submitted.connect(func(_t: String) -> void: finish.call(true))
	field.focus_exited.connect(func() -> void: finish.call(true))
	field.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"):
			field.accept_event()
			finish.call(false))
