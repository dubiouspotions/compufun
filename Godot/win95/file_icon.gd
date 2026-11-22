@tool
class_name FileIcon
extends BoxContainer
## A 32 px icon with its name below, as on the desktop and in folder windows; or, [member compact],
## a 16 px icon with its name on the right, as in the Small Icons, List and Details views.

## The player clicked the icon once. [param additive]: Ctrl (Cmd on a Mac) was held;
## [param extend]: Shift was held; [param on_name]: the click hit the name, not the picture.
signal clicked(additive: bool, extend: bool, on_name: bool)
## The player double-clicked the icon.
signal opened
## The player right-clicked the icon at [param at], in canvas coordinates.
signal context_clicked(at: Vector2)
## The player renamed the icon; text is already new_text.
signal name_edited(old_text: String, new_text: String)

const _WRAP_WIDTH := 70.0
const _COMPACT_HEIGHT := 17.0
const _SMALL_ICON := 16.0
## Win95's name box in a compact row: 2 px around the text.
const _COMPACT_PAD := 2.0
## The space between a Details column's edge and its text, in the rows and in the header.
const CELL_PAD := 7.0
## The stock teal under a focused, unselected desktop icon, which the focus dots invert.
const _DESKTOP_COLOR := Color(0, 0.5, 0.5)

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
## Draws the icon and its name in the selection colour, while [member active].
@export var selected := false:
	set(value):
		selected = value
		_sync()
## Draws Win95's dotted focus rectangle around the name, while [member active]: the icon that the
## keyboard acts on.
@export var focused := false:
	set(value):
		focused = value
		_sync()
## The icon's view is in the active window (or is the active desktop). Win95 hides the selection
## and the focus of the other views.
@export var active := true:
	set(value):
		active = value
		_sync()
## The icon opens something that isn't built yet: Stub marks it.
@export var stub := false:
	set(value):
		stub = value
		_sync()
## Lays the icon out in one 17 px row: the 16 px twin of [member icon] (Win95File.small_icon, or
## [member icon] scaled down), then the name, cut with "..." to fit [member row_width].
@export var compact := false:
	set(value):
		compact = value
		_sync()
## In a compact row: the row's width in pixels; the name gets what the icon leaves. With
## [member columns], the Name column's width instead.
@export var row_width := 112.0:
	set(value):
		row_width = value
		_sync()
## The Details columns, Name first, or empty outside Details. The row draws [member details] in
## the columns after Name.
var columns: Array[ReportList.Column] = []:
	set(value):
		columns = value
		_sync()
## The texts of the Details columns after Name, in their order; FileDetails.cells makes them.
var details: PackedStringArray = []:
	set(value):
		details = value
		queue_redraw()

## Where the icon stands in its IconView, from the view's top left; ZERO flows with the others.
## IconView.place sets it.
var placed_at := Vector2.ZERO

var _large_minimum := Vector2.ZERO
var _large_separation := 0


func _ready() -> void:
	_large_minimum = custom_minimum_size
	_large_separation = get_theme_constant("separation")
	%Name.draw.connect(_draw_focus)
	_sync()


# Only the picture and the name take clicks, as in Win95, so the rest of the cell or row is
# empty space that starts a selection rectangle.
func _has_point(point: Vector2) -> bool:
	return Rect2((%Icon as Control).position, (%Icon as Control).size).merge(Rect2((%Name as Control).position, (%Name as Control).size)).has_point(point)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_RIGHT:
		# On release, as Win95 does: a popup that opens on the press takes the release, and the
		# viewport then routes the next click here as if the right button were still held.
		accept_event()
		if not button.pressed:
			context_clicked.emit(button.global_position)
	elif button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if button.double_click:
			opened.emit()
		else:
			var on_name: bool = %Name.get_global_rect().has_point(button.global_position)
			clicked.emit(button.ctrl_pressed or button.meta_pressed, button.shift_pressed, on_name)


## The picture and the name in canvas coordinates: the part that a selection rectangle must touch.
func hit_rect() -> Rect2:
	return (%Icon as Control).get_global_rect().merge((%Name as Control).get_global_rect())


func _sync() -> void:
	if not is_node_ready():
		return
	var icon_rect: TextureRect = %Icon
	var picture := icon
	if compact:
		var small := Win95File.small_icon(icon)
		picture = small if small != null else icon
	icon_rect.texture = Stub.mark(picture) if stub else picture
	icon_rect.material = _selection_material() if selected and active else null
	var label: Label = %Name
	label.text = text
	label.queue_redraw()
	if selected and active:
		label.theme_type_variation = &"IconLabelSelected"
	else:
		label.theme_type_variation = &"DesktopIconLabel" if on_desktop else &"IconLabel"
	_sync_layout(icon_rect, label)
	queue_redraw()


func _sync_layout(icon_rect: TextureRect, label: Label) -> void:
	if vertical == compact:
		vertical = not compact
	queue_sort()  # setting vertical sorts at once, before the sizes below change
	add_theme_constant_override("separation", 0 if compact else _large_separation)
	icon_rect.custom_minimum_size = Vector2.ONE * (_SMALL_ICON if compact else 32.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE if compact else TextureRect.EXPAND_KEEP_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_SCALE if compact else TextureRect.STRETCH_KEEP
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if compact else VERTICAL_ALIGNMENT_TOP
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if compact else TextServer.OVERRUN_NO_TRIMMING
	# The name box hugs the text, as Win95 draws the selection behind the name only.
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	if not compact:
		custom_minimum_size = _large_minimum
		var block := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, _WRAP_WIDTH, size)
		var box := label.get_theme_stylebox("normal")
		label.custom_minimum_size = Vector2(ceilf(block.x) + box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT), 0)
		return
	var name_width := columns[0].width if not columns.is_empty() else row_width
	var row := 0.0
	for column in columns:
		row += column.width
	custom_minimum_size = Vector2(row if not columns.is_empty() else row_width, _COMPACT_HEIGHT)
	var wide := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) + 2.0 * _COMPACT_PAD
	label.custom_minimum_size = Vector2(minf(wide, name_width - _SMALL_ICON), _COMPACT_HEIGHT)


func _draw() -> void:
	if not compact or columns.is_empty():
		return
	var font := get_theme_font("font", &"Label")
	var font_size := get_theme_font_size("font_size", &"Label")
	var ink := get_theme_color("font_color", &"IconLabel")
	var x := columns[0].width
	for i in range(1, columns.size()):
		var column := columns[i]
		if i - 1 < details.size():
			ReportList.draw_text(self, Rect2(x, 0, column.width, size.y), details[i - 1], font, font_size, ink, CELL_PAD, column.right_aligned)
		x += column.width


# Win95 XORs the dots onto the name's background, so they are its inverse: yellow on the selection.
func _draw_focus() -> void:
	if not (focused and active):
		return
	var label: Label = %Name
	var under := Color.WHITE
	var box := label.get_theme_stylebox("normal") as StyleBoxFlat
	if box != null and box.bg_color.a > 0.0:
		under = box.bg_color
	elif on_desktop:
		under = _DESKTOP_COLOR
	var color := Color(1.0 - under.r, 1.0 - under.g, 1.0 - under.b)
	var w := int(label.size.x)
	var h := int(label.size.y)
	for x in w:
		for y: int in [0, h - 1]:
			if (x + y) % 2 == 0:
				label.draw_rect(Rect2(x, y, 1, 1), color)
	for y in range(1, h - 1):
		for x: int in [0, w - 1]:
			if (x + y) % 2 == 0:
				label.draw_rect(Rect2(x, y, 1, 1), color)


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
