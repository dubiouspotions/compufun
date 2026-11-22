class_name StoryErrandPanel
extends HBoxContainer
## The Story Lab's picked errand: on the left who comes and why (the brief, the problem, the
## computer, the condition), on the right a tab per conversation, as a graph or as text. Each edit
## that parses is a new text of the whole file, which [signal saved] hands up; an edit with errors
## stays here, marked, and the file keeps its last good text.

## [param text], which parses, is the new text of the errand file [param path].
signal saved(path: String, text: String)
## The writer asked to remove the errand file [param path].
signal remove_requested(path: String)
## The writer asked to play [param errand]'s conversation for [param trigger] in the game.
signal play_requested(errand: Errand, trigger: Conversation.Trigger)

## The conversation graph, while the game has it (contract: show_conversation and edited).
const GRAPH: String = "res://dev/story_lab/conversation_graph.tscn"
const PROBLEMS_DIR: String = "res://problems/"
const TRIGGER_NAMES: Dictionary[Conversation.Trigger, String] = {
	Conversation.Trigger.ARRIVE: "Drop-off",
	Conversation.Trigger.PICKUP: "Pick-up",
	Conversation.Trigger.PHONE: "Phone",
}
const COMPUTER_HINTS: PackedStringArray = [
	"They leave it on the counter for repair.",
	"They come without one, and leave when the conversation ends.",
	"It stands on the counter while they visit, and goes with them.",
]
## Seconds of no typing before an edit is parsed and saved.
const SETTLE_SECONDS: float = 0.4

## The flags to offer while typing; the Lab fills it from the week.
var flags: PackedStringArray = []

var _path: String = ""
var _text: String = ""
var _errand: Errand
var _tab: int = 0
## Conversation index to the text of its section that doesn't parse yet.
var _pending: Dictionary[int, String] = {}
var _view: String = ""
var _filling: bool = false
var _remove_armed: bool = false

var _face: Control
var _face_slot: Control
var _name: Label
var _code_label: Label
var _remove: Button
var _brief: TextEdit
var _problem: OptionButton
var _problem_text: Label
var _computer: ButtonGroup
var _computer_hint: Label
var _when: LineEdit
var _when_error: Label
var _header_error: Label
var _tabs: HBoxContainer
var _tab_group: ButtonGroup
var _views: ButtonGroup
var _remove_conversation: Button
var _code: CodeEdit
var _highlighter: StoryHighlighter
var _errors: ItemList
var _text_view: Control
var _graph_view: Control
var _empty: Control
var _play: Button
var _graph: Node
var _settle: Timer
var _field_settle: Timer


func _ready() -> void:
	_build()


## Opens the errand file [param path] with [param text]. Text that doesn't parse opens read-only
## with its errors, so the writer sees what to fix in the file.
func show_errand(path: String, text: String) -> void:
	_settle_now()
	if path != _path:
		_pending.clear()
		_tab = 0
	_path = path
	_text = text
	var parsed := StoryFormat.parse_errand(text, path)
	_errand = parsed.value as Errand
	_fill_fields()
	_fill_tabs()
	_header_error.text = "" if parsed.errors.is_empty() else "This file doesn't parse; fix it as text:\n" + "\n".join(parsed.errors)
	_show_tab(clampi(_tab, 0, maxi(_errand.conversations.size() - 1, 0)))


## The open errand file, or "".
func path() -> String:
	return _path


## The open errand as it last parsed.
func errand() -> Errand:
	return _errand


## The trigger of the conversation tab that shows; ARRIVE without one.
func trigger() -> Conversation.Trigger:
	return _errand.conversations[_tab].trigger if _tab < _errand.conversations.size() else Conversation.Trigger.ARRIVE


## Shows the conversations as "Graph" or "Text".
func show_view(view: String) -> void:
	_view = view
	_show_conversation()


## Makes [param section] the text of the conversation tab that shows, as typing there does, and
## saves the file when it parses. Returns the errors, as "line: what" within the section for its own
## lines; empty when it saved.
func edit_section(section: String) -> PackedStringArray:
	if _code.text != section:
		_code.text = section
	return _apply_section()


## The header (the lines before the first "==") and each "==" section of [param text], each without
## its trailing empty lines.
static func split(text: String) -> Dictionary:
	var header := PackedStringArray()
	var sections: Array[PackedStringArray] = []
	for line: String in text.split("\n"):
		if line.begins_with("=="):
			sections.append(PackedStringArray())
		if sections.is_empty():
			header.append(line)
		else:
			sections[sections.size() - 1].append(line)
	var texts := PackedStringArray()
	for lines: PackedStringArray in sections:
		texts.append(_trimmed(lines))
	return {"header": _trimmed(header), "sections": texts}


## The file of [param header] and [param sections]: an empty line between each, as
## StoryFormat.write_errand writes it.
static func join(header: String, sections: PackedStringArray) -> String:
	var parts := PackedStringArray([header]) if header != "" else PackedStringArray()
	parts.append_array(sections)
	return "\n\n".join(parts) + "\n"


static func _trimmed(lines: PackedStringArray) -> String:
	var kept := lines.duplicate()
	while not kept.is_empty() and kept[kept.size() - 1].strip_edges() == "":
		kept.remove_at(kept.size() - 1)
	return "\n".join(kept)


# --- Saving

# Parses [param full] as the whole file; saves it when it parses. Returns the errors.
func _apply(full: String, keep_errand: bool = false) -> PackedStringArray:
	if full == _text:
		return PackedStringArray()
	var parsed := StoryFormat.parse_errand(full, _path)
	if not parsed.errors.is_empty():
		return parsed.errors
	_text = full
	if not keep_errand:
		_errand = parsed.value as Errand
	_header_error.text = ""
	saved.emit(_path, full)
	return PackedStringArray()


func _apply_section() -> PackedStringArray:
	var parts := split(_text)
	var sections: PackedStringArray = parts["sections"]
	var section := _trimmed(_code.text.split("\n"))
	if _tab < sections.size():
		sections[_tab] = section
	elif section != "":
		sections.append(section)
	var full := join(parts["header"], sections)
	var errors := _apply(full)
	_mark(errors, parts["header"], sections)
	if not errors.is_empty():
		_pending[_tab] = _code.text
		return _local(errors, parts["header"], sections)
	_pending.erase(_tab)
	if _tab_names() != _shown_tab_names():
		_fill_tabs()
		_show_tab(clampi(_tab, 0, maxi(_errand.conversations.size() - 1, 0)))
	else:
		_show_conversation()
	return PackedStringArray()


# Saves the header with [param when] as written, and the left column's other fields.
func _apply_fields() -> void:
	if _filling or _errand == null:
		return
	var copy := _errand.duplicate() as Errand
	copy.conversations = []
	copy.when = null
	copy.brief = _brief.text.strip_edges(false, true)
	copy.problem = null if _problem.selected <= 0 else load(PROBLEMS_DIR + _problem.get_item_text(_problem.selected) + ".tres") as Problem
	copy.brings = _computer.get_pressed_button().get_index() as Errand.Brings
	var header := Array(StoryFormat.write_errand(copy).strip_edges(false, true).split("\n"))
	var when := _when.text.strip_edges()
	if when != "":
		var at := header.find("brief:")
		header.insert(at if at >= 0 else header.size(), "when: " + when)
	var errors := _apply(join("\n".join(PackedStringArray(header)), split(_text)["sections"]))
	_when_error.text = "" if errors.is_empty() else "\n".join(Array(errors).map(func(e: String) -> String: return e.get_slice(": ", 1) if e.get_slice(": ", 1) != "" else e))
	_show_problem()
	_computer_hint.text = COMPUTER_HINTS[_errand.brings]


# Marks the lines of the section that showed errors, and lists every error.
func _mark(errors: PackedStringArray, header: String, sections: PackedStringArray) -> void:
	for line: int in _code.get_line_count():
		_code.set_line_background_color(line, Color.TRANSPARENT)
	_errors.clear()
	var start := _section_start(header, sections)
	for error: String in errors:
		var line := error.trim_prefix(_path + ":").get_slice(":", 0).to_int() - 1 - start
		var what := error.trim_prefix(_path + ":").substr(error.trim_prefix(_path + ":").find(":") + 1).strip_edges()
		if line >= 0 and line < _code.get_line_count():
			_code.set_line_background_color(line, Color(LabUI.BAD, 0.22))
			_errors.add_item("line %d: %s" % [line + 1, what])
			_errors.set_item_metadata(_errors.item_count - 1, line)
		else:
			_errors.add_item("elsewhere in the file: %s" % what)
			_errors.set_item_metadata(_errors.item_count - 1, -1)
	_errors.visible = not errors.is_empty()


func _local(errors: PackedStringArray, header: String, sections: PackedStringArray) -> PackedStringArray:
	var start := _section_start(header, sections)
	var local := PackedStringArray()
	for error: String in errors:
		var rest := error.trim_prefix(_path + ":")
		var line := rest.get_slice(":", 0).to_int() - 1 - start
		local.append("%d:%s" % [line + 1, rest.substr(rest.find(":") + 1)])
	return local


# The line index in the joined file where section [member _tab] starts.
func _section_start(header: String, sections: PackedStringArray) -> int:
	var start := header.split("\n").size() + 1 if header != "" else 0
	for i: int in mini(_tab, sections.size()):
		start += sections[i].split("\n").size() + 1
	return start


# Saves the edits that wait for the typing to settle, before the panel shows something else.
func _settle_now() -> void:
	if _settle != null and not _settle.is_stopped():
		_settle.stop()
		_apply_section()
	if _field_settle != null and not _field_settle.is_stopped():
		_field_settle.stop()
		_apply_fields()


# --- Conversations

func _tab_names() -> PackedStringArray:
	var names := PackedStringArray()
	var counts: Dictionary[Conversation.Trigger, int] = {}
	for c: Conversation in _errand.conversations:
		counts[c.trigger] = counts.get(c.trigger, 0) + 1
	var seen: Dictionary[Conversation.Trigger, int] = {}
	for c: Conversation in _errand.conversations:
		seen[c.trigger] = seen.get(c.trigger, 0) + 1
		names.append(TRIGGER_NAMES[c.trigger] + (" %d" % seen[c.trigger] if counts[c.trigger] > 1 else ""))
	return names


func _shown_tab_names() -> PackedStringArray:
	var names := PackedStringArray()
	for button: BaseButton in _tab_group.get_buttons():
		names.append((button as Button).text)
	return names


func _fill_tabs() -> void:
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	_tab_group = ButtonGroup.new()
	var names := _tab_names()
	for i: int in names.size():
		var tab := Button.new()
		tab.text = names[i]
		tab.toggle_mode = true
		tab.button_group = _tab_group
		tab.theme_type_variation = &"SegmentButton"
		tab.tooltip_text = _errand.conversations[i].brief if _errand.conversations[i].brief != "" else "No brief: write one under the == line"
		tab.toggled.connect(func(on: bool) -> void:
			if on:
				_show_tab(i))
		_tabs.add_child(tab)


func _show_tab(index: int) -> void:
	if index != _tab:
		_settle_now()
	_tab = index
	for button: BaseButton in _tab_group.get_buttons():
		button.set_pressed_no_signal(button.get_index() == index)
	var sections: PackedStringArray = split(_text)["sections"]
	_code.text = _pending.get(index, sections[index] if index < sections.size() else "")
	_code.clear_undo_history()
	_code.editable = _header_error.text == ""
	if _pending.has(index):
		_apply_section()
	else:
		_mark(PackedStringArray(), "", PackedStringArray())
	_show_conversation()


# Shows what the open errand's tab and view call for: the conversation as text or as a graph, or,
# without conversations, a way to add one. Every change of errand, tab or view comes here.
func _show_conversation() -> void:
	var has := _errand != null and _tab < _errand.conversations.size()
	_empty.visible = not has
	_text_view.visible = has and _view == "Text"
	_graph_view.visible = has and _view == "Graph"
	_remove_conversation.visible = has
	var why := "" if has else "Add a conversation first"
	for button: BaseButton in _views.get_buttons():
		button.set_pressed_no_signal((button as Button).text == _view)
		button.disabled = not has
		button.tooltip_text = why
	_play.disabled = not has
	_play.tooltip_text = "Play this conversation in the game; Esc or F4 comes back" if has else why
	if has and _view == "Graph":
		_show_graph()


func _add_conversation(trigger_index: int) -> void:
	var name: String = StoryFormat.TRIGGERS.keys()[trigger_index]
	var parts := split(_text)
	var sections: PackedStringArray = parts["sections"]
	sections.append("== " + name)
	_pending.clear()
	if _apply(join(parts["header"], sections)).is_empty():
		_fill_tabs()
		_show_tab(_errand.conversations.size() - 1)


func _remove_shown_conversation() -> void:
	if _tab >= _errand.conversations.size():
		return
	var conversation := _errand.conversations[_tab]
	var said := not conversation.lines.is_empty() or not conversation.choices.is_empty()
	if said and _remove_conversation.text != "Remove: sure?":
		_remove_conversation.text = "Remove: sure?"
		return
	_remove_conversation.text = "Remove"
	var parts := split(_text)
	var sections: PackedStringArray = parts["sections"]
	sections.remove_at(_tab)
	_pending.clear()
	if _apply(join(parts["header"], sections)).is_empty():
		_fill_tabs()
		_show_tab(clampi(_tab, 0, maxi(_errand.conversations.size() - 1, 0)))


func _show_graph() -> void:
	for child: Node in _graph_view.get_children():
		if child != _graph:
			child.queue_free()
	if _graph == null:
		var scene := load(GRAPH) as PackedScene
		if scene == null:
			push_error("Story Lab: %s doesn't load" % GRAPH)
			return
		_graph = scene.instantiate()
		if _graph is Control:
			(_graph as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_graph_view.add_child(_graph)
		_graph.connect(&"edited", func() -> void: _apply(StoryFormat.write_errand(_errand), true))
	if _errand != null and _tab < _errand.conversations.size():
		_graph.call(&"show_conversation", _errand.conversations[_tab], _errand.customer)


# --- Completion

func _complete() -> void:
	var before := _code.get_line(_code.get_caret_line()).substr(0, _code.get_caret_column())
	var options := PackedStringArray()
	var suffix := ""
	if RegEx.create_from_string("^\\t*\\([a-z0-9_]*$").search(before) != null:
		options = _moods()
		suffix = ") "
	elif RegEx.create_from_string("\\[effect [a-z0-9_]*$").search(before) != null:
		options = LabUI.resource_names("res://voices/effects/")
		suffix = "]"
	elif RegEx.create_from_string("\\[[a-z]*$").search(before) != null:
		options = PackedStringArray(["if ", "once]", "effect ", "leave ", "back "] if before.begins_with("==") else ["if ", "end]"])
	elif RegEx.create_from_string("(^\\t*(set|if) |\\[if )[^\\]]*$").search(before) != null:
		options = flags
	for option: String in options:
		_code.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, option.strip_edges(), option + suffix)
	_code.update_code_completion_options(true)


func _moods() -> PackedStringArray:
	var moods := PackedStringArray()
	var person := _errand.customer.person if _errand != null and _errand.customer != null else null
	if person != null:
		for mood: StringName in person.portraits:
			moods.append(mood)
	if moods.is_empty():
		moods = LabUI.resource_names("res://voices/moods/")
	return moods


# --- The left column

func _fill_fields() -> void:
	_filling = true
	_remove_armed = false
	_remove.text = "Remove errand"
	var customer := _errand.customer
	var face := StoryLabBoard.portrait(customer, 72)
	_face_slot.remove_child(_face)
	_face.queue_free()
	_face = face
	_face_slot.add_child(_face)
	_name.text = customer.spoken_name() if customer != null else "No customer"
	_code_label.text = "%s   %s" % [_errand.code, _path.get_file()]
	_brief.text = _errand.brief
	_problem.select(0)
	for i: int in _problem.item_count:
		if _errand.problem != null and _problem.get_item_text(i) == _errand.problem.resource_path.get_file().get_basename():
			_problem.select(i)
	for button: BaseButton in _computer.get_buttons():
		button.set_pressed_no_signal(button.get_index() == _errand.brings)  # no_signal bypasses the group
	_computer_hint.text = COMPUTER_HINTS[_errand.brings]
	_when.text = StoryFormat.write_condition(_errand.when) if _errand.when != null else ""
	_when_error.text = ""
	var moods: Dictionary[StringName, bool] = {}
	for mood: String in _moods():
		moods[StringName(mood)] = true
	_highlighter.moods = moods
	_show_problem()
	_filling = false


func _show_problem() -> void:
	var problem := _errand.problem
	if problem == null:
		_problem_text.text = "No repair: the visit needs none."
		return
	var lines := PackedStringArray(["Post-it: " + (problem.perceived_issue if problem.perceived_issue != "" else "(empty)")])
	if not problem.symptoms.is_empty():
		lines.append("Symptoms: " + "; ".join(problem.symptoms))
	if not problem.hardware_steps.is_empty():
		lines.append("Hardware: " + "; ".join(problem.hardware_steps))
	if not problem.software_steps.is_empty():
		lines.append("Software: " + "; ".join(problem.software_steps))
	_problem_text.text = "\n".join(lines)


func _arm_remove() -> void:
	if not _remove_armed:
		_remove_armed = true
		_remove.text = "Remove: sure?"
		return
	remove_requested.emit(_path)


# --- Building

func _build() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_left())
	add_child(_right())
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SETTLE_SECONDS
	_settle.timeout.connect(_apply_section)
	add_child(_settle)
	_field_settle = Timer.new()
	_field_settle.one_shot = true
	_field_settle.wait_time = SETTLE_SECONDS
	_field_settle.timeout.connect(_apply_fields)
	add_child(_field_settle)
	show_view("Graph")


func _left() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_right", 14)
	scroll.add_child(inset)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	inset.add_child(box)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	box.add_child(who)
	_face_slot = CenterContainer.new()
	who.add_child(_face_slot)
	_face = Control.new()
	_face_slot.add_child(_face)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	who.add_child(names)
	_name = LabUI.label("", 24)
	names.add_child(_name)
	_code_label = LabUI.label("", 13, LabUI.DIM)
	names.add_child(_code_label)
	_remove = LabUI.button("Remove errand", _arm_remove, &"FlatButton")
	_remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(_remove)
	box.add_child(LabUI.label("What this visit is for", 14, LabUI.DIM))
	_brief = TextEdit.new()
	_brief.custom_minimum_size.y = 96
	_brief.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_brief.placeholder_text = "The brief: what the visit must get across, in plain words. The game doesn't show it."
	_brief.text_changed.connect(func() -> void: _field_settle.start())
	box.add_child(_brief)
	box.add_child(LabUI.label("Problem", 14, LabUI.DIM))
	_problem = OptionButton.new()
	_problem.add_item("No problem: no repair")
	for name: String in LabUI.resource_names(PROBLEMS_DIR):
		_problem.add_item(name)
	_problem.item_selected.connect(func(_i: int) -> void: _apply_fields())
	box.add_child(_problem)
	_problem_text = LabUI.label("", 13, LabUI.DIM)
	_problem_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_problem_text)
	box.add_child(LabUI.label("Computer", 14, LabUI.DIM))
	_computer = ButtonGroup.new()
	var computer := LabUI.segmented(PackedStringArray(["Leaves it", "None", "Shows it"]), _computer)
	for button: BaseButton in _computer.get_buttons():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_apply_fields())
	box.add_child(computer)
	_computer_hint = LabUI.label("", 13, LabUI.DIM)
	box.add_child(_computer_hint)
	box.add_child(LabUI.label("Comes when", 14, LabUI.DIM))
	_when = LineEdit.new()
	_when.placeholder_text = "always"
	_when.tooltip_text = "Empty: the errand always comes. Or flags and days, such as:\nskater_cambion, not gone_skater_bro, days 2-4"
	_when.text_changed.connect(func(_t: String) -> void: _field_settle.start())
	box.add_child(_when)
	_when_error = LabUI.label("", 13, LabUI.BAD)
	_when_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_when_error)
	_header_error = LabUI.label("", 13, LabUI.BAD)
	_header_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_header_error)
	return panel


func _right() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	box.add_child(bar)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 0)
	_tab_group = ButtonGroup.new()
	bar.add_child(_tabs)
	var add := MenuButton.new()
	add.text = "+"
	add.tooltip_text = "Add a conversation"
	for name: String in TRIGGER_NAMES.values():
		add.get_popup().add_item(name)
	add.get_popup().id_pressed.connect(_add_conversation)
	bar.add_child(add)
	_remove_conversation = LabUI.button("Remove", _remove_shown_conversation, &"FlatButton")
	_remove_conversation.tooltip_text = "Remove this conversation from the errand"
	bar.add_child(_remove_conversation)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_views = ButtonGroup.new()
	var views := LabUI.segmented(PackedStringArray(["Graph", "Text"]), _views)
	for button: BaseButton in _views.get_buttons():
		button.custom_minimum_size.x = 80
		button.toggled.connect(func(on: bool) -> void:
			if on:
				show_view((button as Button).text))
	bar.add_child(views)
	_play = LabUI.button("Play", func() -> void:
		_settle_now()
		play_requested.emit(_errand, trigger()), &"AccentButton")
	_play.custom_minimum_size.x = 80
	bar.add_child(_play)
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	_text_view = VBoxContainer.new()
	_text_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(_text_view)
	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.gutters_draw_line_numbers = true
	_code.indent_use_spaces = false
	_code.indent_size = 4
	_code.indent_automatic = true
	_code.code_completion_enabled = true
	_code.code_completion_prefixes = ["(", " ", "[", ","]
	_code.add_theme_constant_override("line_spacing", 6)
	_highlighter = StoryHighlighter.new()
	_code.syntax_highlighter = _highlighter
	_code.text_changed.connect(func() -> void: _settle.start())
	_code.code_completion_requested.connect(_complete)
	_text_view.add_child(_code)
	_errors = ItemList.new()
	_errors.custom_minimum_size.y = 70
	_errors.add_theme_color_override("font_color", LabUI.BAD)
	_errors.visible = false
	_errors.item_clicked.connect(func(index: int, _at: Vector2, _button: int) -> void:
		var line: int = _errors.get_item_metadata(index)
		if line >= 0:
			_code.set_caret_line(line)
			_code.grab_focus())
	_text_view.add_child(_errors)
	_graph_view = Control.new()
	_graph_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(_graph_view)
	_empty = CenterContainer.new()
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(_empty)
	var empty := VBoxContainer.new()
	empty.add_theme_constant_override("separation", 14)
	_empty.add_child(empty)
	var none := LabUI.label("No conversations yet", 20)
	none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_child(none)
	var adds := HBoxContainer.new()
	adds.add_theme_constant_override("separation", 10)
	empty.add_child(adds)
	for i: int in TRIGGER_NAMES.size():
		adds.add_child(LabUI.button("+  " + TRIGGER_NAMES.values()[i], _add_conversation.bind(i)))
	return panel
