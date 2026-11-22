class_name StoryBiblePanel
extends HBoxContainer
## The Story Lab's Bible tab: the pages of story/bible/ (Markdown that the game doesn't read), as
## editable text. Each edit is a new text of the page, which [signal saved] hands up.

## [param text] is the new text of the page [param path]; "" removes it.
signal saved(path: String, text: String)

const DIR: String = "res://story/bible/"
const SETTLE_SECONDS: float = 0.4

var _drafts: StoryDrafts
var _path: String = ""
var _pages: ItemList
var _name: LineEdit
var _code: CodeEdit
var _title: Label
var _remove: Button
var _settle: Timer


func _ready() -> void:
	_build()


## Lists the pages with [param drafts] over them, and opens the first (or the open one).
func show_pages(drafts: StoryDrafts) -> void:
	_drafts = drafts
	_fill()


## The open page, or "".
func path() -> String:
	return _path


## Opens the page [param page] (a res:// path).
func open_page(page: String) -> void:
	_settle_now()
	_path = page
	_title.text = page.get_file()
	_code.text = _drafts.text(page)
	_code.clear_undo_history()
	_code.editable = true
	_remove.visible = true
	_remove.text = "Remove page"
	for i: int in _pages.item_count:
		if _pages.get_item_metadata(i) == page:
			_pages.select(i)


func _fill() -> void:
	_pages.clear()
	var pages := PackedStringArray()
	if DirAccess.dir_exists_absolute(DIR):
		pages = StoryFiles.files(DIR, ".md", _drafts.texts())
	else:
		for drafted: String in _drafts.paths():
			if drafted.begins_with(DIR) and drafted.ends_with(".md") and _drafts.text(drafted) != "":
				pages.append(drafted)
	for page: String in pages:
		_pages.add_item(page.get_file().get_basename().capitalize())
		_pages.set_item_metadata(_pages.item_count - 1, page)
	if _path in pages:
		open_page(_path)
	elif not pages.is_empty():
		open_page(pages[0])
	else:
		_path = ""
		_title.text = "No pages yet: name one below and add it."
		_code.text = ""
		_code.editable = false
		_remove.visible = false


func _settle_now() -> void:
	if _settle != null and not _settle.is_stopped():
		_settle.stop()
		_save()


func _save() -> void:
	if _path != "" and _code.editable:
		saved.emit(_path, _code.text)


func _add_page() -> void:
	var name := _name.text.strip_edges().to_lower().replace(" ", "_")
	name = RegEx.create_from_string("[^a-z0-9_-]").sub(name, "", true)
	if name == "":
		_title.text = "A page needs a name: letters, digits, - or _."
		return
	var page := DIR + name + ".md"
	if _drafts.text(page) == "":
		saved.emit(page, "# %s\n" % _name.text.strip_edges())
	_name.text = ""
	_path = page
	_fill()


func _remove_page() -> void:
	if _remove.text == "Remove page":
		_remove.text = "Remove: sure?"
		return
	_settle.stop()
	saved.emit(_path, "")
	_path = ""
	_fill()


func _build() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SETTLE_SECONDS
	_settle.timeout.connect(_save)
	add_child(_settle)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 360
	add_child(left)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	left.add_child(list)
	list.add_child(LabUI.label("The bible", 22))
	var about := LabUI.label("The story that the game doesn't read: the lore, the cast and the end.", 13, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(about)
	_pages = ItemList.new()
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pages.item_selected.connect(func(index: int) -> void: open_page(_pages.get_item_metadata(index)))
	list.add_child(_pages)
	var add := HBoxContainer.new()
	list.add_child(add)
	_name = LineEdit.new()
	_name.placeholder_text = "New page name"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_submitted.connect(func(_t: String) -> void: _add_page())
	add.add_child(_name)
	add.add_child(LabUI.button("Add", _add_page))
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	right.add_child(page)
	var head := HBoxContainer.new()
	page.add_child(head)
	_title = LabUI.label("", 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_remove = LabUI.button("Remove page", _remove_page, &"FlatButton")
	head.add_child(_remove)
	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.indent_use_spaces = false
	_code.indent_size = 4
	var markdown := CodeHighlighter.new()
	markdown.number_color = LabUI.TEXT
	markdown.symbol_color = LabUI.TEXT
	markdown.function_color = LabUI.TEXT
	markdown.member_variable_color = LabUI.TEXT
	markdown.add_color_region("#", "", LabUI.ACCENT, true)
	markdown.add_color_region("**", "**", LabUI.CHANGED)
	markdown.add_color_region("`", "`", LabUI.PLAYER)
	_code.syntax_highlighter = markdown
	_code.text_changed.connect(func() -> void: _settle.start())
	page.add_child(_code)
