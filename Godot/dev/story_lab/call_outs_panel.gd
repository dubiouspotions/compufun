class_name StoryCallOutsPanel
extends HBoxContainer
## The Story Lab's Call-outs: what each customer, or everyone, calls out while they wait and the
## player looks elsewhere (story/callouts/, docs/dialogue.md "Call-outs"), as editable text with a
## row that adds a set for a day, a daypart and an effect. Each edit that parses is a new text of
## the file, which [signal saved] hands up; clearing a customer's text removes their file.

## [param text] is the new text of the call-outs file [param path]; "" removes it.
signal saved(path: String, text: String)

const SETTLE_SECONDS: float = 0.4

var _drafts: StoryDrafts
var _path: String = ""
var _list: ItemList
var _title: Label
var _about: Label
var _day: OptionButton
var _daypart: OptionButton
var _effect: OptionButton
var _code: CodeEdit
var _errors: ItemList
var _settle: Timer


func _ready() -> void:
	_build()


## Lists everyone and each customer with [param drafts] over their files, and opens the open one
## (everyone's at first).
func show_call_outs(drafts: StoryDrafts) -> void:
	_drafts = drafts
	_fill()


## The res:// path of the open call-outs file, which may not exist yet.
func path() -> String:
	return _path


## Opens the call-outs of [param name]: a customer's file name, or CallOuts.EVERYONE.
func open(outs_name: StringName) -> void:
	_settle_now()
	_path = "%s%s.callouts" % [StoryFiles.CALL_OUTS_DIR, outs_name]
	var everyone := outs_name == CallOuts.EVERYONE
	_title.text = "Everyone" if everyone else _spoken(outs_name)
	_about.text = "Every customer calls these out, unless a set of their own matches." if everyone else \
		"%s calls out the first of these sets whose day, daypart and flags match, else the one without any; with none that matches, everyone's." % _title.text
	_code.placeholder_text = "" if everyone else "%s calls out everyone's lines. Add a set above to give them their own." % _title.text
	_code.text = _drafts.text(_path)
	_code.clear_undo_history()
	_mark(PackedStringArray())
	for i: int in _list.item_count:
		if _list.get_item_metadata(i) == outs_name:
			_list.select(i)


func _fill() -> void:
	_list.clear()
	var names: Array[StringName] = [CallOuts.EVERYONE]
	for each: String in LabUI.resource_names(StoryFormat.CUSTOMERS_DIR):
		names.append(StringName(each))
	for outs_name: StringName in names:
		_list.add_item("")
		_list.set_item_metadata(_list.item_count - 1, outs_name)
		_name_item(_list.item_count - 1)
	open(StringName(_path.get_file().get_basename()) if _path != "" else CallOuts.EVERYONE)


# Names the customer of item [param index] and how many sets of their own they have.
func _name_item(index: int) -> void:
	var outs_name: StringName = _list.get_item_metadata(index)
	var text := _drafts.text("%s%s.callouts" % [StoryFiles.CALL_OUTS_DIR, outs_name])
	var sets := Array(text.split("\n")).filter(func(line: String) -> bool: return line.begins_with("==")).size()
	var shown := "Everyone" if outs_name == CallOuts.EVERYONE else _spoken(outs_name)
	_list.set_item_text(index, "%s   %s" % [shown, ("%d set%s" % [sets, "" if sets == 1 else "s"]) if sets > 0 else "(everyone's)"])
	_list.set_item_custom_fg_color(index, LabUI.TEXT if sets > 0 else LabUI.DIM)


func _spoken(outs_name: StringName) -> String:
	var customer := load(StoryFormat.CUSTOMERS_DIR + outs_name + ".tres") as Customer
	if customer == null:
		push_error("Story Lab: %s%s.tres doesn't load as a Customer" % [StoryFormat.CUSTOMERS_DIR, outs_name])
		return String(outs_name)
	return customer.spoken_name()


func _settle_now() -> void:
	if _settle != null and not _settle.is_stopped():
		_settle.stop()
		_save()


# Saves the text when it parses, and everyone's only with a set that has no [if] or [daypart].
func _save() -> void:
	if _path == "" or _code.text == _drafts.text(_path):
		return
	var text := _code.text if _code.text.strip_edges() != "" else ""
	var parsed := StoryFormat.parse_call_outs(text, _path)
	var errors := parsed.errors
	var outs := parsed.value as CallOuts
	if errors.is_empty() and outs.name == CallOuts.EVERYONE and not outs.sets.any(func(each: CallOuts.Set) -> bool: return each.is_plain()):
		errors.append("%s:1: everyone needs a '== waiting' set without [if] or [daypart]; every customer falls back to it" % _path)
	_mark(errors)
	if errors.is_empty():
		saved.emit(_path, text)
		for index: int in _list.get_selected_items():
			_name_item(index)


func _mark(errors: PackedStringArray) -> void:
	for line: int in _code.get_line_count():
		_code.set_line_background_color(line, Color.TRANSPARENT)
	_errors.clear()
	for error: String in errors:
		var rest := error.trim_prefix(_path + ":")
		var line := rest.get_slice(":", 0).to_int() - 1
		if line >= 0 and line < _code.get_line_count():
			_code.set_line_background_color(line, Color(LabUI.BAD, 0.22))
		_errors.add_item("line %d: %s" % [line + 1, rest.substr(rest.find(":") + 1).strip_edges()])
		_errors.set_item_metadata(_errors.item_count - 1, line)
	_errors.visible = not errors.is_empty()


func _add_set() -> void:
	var head := "== waiting"
	if _day.selected > 0:
		head += " [if day %d]" % _day.selected
	if _daypart.selected > 0:
		head += " [daypart %s]" % CallOuts.DAYPARTS[_daypart.selected - 1]
	if _effect.selected > 0:
		head += " [effect %s]" % _effect.get_item_text(_effect.selected)
	var text := _code.text.strip_edges(false, true)
	_code.text = (text + "\n\n" if text != "" else "") + head + "\n(neutral) "
	_code.set_caret_line(_code.get_line_count() - 1)
	_code.set_caret_column(_code.get_line(_code.get_line_count() - 1).length())
	_code.grab_focus()


func _complete() -> void:
	var before := _code.get_line(_code.get_caret_line()).substr(0, _code.get_caret_column())
	var options := PackedStringArray()
	var suffix := "]"
	if RegEx.create_from_string("^\\([a-z0-9_]*$").search(before) != null:
		options = LabUI.resource_names(Voices.MOODS_DIR)
		suffix = ") "
	elif RegEx.create_from_string("\\[effect [a-z0-9_]*$").search(before) != null:
		options = LabUI.resource_names(Voices.EFFECTS_DIR)
	elif RegEx.create_from_string("\\[voice [a-z0-9_]*$").search(before) != null:
		options = LabUI.resource_names(Voices.MOODS_DIR)
	elif RegEx.create_from_string("\\[daypart [a-z]*$").search(before) != null:
		options = PackedStringArray(CallOuts.DAYPARTS)
	elif RegEx.create_from_string("\\[[a-z]*$").search(before) != null:
		options = PackedStringArray(["if ", "daypart ", "effect "] if before.begins_with("==") else ["effect ", "voice "])
		suffix = ""
	for option: String in options:
		_code.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, option.strip_edges(), option + suffix)
	_code.update_code_completion_options(true)


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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	left.add_child(column)
	column.add_child(LabUI.label("Call-outs", 22))
	var about := LabUI.label("What customers call out while they wait at the counter and the player looks elsewhere. They climb through a set's moods, calmest first.", 13, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(about)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void: open(_list.get_item_metadata(index)))
	column.add_child(_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	right.add_child(page)
	_title = LabUI.label("", 18)
	page.add_child(_title)
	_about = LabUI.label("", 13, LabUI.DIM)
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_about)
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 8)
	page.add_child(add)
	add.add_child(LabUI.label("New set:", 14, LabUI.DIM))
	_day = OptionButton.new()
	_day.add_item("Any day")
	for n: int in range(1, StoryFiles.DAYS + 1):
		_day.add_item("Day %d" % n)
	add.add_child(_day)
	_daypart = OptionButton.new()
	_daypart.add_item("Any daypart")
	for part: StringName in CallOuts.DAYPARTS:
		_daypart.add_item(String(part).capitalize())
	add.add_child(_daypart)
	_effect = OptionButton.new()
	_effect.add_item("No effect")
	for effect: String in LabUI.resource_names(Voices.EFFECTS_DIR):
		_effect.add_item(effect)
	add.add_child(_effect)
	add.add_child(LabUI.button("Add set", _add_set))
	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.gutters_draw_line_numbers = true
	_code.indent_use_spaces = false
	_code.indent_size = 4
	_code.code_completion_enabled = true
	_code.code_completion_prefixes = ["(", " ", "["]
	_code.add_theme_constant_override("line_spacing", 6)
	var highlighter := StoryHighlighter.new()
	for mood: String in LabUI.resource_names(Voices.MOODS_DIR):
		highlighter.moods[StringName(mood)] = true
	_code.syntax_highlighter = highlighter
	_code.text_changed.connect(func() -> void: _settle.start())
	_code.code_completion_requested.connect(_complete)
	page.add_child(_code)
	_errors = ItemList.new()
	_errors.custom_minimum_size.y = 70
	_errors.add_theme_color_override("font_color", LabUI.BAD)
	_errors.visible = false
	_errors.item_clicked.connect(func(index: int, _at: Vector2, _button: int) -> void:
		var line: int = _errors.get_item_metadata(index)
		if line >= 0:
			_code.set_caret_line(line)
			_code.grab_focus())
	page.add_child(_errors)
