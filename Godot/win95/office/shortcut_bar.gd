extends BackgroundTask
## MSOFFICE.EXE, the Microsoft Office Shortcut Bar of Office 97 (docs/win95-reference.md, "Office
## 97"): while it runs, a row of buttons docked at the top right of its computer's desktop, above
## every window, as the real one sat in a maximized window's title bar. The Office logo starts it;
## each other button opens its program. It starts from the StartUp folder on computers that have it.

## The buttons after the logo: [tooltip, icon, path of the program on drive C]. A button whose
## program isn't on the computer doesn't show.
@export var buttons: Array[Array] = [
	["Microsoft Word", preload("res://win95/office/icons/word_16.png"), "C:\\Program Files\\Microsoft Office\\Office\\WINWORD.EXE"],
]
## The gap between the bar and the desktop's right edge, which keeps a maximized window's caption
## buttons free.
@export var right_margin := 62.0

## The bar on the desktop while the task runs; null otherwise.
var bar: Control

var _desktop: Win95Desktop


func start(state: ComputerState) -> void:
	super(state)
	for node in get_tree().get_nodes_in_group(Win95Desktop.GROUP):
		if (node as Win95Desktop).computer == state:
			_desktop = node
	if _desktop == null:
		push_error("Office Shortcut Bar: no desktop shows %s, so the bar has nowhere to dock" % state)
		return
	bar = _build()
	_desktop.add_child(bar)
	bar.reset_size()
	bar.position = Vector2(_desktop.size.x - right_margin - bar.size.x, 0)
	tree_exiting.connect(bar.queue_free)


## The button that opens [param tooltip]'s program, or null.
func button(tooltip: String) -> Button:
	if bar == null:
		return null
	for child in bar.find_children("*", "Button", true, false):
		if (child as Button).tooltip_text == tooltip:
			return child
	return null


func _build() -> Control:
	var frame := HBoxContainer.new()
	frame.z_index = 1  # above every window, which the desktop orders by tree position
	frame.add_theme_constant_override(&"separation", 0)
	var logo := TextureRect.new()
	logo.texture = preload("res://win95/office/icons/office_logo_16.png")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.custom_minimum_size = Vector2(18, 20)
	var navy := ColorRect.new()
	navy.color = Color("#000080")
	navy.show_behind_parent = true
	navy.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.add_child(navy)
	frame.add_child(logo)
	var rule := ColorRect.new()
	rule.color = Color("#800080")
	rule.custom_minimum_size = Vector2(3, 20)
	frame.add_child(rule)
	for entry: Array in buttons:
		var program := computer.setup.file_at(entry[2]) if computer.setup != null else null
		if program == null:
			continue
		var press := Button.new()
		press.icon = entry[1]
		press.tooltip_text = entry[0]
		press.focus_mode = Control.FOCUS_NONE
		press.custom_minimum_size = Vector2(22, 20)
		press.pressed.connect(_open.bind(entry[2]))
		frame.add_child(press)
	return frame


# Windows above the bar in the tree would take its presses, so it catches them first.
func _input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if bar == null or press == null or press.button_index != MOUSE_BUTTON_LEFT or not press.pressed or not bar.is_visible_in_tree():
		return
	for child in bar.get_children():
		if child is Button and (child as Button).get_global_rect().has_point(press.position):
			get_viewport().set_input_as_handled()
			(child as Button).pressed.emit()
			return
	if bar.get_global_rect().has_point(press.position):
		get_viewport().set_input_as_handled()


func _open(path: String) -> void:
	var screen := _desktop.owner if _desktop != null else null  # win95.gd, which opens files as Windows does
	var program := computer.setup.file_at(path)
	if screen == null or not screen.has_method(&"open_file"):
		push_error("Office Shortcut Bar: no Win95 screen owns the desktop, so it can't open %s" % path)
	elif program == null:
		push_error("Office Shortcut Bar: %s is gone" % path)
	else:
		screen.open_file(program)
