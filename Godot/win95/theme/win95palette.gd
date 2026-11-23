@tool
class_name Win95Palette
extends Resource
## The Windows 95 system colours that Win95Bevel and the Win95 theme draw with. Named after the
## items in Display Properties > Appearance. Bevels that share one palette all redraw when a colour
## changes. Setting a colour to its current value emits nothing, so re-applying a palette redraws nothing.

## Every colour of a scheme.
const COLOURS: Array[StringName] = [&"face_color", &"window_color", &"highlight_color", &"light_color",
	&"shadow_color", &"dark_shadow_color", &"button_text_color", &"window_text_color", &"gray_text_color",
	&"selection_color", &"selection_text_color", &"active_title_color", &"active_title_text_color",
	&"inactive_title_color", &"inactive_title_text_color", &"tooltip_color", &"tooltip_text_color"]

const _ATLAS := preload("res://win95/theme/atlas.png")
## The enabled check boxes and radio buttons in the atlas: their white inside is the Window colour.
const _ATLAS_FIELDS: Array[Rect2i] = [Rect2i(31, 0, 13, 13), Rect2i(45, 0, 13, 13), Rect2i(87, 0, 12, 12), Rect2i(100, 0, 12, 12)]
## The theme colours that each palette colour sets, as "Type/item".
const _THEME_COLOURS := {
	&"button_text_color": ["Button/font_color", "Button/font_focus_color", "Button/font_hover_color",
		"Button/font_hover_pressed_color", "Button/font_pressed_color", "CheckBox/font_color",
		"CheckBox/font_focus_color", "CheckBox/font_hover_color", "CheckBox/font_hover_pressed_color",
		"CheckBox/font_pressed_color", "Label/font_color", "MenuBar/font_color", "MenuBar/font_focus_color",
		"MenuBar/font_hover_color", "MenuBar/font_hover_pressed_color", "MenuBar/font_pressed_color",
		"OptionButton/font_color", "OptionButton/font_hover_color", "OptionButton/font_hover_pressed_color",
		"OptionButton/font_pressed_color", "PopupMenu/font_color", "PopupMenu/font_accelerator_color",
		"ProgressBar/font_color", "TabBar/font_hovered_color", "TabBar/font_selected_color",
		"TabBar/font_unselected_color", "TabContainer/font_hovered_color", "TabContainer/font_selected_color",
		"TabContainer/font_unselected_color"],
	&"window_text_color": ["IconLabel/font_color", "ItemList/font_color", "ItemList/font_hovered_color",
		"LineEdit/font_color", "LineEdit/font_uneditable_color", "LineEdit/caret_color", "TextEdit/font_color",
		"TextEdit/caret_color"],
	&"gray_text_color": ["Button/font_disabled_color", "CheckBox/font_disabled_color", "DisabledLabel/font_color",
		"LineEdit/font_placeholder_color", "LineEdit/font_readonly_color", "MenuBar/font_disabled_color",
		"OptionButton/font_disabled_color", "PopupMenu/font_disabled_color", "TabBar/font_disabled_color",
		"TabContainer/font_disabled_color", "TextEdit/font_placeholder_color", "TextEdit/font_readonly_color"],
	&"selection_color": ["LineEdit/selection_color", "TextEdit/selection_color"],
	&"selection_text_color": ["IconLabelSelected/font_color", "ItemList/font_hovered_selected_color",
		"ItemList/font_selected_color", "LineEdit/font_selected_color", "OptionButton/font_focus_color",
		"PopupMenu/font_hover_color", "TextEdit/font_selected_color"],
	&"active_title_text_color": ["TitleLabel/font_color"],
	&"inactive_title_text_color": ["TitleLabelInactive/font_color"],
	&"tooltip_text_color": ["TooltipLabel/font_color"],
}
## The flat styleboxes whose fill each palette colour sets, as "Type/item".
const _THEME_FILLS := {
	&"selection_color": ["IconLabelSelected/normal", "ItemList/selected", "PopupMenu/hover"],
	&"active_title_color": ["TitleBar/panel"],
	&"inactive_title_color": ["TitleBarInactive/panel"],
	&"tooltip_color": ["TooltipPanel/panel"],
}

## "3D Objects": buttons, windows, dialogs.
@export var face_color := Color("#c0c0c0"):
	set(value):
		if value != face_color:
			face_color = value
			emit_changed()
## "Window": the inside of text fields and lists.
@export var window_color := Color("#ffffff"):
	set(value):
		if value != window_color:
			window_color = value
			emit_changed()
## The bright line on the lit side of an edge.
@export var highlight_color := Color("#ffffff"):
	set(value):
		if value != highlight_color:
			highlight_color = value
			emit_changed()
## The softer second line on the lit side.
@export var light_color := Color("#dfdfdf"):
	set(value):
		if value != light_color:
			light_color = value
			emit_changed()
## The gray line on the shaded side.
@export var shadow_color := Color("#808080"):
	set(value):
		if value != shadow_color:
			shadow_color = value
			emit_changed()
## The black outer line on the shaded side.
@export var dark_shadow_color := Color("#000000"):
	set(value):
		if value != dark_shadow_color:
			dark_shadow_color = value
			emit_changed()
## Text and glyphs on 3D objects: buttons, labels, menus, tabs, scroll arrows.
@export var button_text_color := Color("#000000"):
	set(value):
		if value != button_text_color:
			button_text_color = value
			emit_changed()
## Text in text fields and lists.
@export var window_text_color := Color("#000000"):
	set(value):
		if value != window_text_color:
			window_text_color = value
			emit_changed()
## Disabled text.
@export var gray_text_color := Color("#808080"):
	set(value):
		if value != gray_text_color:
			gray_text_color = value
			emit_changed()
## "Selected Items": behind selected text and the hovered menu item.
@export var selection_color := Color("#000080"):
	set(value):
		if value != selection_color:
			selection_color = value
			emit_changed()
## Selected text.
@export var selection_text_color := Color("#ffffff"):
	set(value):
		if value != selection_text_color:
			selection_text_color = value
			emit_changed()
## "Active Title Bar".
@export var active_title_color := Color("#000080"):
	set(value):
		if value != active_title_color:
			active_title_color = value
			emit_changed()
@export var active_title_text_color := Color("#ffffff"):
	set(value):
		if value != active_title_text_color:
			active_title_text_color = value
			emit_changed()
## "Inactive Title Bar".
@export var inactive_title_color := Color("#808080"):
	set(value):
		if value != inactive_title_color:
			inactive_title_color = value
			emit_changed()
@export var inactive_title_text_color := Color("#c0c0c0"):
	set(value):
		if value != inactive_title_text_color:
			inactive_title_text_color = value
			emit_changed()
## "ToolTip".
@export var tooltip_color := Color("#ffffe1"):
	set(value):
		if value != tooltip_color:
			tooltip_color = value
			emit_changed()
@export var tooltip_text_color := Color("#000000"):
	set(value):
		if value != tooltip_text_color:
			tooltip_text_color = value
			emit_changed()

var _atlas_roles: PackedStringArray
var _atlas: ImageTexture
var _atlas_stale := false


## Sets every colour to [param from]'s.
func copy_colours(from: Win95Palette) -> void:
	for colour in COLOURS:
		set(colour, from.get(colour))


## Whether every colour matches [param other]'s.
func same_colours(other: Win95Palette) -> bool:
	return COLOURS.all(func(colour: StringName) -> bool: return (get(colour) as Color).is_equal_approx(other.get(colour)))


## The theme's glyph atlas in these colours. The same texture for the life of the palette; it
## follows every later change of colour.
func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(_recoloured_atlas())
		changed.connect(_mark_atlas_stale)
	return _atlas


## Paints [param theme]'s text colours, selection, title bars, tooltips and glyphs in these colours.
func paint(theme: Theme) -> void:
	for colour: StringName in _THEME_COLOURS:
		for path: String in _THEME_COLOURS[colour]:
			theme.set_color(path.get_slice("/", 1), path.get_slice("/", 0), get(colour))
	for colour: StringName in _THEME_FILLS:
		for path: String in _THEME_FILLS[colour]:
			var box := theme.get_stylebox(path.get_slice("/", 1), path.get_slice("/", 0)) as StyleBoxFlat
			assert(box != null, "Win95Palette: %s in %s is no StyleBoxFlat" % [path, theme.resource_path])
			box.bg_color = get(colour)
	(theme.get_stylebox(&"panel", &"TooltipPanel") as StyleBoxFlat).border_color = tooltip_text_color
	var glyphs := atlas()
	for type in theme.get_type_list():
		for icon in theme.get_icon_list(type):
			var texture := theme.get_icon(icon, type) as AtlasTexture
			if texture != null and texture.atlas == _ATLAS:
				texture.atlas = glyphs
		for style in theme.get_stylebox_list(type):
			var box := theme.get_stylebox(style, type)
			if box is StyleBoxTexture and box.texture is AtlasTexture and box.texture.atlas == _ATLAS:
				box.texture.atlas = glyphs
			elif box is StyleBoxTexture and box.texture == _ATLAS:
				box.texture = glyphs


# Once per frame, however many colours changed.
func _mark_atlas_stale() -> void:
	if not _atlas_stale:
		_atlas_stale = true
		_refresh_atlas.call_deferred()


func _refresh_atlas() -> void:
	_atlas_stale = false
	_atlas.update(_recoloured_atlas())


# The atlas is drawn in Windows Standard; each pixel takes the colour of its role in this palette.
func _recoloured_atlas() -> Image:
	var image := _ATLAS.get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var roles := _roles(image)
	for y in image.get_height():
		for x in image.get_width():
			var role := roles[y * image.get_width() + x]
			if role != "":
				image.set_pixel(x, y, get(role))
	return image


# The palette colour of each pixel of the stock atlas, or "" to keep it. Black is both the dark
# shadow and the glyphs; every scheme gives them one colour, and the glyphs must stay readable.
func _roles(image: Image) -> PackedStringArray:
	if not _atlas_roles.is_empty():
		return _atlas_roles
	var stock := {Color("#000000"): "button_text_color", Color("#808080"): "shadow_color",
		Color("#c0c0c0"): "face_color", Color("#dfdfdf"): "light_color", Color("#ffffff"): "highlight_color"}
	var width := image.get_width()
	var roles := PackedStringArray()
	roles.resize(width * image.get_height())
	for y in image.get_height():
		for x in width:
			var pixel: Color = image.get_pixel(x, y)
			roles[y * width + x] = stock.get(Color(pixel, 1.0), "") if pixel.a > 0.0 else ""
	for field in _ATLAS_FIELDS:
		for at in _enclosed_white(image, field):
			roles[at.y * width + at.x] = "window_color"
	_atlas_roles = roles
	return roles


# The white pixels of the region that no path of white or clear pixels links to its edge.
static func _enclosed_white(image: Image, region: Rect2i) -> Array[Vector2i]:
	var open := func(at: Vector2i) -> bool:
		var pixel: Color = image.get_pixelv(at)
		return pixel.a == 0.0 or Color(pixel, 1.0).is_equal_approx(Color.WHITE)
	var outside := {}
	var todo: Array[Vector2i] = []
	for x in range(region.position.x, region.end.x):
		todo.append_array([Vector2i(x, region.position.y), Vector2i(x, region.end.y - 1)])
	for y in range(region.position.y, region.end.y):
		todo.append_array([Vector2i(region.position.x, y), Vector2i(region.end.x - 1, y)])
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		if outside.has(at) or not region.has_point(at) or not open.call(at):
			continue
		outside[at] = true
		todo.append_array([at + Vector2i.LEFT, at + Vector2i.RIGHT, at + Vector2i.UP, at + Vector2i.DOWN])
	var enclosed: Array[Vector2i] = []
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var at := Vector2i(x, y)
			if not outside.has(at) and image.get_pixelv(at).is_equal_approx(Color.WHITE):
				enclosed.append(at)
	return enclosed
