extends "res://win95/window.gd"
## Office 97's Office Assistant dialog, from the assistant's Options...: the Gallery with the one
## assistant there is, and the Options tab, whose checkboxes OK keeps on this computer. The scene
## inherits property_sheet.tscn for its look; the options aren't Win95 settings, so it has its own
## script.

const _GREETINGS: Array[String] = ["Hey, there. What's the word?", "How's life? All work and no play?"]
const _CLIP := preload("res://win95/office/assistant/clippy_rest.png")
const _BALLOON := preload("res://win95/office/assistant/balloon.gd")
## The Options tab's groups: [heading, [option, label] cells in two columns ("" holds Reset my tips),
## then the cell that spans both columns, or none].
const _GROUPS: Array = [
	["Assistant capabilities", [
		[&"respond_to_f1", "Respond to F1 key"], [&"move_when_in_the_way", "Move when in the way"],
		[&"help_with_wizards", "Help with wizards"], [&"guess_help_topics", "Guess help topics"],
		[&"display_alerts", "Display alerts"], [&"make_sounds", "Make sounds"]],
		[&"search_programming", "Search for both product and programming help when programming"]],
	["Show tips about", [
		[&"tips_features", "Using features more effectively"], [&"tips_keyboard", "Keyboard shortcuts"],
		[&"tips_mouse", "Using the mouse more effectively"]], []],
	["Other tip options", [
		[&"high_priority_only", "Only show high priority tips"], [&"", ""],
		[&"tip_at_startup", "Show the Tip of the Day at startup"]], []],
]

var _assistant: Node
var _boxes: Dictionary[StringName, CheckBox] = {}


func _ready() -> void:
	super()
	%Apply.hide()
	%Ok.pressed.connect(_keep)
	%Cancel.pressed.connect(close)
	closed.connect(queue_free)
	%Tabs.add_child(_gallery())
	%Tabs.add_child(_options_page())
	%Tabs.current_tab = 1


## Shows [param assistant]'s options (assistant.gd), which OK sets.
func edit(assistant: Node) -> void:
	_assistant = assistant
	var values: Dictionary = assistant.call(&"options")
	for option: StringName in _boxes:
		_boxes[option].button_pressed = values.get(option, false)


## Ticks or clears [param option]'s checkbox, as a click does; for tests.
func set_option(option: StringName, on: bool) -> void:
	_boxes[option].button_pressed = on


func _keep() -> void:
	if _assistant != null:
		var values: Dictionary = _assistant.call(&"options")
		for option: StringName in _boxes:
			values[option] = _boxes[option].button_pressed
	close()


func _gallery() -> Control:
	var page := VBoxContainer.new()
	page.name = "Gallery"
	page.add_theme_constant_override(&"separation", 12)
	page.add_child(_wrapped("You can scroll through the different assistants by using the <Back and Next> buttons. When you are finished selecting your assistant, click the OK button.", 470.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 40)
	var picture := ColorRect.new()
	picture.custom_minimum_size = Vector2(125, 94)
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var clip := TextureRect.new()
	clip.texture = _CLIP
	clip.position = Vector2(42, 13)
	picture.add_child(clip)
	row.add_child(picture)
	var about := VBoxContainer.new()
	about.add_child(_greeting())
	about.add_child(_wrapped("Name:              Clippit", 250.0))
	about.add_child(_wrapped("Though nothing more than a thin metal wire, Clippit will help find what you need and keep it all together.", 250.0))
	row.add_child(about)
	page.add_child(row)
	var buttons := HBoxContainer.new()
	var back := Button.new()
	back.text = "<Back"
	back.disabled = true
	back.custom_minimum_size = Vector2(75, 23)
	buttons.add_child(back)
	var next := Button.new()
	next.text = "Next>"
	next.icon = Stub.dot()
	next.custom_minimum_size = Vector2(75, 23)
	buttons.add_child(next)
	page.add_child(buttons)
	return page


# The gallery's pale yellow box with a greeting, as Office 97 shows beside each assistant.
func _greeting() -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _BALLOON.FILL
	style.border_color = Color.BLACK
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_top = 6
	box.add_theme_stylebox_override(&"panel", style)
	box.custom_minimum_size = Vector2(250, 70)
	var label := Label.new()
	label.text = _GREETINGS.pick_random()
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override(&"font_color", Color.BLACK)
	box.add_child(label)
	return box


func _options_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Options"
	page.add_theme_constant_override(&"separation", 2)
	for group: Array in _GROUPS:
		var heading := HBoxContainer.new()
		var title := Label.new()
		title.text = group[0]
		heading.add_child(title)
		var line := HSeparator.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(line)
		page.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 16)
		var indent := MarginContainer.new()
		indent.add_theme_constant_override(&"margin_left", 16)
		indent.add_child(grid)
		page.add_child(indent)
		for cell: Array in group[1]:
			if cell[0] == &"":
				grid.add_child(_reset_button())
				continue
			grid.add_child(_check_box(cell[0], cell[1]))
		if not group[2].is_empty():
			var wide := MarginContainer.new()
			wide.add_theme_constant_override(&"margin_left", 16)
			wide.add_child(_check_box(group[2][0], group[2][1]))
			page.add_child(wide)
	return page


func _check_box(option: StringName, label: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = label
	box.custom_minimum_size.x = 230
	_boxes[option] = box
	return box


func _reset_button() -> Button:
	var reset := Button.new()
	reset.text = "Reset my tips"
	reset.custom_minimum_size = Vector2(105, 23)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		if _assistant != null:
			_assistant.call(&"reset_tips"))
	return reset


func _wrapped(text: String, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label
