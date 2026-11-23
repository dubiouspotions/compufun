class_name LabUI
extends RefCounted
## The Story Lab's colours, theme and small widgets: the Voice Lab's dark look.

const BG := Color("12141a")
const CARD := Color("1b1e26")
const RAISED := Color("262a35")
const HOVER := Color("30354a")
const LINE := Color("2f3443")
const TEXT := Color("e8eaf0")
const DIM := Color("8b92a6")
const ACCENT := Color("7c8cff")
const CHANGED := Color("ffb454")
const GOOD := Color("5fd39a")
const BAD := Color("ff6b6b")
## The player's side of a conversation (Mascoll's Figma trees colour it teal).
const PLAYER := Color("4fc1c9")
const FIELD := Color("0f1116")


## The file names without extension of the .tres files in [param dir], sorted.
static func resource_names(dir: String) -> PackedStringArray:
	var names := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			names.append(file.get_basename())
	names.sort()
	return names


static func label(text: String, size: int = 15, color: Color = TEXT) -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_font_size_override("font_size", size)
	made.add_theme_color_override("font_color", color)
	return made


## A rounded box of [param color], [param pad] pixels inside top and bottom and three times that
## at the sides.
static func box(color: Color, radius: int, pad: int = 0) -> StyleBoxFlat:
	var made := StyleBoxFlat.new()
	made.bg_color = color
	made.set_corner_radius_all(radius)
	made.content_margin_left = pad * 3
	made.content_margin_right = pad * 3
	made.content_margin_top = pad
	made.content_margin_bottom = pad
	return made


## A button that runs [param pressed].
static func button(text: String, pressed: Callable, variation: StringName = &"") -> Button:
	var made := Button.new()
	made.text = text
	made.theme_type_variation = variation
	made.pressed.connect(pressed)
	return made


## A small square button that draws [param kind] ("up", "down" or "remove") and runs [param pressed].
static func icon_button(kind: String, tooltip: String, pressed: Callable) -> Button:
	var made := Button.new()
	made.custom_minimum_size = Vector2(30, 30)
	made.theme_type_variation = &"FlatButton"
	made.tooltip_text = tooltip
	made.focus_mode = Control.FOCUS_NONE
	made.pressed.connect(pressed)
	made.draw.connect(func() -> void:
		var c := made.size / 2.0
		var color := TEXT if made.is_hovered() else DIM
		if kind == "up":
			made.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 4), c + Vector2(6, 4), c + Vector2(0, -5)]), color)
		elif kind == "down":
			made.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -4), c + Vector2(6, -4), c + Vector2(0, 5)]), color)
		else:
			made.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), color, 2.0, true)
			made.draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), color, 2.0, true))
	return made


## Buttons in a row of which one is pressed, in [param group].
static func segmented(options: PackedStringArray, group: ButtonGroup) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for i: int in options.size():
		var made := Button.new()
		made.text = options[i]
		made.toggle_mode = true
		made.button_group = group
		made.button_pressed = i == 0
		made.theme_type_variation = &"SegmentButton"
		row.add_child(made)
	return row


## A label with [param text] in a small rounded chip of [param color].
static func chip(text: String, color: Color, size: int = 12) -> Label:
	var made := label(" %s " % text, size, color)
	made.add_theme_stylebox_override("normal", box(Color(color, 0.16), 8, 2))
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return made


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	var card := box(CARD, 12, 6)
	card.content_margin_left = 14
	card.content_margin_right = 14
	card.content_margin_top = 12
	card.content_margin_bottom = 12
	card.border_color = LINE
	card.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", card)
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, box(RAISED, 8, 5))
		t.set_stylebox("hover", type, box(HOVER, 8, 5))
		t.set_stylebox("pressed", type, box(ACCENT.darkened(0.2), 8, 5))
		t.set_stylebox("hover_pressed", type, box(ACCENT.darkened(0.1), 8, 5))
		t.set_stylebox("disabled", type, box(Color(RAISED, 0.5), 8, 5))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(state, type, TEXT)
		t.set_color("font_disabled_color", type, DIM)
	t.add_type(&"AccentButton")
	t.set_type_variation(&"AccentButton", &"Button")
	t.set_stylebox("normal", "AccentButton", box(ACCENT, 8, 5))
	t.set_stylebox("hover", "AccentButton", box(ACCENT.lightened(0.12), 8, 5))
	t.set_stylebox("pressed", "AccentButton", box(ACCENT.darkened(0.15), 8, 5))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "AccentButton", BG)
	t.add_type(&"FlatButton")
	t.set_type_variation(&"FlatButton", &"Button")
	t.set_stylebox("normal", "FlatButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "FlatButton", box(HOVER, 8, 2))
	t.set_stylebox("pressed", "FlatButton", box(HOVER, 8, 2))
	t.set_color("font_color", "FlatButton", DIM)
	t.set_color("font_hover_color", "FlatButton", TEXT)
	t.add_type(&"SegmentButton")
	t.set_type_variation(&"SegmentButton", &"Button")
	t.set_stylebox("normal", "SegmentButton", box(RAISED, 0, 5))
	t.set_stylebox("hover", "SegmentButton", box(HOVER, 0, 5))
	t.set_stylebox("pressed", "SegmentButton", box(ACCENT, 0, 5))
	t.set_stylebox("hover_pressed", "SegmentButton", box(ACCENT, 0, 5))
	t.set_color("font_pressed_color", "SegmentButton", BG)
	t.set_color("font_hover_pressed_color", "SegmentButton", BG)
	t.add_type(&"ChipButton")
	t.set_type_variation(&"ChipButton", &"Button")
	t.set_stylebox("normal", "ChipButton", box(RAISED, 12, 3))
	t.set_stylebox("hover", "ChipButton", box(HOVER, 12, 3))
	t.set_stylebox("pressed", "ChipButton", box(ACCENT, 12, 3))
	t.set_stylebox("hover_pressed", "ChipButton", box(ACCENT.lightened(0.1), 12, 3))
	t.set_color("font_pressed_color", "ChipButton", BG)
	t.set_color("font_hover_pressed_color", "ChipButton", BG)
	t.set_font_size("font_size", "ChipButton", 13)
	var field := box(FIELD, 8, 5)
	field.border_color = LINE
	field.set_border_width_all(1)
	var focused := field.duplicate() as StyleBoxFlat
	focused.border_color = ACCENT
	for type: String in ["TextEdit", "LineEdit", "CodeEdit", "SpinBox"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, focused)
		t.set_stylebox("read_only", type, field)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_readonly_color", type, DIM)
	t.set_color("font_placeholder_color", "LineEdit", DIM.darkened(0.2))
	t.set_color("font_placeholder_color", "TextEdit", DIM.darkened(0.2))
	t.set_color("background_color", "CodeEdit", FIELD)
	t.set_color("line_number_color", "CodeEdit", DIM.darkened(0.3))
	t.set_color("current_line_color", "CodeEdit", Color(RAISED, 0.6))
	t.set_color("caret_color", "CodeEdit", TEXT)
	t.set_color("selection_color", "CodeEdit", Color(ACCENT, 0.35))
	t.set_color("completion_background_color", "CodeEdit", CARD)
	t.set_color("completion_selected_color", "CodeEdit", HOVER)
	t.set_color("completion_existing_color", "CodeEdit", Color(ACCENT, 0.3))
	t.set_stylebox("completion", "CodeEdit", box(CARD, 6, 2))
	t.set_font_size("font_size", "CodeEdit", 16)
	var track := box(RAISED, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := box(ACCENT, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("panel", "PopupMenu", box(CARD, 8, 6))
	t.set_stylebox("hover", "PopupMenu", box(HOVER, 6, 2))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_stylebox("panel", "ItemList", field)
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(Color(ACCENT, 0.3), 6))
	t.set_stylebox("selected_focus", "ItemList", box(Color(ACCENT, 0.3), 6))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", TEXT)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", TEXT)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", box(CARD, 6, 4))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t
