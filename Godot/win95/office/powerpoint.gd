extends OfficeWindow
## Microsoft PowerPoint 97 (POWERPNT.EXE): a presentation of slides with title and text placeholders
## in a few AutoLayouts and design templates. Slide view edits one slide; Slide Sorter shows them all
## to pick, delete or open; Slide Show plays them over the whole screen. It opens and saves .ppt
## files in the plain text format of docs/ppt.md (PptDeck).

## The file extensions that PowerPoint opens, lower case, without the dot.
@export var opens: Array[String] = ["ppt"]
## The design templates that Apply Design lists, the Default Design first.
@export var designs: Array[PptDesign] = []

enum View { SLIDE, SORTER }

const _LAYOUT_DIALOG := preload("res://win95/office/ppt_layout_dialog.tscn")
const _DESIGN_DIALOG := preload("res://win95/office/ppt_design_dialog.tscn")
const _SHOW := preload("res://win95/office/ppt_show.tscn")
const _START := preload("res://win95/office/ppt_start_dialog.tscn")
const _THUMB := Vector2(160, 120)

## The presentation on show.
var deck := PptDeck.parse("")
## The slide that Slide view shows and Slide Sorter selects, from 0.
var current := 0
var view := View.SLIDE

var _saved := ""  # the deck as last loaded or saved
var _slide_cell: Label
var _design_cell: Label

@onready var _slide: SlideView = %Slide


func _ready() -> void:
	super()
	_slide.edited.connect(edited)
	%SlideScroll.value_changed.connect(func(value: float) -> void: go_to(int(value)))
	%SlideViewButton.pressed.connect(show_view.bind(View.SLIDE))
	%SorterViewButton.pressed.connect(show_view.bind(View.SORTER))
	%ShowButton.pressed.connect(slide_show)
	%TasksTitle.close_pressed.connect(func() -> void: %CommonTasks.hide())
	for task: Array in [[%NewSlideTask, new_slide_dialog], [%LayoutTask, layout_dialog], [%DesignTask, design_dialog]]:
		(task[0] as Button).pressed.connect(task[1])
	_slide_cell = add_status_cell("", 245)
	_design_cell = add_status_cell("", 245)
	for cell in [_slide_cell, _design_cell]:
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_status_cell("", 33)
	_saved = deck.to_text()
	_refresh()
	_greet.call_deferred()


## The presentation's text without formatting, slide by slide, for the assistant.
func document_text() -> String:
	var lines: PackedStringArray = []
	for slide in deck.slides:
		lines.append(slide.title)
		lines.append_array(slide.body)
		lines.append_array(slide.right)
	return "\n".join(lines)


## The design that [member deck] names, or null for the Default Design.
func design() -> PptDesign:
	for candidate in designs:
		if candidate.name == deck.design and deck.design != "":
			return candidate
	return null


## Shows slide [param index] in Slide view, or selects it in Slide Sorter.
func go_to(index: int) -> void:
	current = clampi(index, 0, deck.slides.size() - 1)
	_refresh()


## Switches to Slide view or Slide Sorter.
func show_view(to: View) -> void:
	view = to
	_refresh()


## Adds a slide with [param layout] after the current one and shows it, as New Slide's OK does.
func add_slide(layout: String) -> void:
	_slide.stop_editing()
	deck.slides.insert(current + 1, PptDeck.Slide.new(layout))
	current += 1
	edited()
	_refresh()


## Deletes the current slide, as Edit > Delete Slide does. The last one stays: a presentation has a
## slide.
func delete_slide() -> void:
	if deck.slides.size() <= 1:
		deck.slides[0] = PptDeck.Slide.new(deck.slides[0].layout)
	else:
		deck.slides.remove_at(current)
		current = mini(current, deck.slides.size() - 1)
	edited()
	_refresh()


## Gives the current slide [param layout], keeping its text where the new layout has room for it.
func set_layout(layout: String) -> void:
	_slide.stop_editing()
	deck.slides[current].layout = layout
	edited()
	_refresh()


## Applies the design named [param design_name]; empty is the Default Design.
func apply_design(design_name: String) -> void:
	deck.design = design_name
	edited()
	_refresh()


## Insert > New Slide: picks a layout, then adds the slide.
func new_slide_dialog() -> void:
	var dialog := _open_dialog(_LAYOUT_DIALOG)
	if dialog != null:
		dialog.chosen.connect(add_slide)
		dialog.belong_to(self)


## Format > Slide Layout: picks a new layout for the current slide.
func layout_dialog() -> void:
	var dialog := _open_dialog(_LAYOUT_DIALOG)
	if dialog != null:
		dialog.as_slide_layout(deck.slides[current].layout)
		dialog.chosen.connect(set_layout)
		dialog.belong_to(self)


## Format > Apply Design: picks a design template.
func design_dialog() -> void:
	var dialog := _open_dialog(_DESIGN_DIALOG)
	if dialog != null:
		dialog.list(designs, deck.design)
		dialog.chosen.connect(apply_design)
		dialog.belong_to(self)


## Slide Show > View Show: the slides over the whole screen from the current one; the show ends on
## the slide it reached.
func slide_show() -> Control:
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("PowerPoint: not on a Win95Desktop, so it has no screen to show %s on" % untitled_name)
		return null
	_slide.stop_editing()
	var show: Control = desktop.cover(_SHOW)
	show.start(deck, designs, current)
	show.ended.connect(func(at: int) -> void: go_to(at))
	return show


# Without a file, PowerPoint opens with its start dialog; Blank presentation then asks for the first
# slide's layout.
func _greet() -> void:
	if file != null or not is_inside_tree():
		return
	var dialog := _open_dialog(_START)
	if dialog != null:
		dialog.blank_chosen.connect(func() -> void:
			var picker := _open_dialog(_LAYOUT_DIALOG)
			if picker != null:
				picker.pick("Title Slide")
				picker.chosen.connect(set_layout)
				picker.belong_to(self))
		dialog.belong_to(self)


func _retitle() -> void:
	super()
	%TitleBar.title = "%s - [%s]" % [_app_title, file.name.get_basename() if file != null else untitled_name]


func _open_dialog(scene: PackedScene) -> Control:
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("PowerPoint: not on a Win95Desktop, so it can't open %s" % scene.resource_path)
		return null
	return desktop.open(scene, false)


func _focus_default() -> void:
	if is_inside_tree():
		%SlideArea.grab_focus()


func _load(from: Win95File) -> void:
	deck = PptDeck.parse(from.contents if from != null else "")
	current = 0
	_saved = deck.to_text()
	_refresh()
	if from == null or deck.errors.is_empty():
		return
	var path := _state.path_of(from) if _state != null else from.name
	push_error("PowerPoint: %s has lines that it can't read:\n%s" % [path, "\n".join(deck.errors)])
	var desktop := get_parent() as Win95Desktop
	if desktop != null:
		var box: Node = desktop.open(preload("res://win95/message_box.tscn"), false)
		box.closed.connect(box.queue_free)
		box.show_message(_app_title, "PowerPoint can't read part of %s. The rest of it is open.\n\n%s" % [from.name, deck.errors[0]])
		box.belong_to(self)


func _save(state: ComputerState, into: Win95File) -> void:
	_slide.stop_editing()
	_saved = deck.to_text()
	state.write_text(into, _saved)


func _is_dirty() -> bool:
	return deck.to_text() != _saved


func _unsaved_question(path: String) -> String:
	return "Do you want to save the changes you made to %s?" % path.get_file()


func _refresh() -> void:
	if not is_node_ready():
		return
	var count := deck.slides.size()
	current = clampi(current, 0, count - 1)
	%SlideArea.visible = view == View.SLIDE
	%Sorter.visible = view == View.SORTER
	%SlideScroll.max_value = count
	%SlideScroll.page = 1
	%SlideScroll.set_value_no_signal(current)
	if view == View.SLIDE:
		_slide.show_slide(deck.slides[current], design())
	else:
		_fill_sorter()
	_slide_cell.text = "Slide %d of %d" % [current + 1, count] if view == View.SLIDE else "Slide Sorter"
	_design_cell.text = deck.design if deck.design != "" else "Default Design"


# One thumbnail per slide, numbered; a click selects it, a double-click opens it in Slide view.
func _fill_sorter() -> void:
	for old in %Slides.get_children():
		old.queue_free()
	for i in deck.slides.size():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 2)
		var frame := PanelContainer.new()
		var border := StyleBoxFlat.new()  # a thin black edge; the selected slide's is thick and grey
		border.draw_center = false
		border.set_content_margin_all(4)
		border.border_color = Color(0.5, 0.5, 0.5) if i == current else Color.BLACK
		border.set_border_width_all(4 if i == current else 1)
		frame.add_theme_stylebox_override(&"panel", border)
		var thumb := SlideView.new()
		thumb.custom_minimum_size = _THUMB
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(thumb)
		thumb.show_slide(deck.slides[i], design())
		frame.gui_input.connect(_on_thumb_input.bind(i))
		cell.add_child(frame)
		var number := Label.new()
		number.text = str(i + 1)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.add_child(number)
		%Slides.add_child(cell)


func _on_thumb_input(event: InputEvent, index: int) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	current = index
	if press.double_click:
		view = View.SLIDE
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _is_front():
		var shortcut := key.get_keycode_with_modifiers()
		var handled := true
		if shortcut == KEY_MASK_CTRL | KEY_M:
			new_slide_dialog()
		elif shortcut == KEY_F5:
			slide_show()
		elif shortcut == KEY_PAGEDOWN and _slide.editing() < 0:
			go_to(current + 1)
		elif shortcut == KEY_PAGEUP and _slide.editing() < 0:
			go_to(current - 1)
		elif shortcut == KEY_DELETE and view == View.SORTER:
			delete_slide()
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()
			return
	super(event)


func _menus() -> Array:
	return [
		["Edit", [["Undo", null, KEY_MASK_CTRL | KEY_Z], ["Repeat", null, KEY_MASK_CTRL | KEY_Y], [],
			["Cut", null, KEY_MASK_CTRL | KEY_X], ["Copy", null, KEY_MASK_CTRL | KEY_C], ["Paste", null, KEY_MASK_CTRL | KEY_V],
			["Paste Special...", null], ["Paste as Hyperlink", null], ["Clear", null, KEY_DELETE],
			["Select All", null, KEY_MASK_CTRL | KEY_A], [], ["Duplicate", null, KEY_MASK_CTRL | KEY_D], ["Delete Slide", delete_slide], [],
			["Find...", null, KEY_MASK_CTRL | KEY_F], ["Replace...", null, KEY_MASK_CTRL | KEY_H], ["Go To Property...", null], [],
			["Links...", null], ["Object", null]]],
		["View", [["Slide", show_view.bind(View.SLIDE)], ["Outline", null], ["Slide Sorter", show_view.bind(View.SORTER)],
			["Notes Page", null], ["Slide Show", slide_show], [], ["Master", null], ["Black and White", null], ["Slide Miniature", null],
			["Speaker Notes", null], [], ["Toolbars", null], ["Ruler", null], ["Guides", null], [], ["Header and Footer...", null],
			["Comments", null], [], ["Zoom...", null]]],
		["Insert", [["New Slide...", new_slide_dialog, KEY_MASK_CTRL | KEY_M], ["Duplicate Slide", null], [], ["Slide Number", null],
			["Date and Time...", null], ["Tab", null], ["Symbol...", null], ["Comment", null], [], ["Slides from Files...", null],
			["Slides from Outline...", null], [], ["Picture", null], ["Text Box", null], [], ["Movies and Sounds", null],
			["Chart...", null], ["Object...", null], ["Hyperlink...", null, KEY_MASK_CTRL | KEY_K]]],
		["Format", [["Font...", null], ["Bullet...", null], ["Alignment", null], ["Line Spacing...", null], ["Change Case...", null],
			["Replace Fonts...", null], [], ["Slide Layout...", layout_dialog], ["Slide Color Scheme...", null], ["Background...", null],
			["Apply Design...", design_dialog], [], ["Colors and Lines...", null], ["Object...", null]]],
		["Tools", [["Spelling...", null, KEY_F7], ["Style Checker...", null], ["Language...", null], ["AutoCorrect...", null],
			["Look Up Reference...", null], [], ["PowerPoint Central", null], ["Presentation Conference...", null],
			["Meeting Minder...", null], ["Expand Slide", null], [], ["Macro", null], ["Add-Ins", null], ["Customize...", null],
			["Options...", null]]],
		["Slide Show", [["View Show", slide_show], ["Rehearse Timings", null], ["Record Narration...", null],
			["Set Up Show...", null], ["View On Two Screens...", null], [], ["Action Buttons", null], ["Action Settings...", null],
			["Preset Animation", null], ["Custom Animation...", null], ["Animation Preview", null], ["Slide Transition...", null], [],
			["Hide Slide", null], ["Custom Shows...", null]]],
		["Window", [["New Window", null], ["Arrange All", null], ["Cascade", null], [], ["Fit to Page", null]]],
		["Help", [["Microsoft PowerPoint Help", help_requested.emit, KEY_F1], [], ["Contents and Index", null],
			["What's This?", null, KEY_MASK_SHIFT | KEY_F1], ["Microsoft on the Web", null], [], ["About Microsoft PowerPoint", null]]],
	]


func _standard_tools() -> Array:
	return [
		[&"new", "New", func() -> void: _on_file_menu(FileMenu.NEW)], [&"open", "Open", null], [&"save", "Save", save], "|",
		[&"print", "Print", null], [&"spelling", "Spelling", null], "|",
		[&"cut", "Cut", null], [&"copy", "Copy", null], [&"paste", "Paste", null], [&"format_painter", "Format Painter", null], "|",
		[&"undo", "Undo", null], "v", [&"redo", "Redo", null], "v", "|",
		[&"hyperlink", "Insert Hyperlink", null], [&"web_toolbar", "Web Toolbar", null], "|",
		[&"ppt_word_table", "Insert Microsoft Word Table", null], [&"insert_worksheet", "Insert Microsoft Excel Worksheet", null],
		[&"ppt_chart", "Insert Chart", null], [&"ppt_clip_art", "Insert Clip Art", null], "|",
		[&"ppt_new_slide", "New Slide", new_slide_dialog], [&"ppt_slide_layout", "Slide Layout", layout_dialog],
		[&"ppt_apply_design", "Apply Design", design_dialog], [&"ppt_black_white", "Black and White View", null], _zoom_box(), "|",
		[&"assistant", "Office Assistant", help_requested.emit],
	]


func _formatting_tools() -> Array:
	return [
		_box(["Times New Roman"], 172), _box(["24"], 44), "|",
		[&"bold", "Bold", null], [&"italic", "Italic", null], [&"underline", "Underline", null], [&"ppt_shadow", "Text Shadow", null], "|",
		[&"align_left", "Align Left", null], [&"center", "Center", null], [&"align_right", "Align Right", null], "|",
		[&"bullets", "Bullets", null], [&"ppt_spacing_up", "Increase Paragraph Spacing", null],
		[&"ppt_spacing_down", "Decrease Paragraph Spacing", null], "|",
		[&"ppt_grow_font", "Increase Font Size", null], [&"ppt_shrink_font", "Decrease Font Size", null], "|",
		[&"ppt_promote", "Promote", null], [&"ppt_demote", "Demote", null], "|",
		[&"ppt_animation", "Animation Effects", null],
	]


func _zoom_box() -> OptionButton:
	return _box(["37%"], 52)


# A toolbar box listing [param items], [param width] pixels wide. PowerPoint's boxes only show.
func _box(items: Array, width: float) -> OptionButton:
	var box := OptionButton.new()
	for item: String in items:
		box.add_item(item)
	box.select(0)
	box.custom_minimum_size = Vector2(width, 20)
	box.focus_mode = Control.FOCUS_NONE
	box.fit_to_longest_item = false
	box.clip_text = true
	return box
