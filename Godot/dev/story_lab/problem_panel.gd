class_name StoryProblemPanel
extends HBoxContainer
## The Story Lab's Problems: every computer problem of the week, with its post-it and whether the
## game can repair it yet, and a form for the open one (the post-it, the symptoms and the checks and
## how each shows, the repair steps and notes). Each edit that is complete is a new text of the problem file
## (story/problems/<id>.problem), which [signal saved] hands up.

## [param text] is the new text of the problem file [param path]; "" removes it.
signal saved(path: String, text: String)

const SETTLE_SECONDS: float = 0.4
const SYMPTOM_WARNING: String = "You changed a symptom that the game already checks for: %s. The repair checks match this text; tell a developer."
const NOT_BUILT_TIP: String = "Writers named this problem; a developer still has to make its repair work in the game."

var _drafts: StoryDrafts
var _problems: Dictionary[StringName, Problem] = {}
var _id: StringName = &""
var _filling: bool = false

var _list: VBoxContainer
var _new_name: LineEdit
var _new_error: Label
var _form: Control
var _empty: Label
var _title: Label
var _built_slot: HBoxContainer
var _remove: Button
var _post_it: LineEdit
var _symptoms: VBoxContainer
var _checks: VBoxContainer
var _hardware: VBoxContainer
var _software: VBoxContainer
var _notes: TextEdit
var _warning: Label
var _errors: Label
var _settle: Timer


func _ready() -> void:
	_build()


## Lists [param problems] (the week's, by id) with [param drafts] over their files. The open problem
## stays open while it is still there; else the first opens.
func show_problems(problems: Dictionary[StringName, Problem], drafts: StoryDrafts) -> void:
	_drafts = drafts
	_problems = problems
	if not _problems.has(_id):
		_id = &""
		var ids := _sorted_ids()
		if not ids.is_empty():
			open_problem(ids[0])
		else:
			_form.hide()
			_empty.show()
	_fill_list()


## Opens the problem [param id] in the form.
func open_problem(id: StringName) -> void:
	_settle_now()
	_id = id
	_form.show()
	_empty.hide()
	var parsed := StoryFormat.parse_problem(_drafts.text(path()), path())
	var problem := parsed.value as Problem
	_filling = true
	_title.text = String(id).capitalize()
	for child: Node in _built_slot.get_children():
		child.queue_free()
	var built := built(_problems.get(id))
	var chip := LabUI.chip("the game repairs it" if built else "not built yet", LabUI.GOOD if built else LabUI.CHANGED, 13)
	chip.tooltip_text = "It has repair mechanics in problems/%s.tres." % id if built else NOT_BUILT_TIP
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	_built_slot.add_child(chip)
	_remove.visible = not built
	_remove.text = "Remove problem"
	_post_it.text = problem.perceived_issue
	_clear(_symptoms)
	for symptom: String in problem.symptoms:
		_add_symptom(symptom, problem.symptom_shows.get(symptom, ""))
	_clear(_checks)
	for check: String in problem.checks:
		_add_check(check, problem.check_shows.get(check, ""))
	for list: VBoxContainer in [_hardware, _software]:
		_clear(list)
		for step: String in (problem.hardware_steps if list == _hardware else problem.software_steps):
			_add_step(list, step)
	_notes.text = problem.notes
	_errors.text = "" if parsed.errors.is_empty() else "This file has errors; editing the form rewrites it:\n" + "\n".join(_plain(parsed.errors))
	_filling = false
	_warn()
	_fill_list()


## The open problem's id, or &"".
func problem_id() -> StringName:
	return _id


## The open problem's file.
func path() -> String:
	return StoryFiles.PROBLEMS_DIR + String(_id) + ".problem"


## True when [param problem] has repair mechanics: its problems/<id>.tres, with a broken part, a
## software check or a blocker. The story check lists the others.
static func built(problem: Problem) -> bool:
	return problem != null and problem.resource_path.ends_with(".tres") and (problem.broken_part != null or problem.software_check != null or problem.blocker != null)


## The problem id of a name that a writer typed: lower case, spaces as _, other characters left out.
static func id_of(name: String) -> String:
	return RegEx.create_from_string("[^a-z0-9_]").sub(name.strip_edges().to_lower().replace(" ", "_").replace("-", "_"), "", true)


## Makes the text-only problem that [param name] names, its post-it the name, and opens it. Returns
## "" or why not, in plain words.
func add_problem(name: String) -> String:
	var id := id_of(name)
	if id == "":
		return "Name the problem with letters or digits."
	if _problems.has(StringName(id)):
		return "There is a problem %s already." % id
	saved.emit(StoryFiles.PROBLEMS_DIR + id + ".problem", "post-it: %s\n" % name.strip_edges())
	if _problems.has(StringName(id)):
		open_problem(StringName(id))
	return ""


## The problem file that the form writes; [member _errors] says why when it can't be written yet.
func text() -> String:
	var problem := Problem.new()
	problem.perceived_issue = _post_it.text.strip_edges()
	problem.symptoms = _shown(_symptoms, problem.symptom_shows)
	problem.checks = _shown(_checks, problem.check_shows)
	problem.hardware_steps = _steps(_hardware)
	problem.software_steps = _steps(_software)
	problem.notes = _notes.text.strip_edges(false, true)
	return StoryFormat.write_problem(problem)


func _save() -> void:
	if _filling or _id == &"":
		return
	_warn()
	var problems := _form_problems()
	if not problems.is_empty():
		_errors.text = "\n".join(problems)
		return
	var written := text()
	var parsed := StoryFormat.parse_problem(written, path())
	if not parsed.errors.is_empty():
		_errors.text = "\n".join(_plain(parsed.errors))
		return
	_errors.text = ""
	saved.emit(path(), written)


# What keeps the form from being a problem file, in plain words.
func _form_problems() -> PackedStringArray:
	var found := PackedStringArray()
	if _post_it.text.strip_edges() == "":
		found.append("Write the post-it: what the customer says is wrong.")
	for list: VBoxContainer in [_symptoms, _checks]:
		var noun := "symptom" if list == _symptoms else "check"
		var seen: Dictionary[String, bool] = {}
		for row: Node in list.get_children():
			var entry := (row.get_child(0) as LineEdit).text.strip_edges()
			if entry == "" and (row.get_child(1) as LineEdit).text.strip_edges() != "":
				found.append("A %s says how it shows, but not what it is." % noun)
			elif seen.has(entry):
				found.append("Two %ss say \"%s\"; give each its own words." % [noun, entry])
			seen[entry] = true
	return found


# Warns when the form drops or rewords a symptom of the checkout's file while the game checks for it.
func _warn() -> void:
	_warning.text = ""
	if not built(_problems.get(_id)):
		return
	var current := PackedStringArray()
	for row: Node in _symptoms.get_children():
		current.append((row.get_child(0) as LineEdit).text.strip_edges())
	var changed := PackedStringArray()
	for symptom: String in (StoryFormat.parse_problem(_drafts.checkout_text(path()), path()).value as Problem).symptoms:
		if symptom not in current:
			changed.append("\"%s\"" % symptom)
	if not changed.is_empty():
		_warning.text = SYMPTOM_WARNING % ", ".join(changed)


func _plain(errors: PackedStringArray) -> PackedStringArray:
	var plain := PackedStringArray()
	for error: String in errors:
		var rest := error.trim_prefix(path() + ":")
		plain.append(rest.substr(rest.find(":") + 1).strip_edges() if rest != error else error)
	return plain


# The entries of the rows of [param list], with how each shows into [param shows].
func _shown(list: VBoxContainer, shows: Dictionary[String, String]) -> PackedStringArray:
	var entries := PackedStringArray()
	for row: Node in list.get_children():
		var entry := (row.get_child(0) as LineEdit).text.strip_edges()
		var how := (row.get_child(1) as LineEdit).text.strip_edges()
		if entry != "":
			entries.append(entry)
			if how != "":
				shows[entry] = how
	return entries


func _steps(list: VBoxContainer) -> PackedStringArray:
	var steps := PackedStringArray()
	for row: Node in list.get_children():
		var step := (row.get_child(0) as LineEdit).text.strip_edges()
		if step != "":
			steps.append(step)
	return steps


func _sorted_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_problems.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func _settle_now() -> void:
	if _settle != null and not _settle.is_stopped():
		_settle.stop()
		_save()


func _changed() -> void:
	if not _filling:
		_settle.start()


func _clear(list: Control) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


# --- The list

func _fill_list() -> void:
	_clear(_list)
	for id: StringName in _sorted_ids():
		var file := StoryFiles.PROBLEMS_DIR + String(id) + ".problem"
		var post_it := (StoryFormat.parse_problem(_drafts.text(file), file).value as Problem).perceived_issue
		var row := PanelContainer.new()
		var style := LabUI.box(LabUI.RAISED, 8, 4)
		style.content_margin_left = 10
		style.border_color = LabUI.ACCENT if id == _id else LabUI.LINE
		style.set_border_width_all(2 if id == _id else 1)
		row.add_theme_stylebox_override("panel", style)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				open_problem(id))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(head)
		var name := LabUI.label(String(id).capitalize(), 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		if _drafts.has(file):
			head.add_child(LabUI.chip("draft", LabUI.CHANGED, 10))
		if not built(_problems[id]):
			var chip := LabUI.chip("not built yet", LabUI.CHANGED, 10)
			chip.tooltip_text = NOT_BUILT_TIP
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			head.add_child(chip)
		var post := LabUI.label(post_it if post_it != "" else "(no post-it yet)", 13, LabUI.DIM)
		post.clip_text = true
		box.add_child(post)
		_list.add_child(row)


func _add_new() -> void:
	var failed := add_problem(_new_name.text)
	_new_error.text = failed
	if failed == "":
		_new_name.text = ""


func _arm_remove() -> void:
	if _remove.text == "Remove problem":
		_remove.text = "Remove: sure?"
		return
	_settle.stop()
	var gone := path()
	_id = &""
	saved.emit(gone, "")


# --- The form's rows

func _add_symptom(symptom: String = "", shows: String = "") -> void:
	_add_shown(_symptoms, symptom, shows, "As the customer or the player would put it", "What the player sees or hears")


func _add_check(check: String = "", shows: String = "") -> void:
	_add_shown(_checks, check, shows, "What a working computer does, such as: Boots from C:", "How it fails in the game")


func _add_shown(list: VBoxContainer, entry: String, shows: String, what_hint: String, how_hint: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var what := LineEdit.new()
	what.text = entry
	what.placeholder_text = what_hint
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.text_changed.connect(func(_t: String) -> void: _changed())
	row.add_child(what)
	var how := LineEdit.new()
	how.text = shows
	how.placeholder_text = how_hint
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.size_flags_stretch_ratio = 1.6
	how.text_changed.connect(func(_t: String) -> void: _changed())
	row.add_child(how)
	var heading := LineEdit.new()
	heading.text = category
	heading.placeholder_text = "Its heading in CompuFunDB"
	heading.tooltip_text = "Where the player meets it, such as At startup or In Windows; CompuFunDB lists the symptom under this heading."
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_stretch_ratio = 0.6
	heading.text_changed.connect(func(_t: String) -> void: _changed())
	row.add_child(heading)
	_add_row_buttons(row)
	list.add_child(row)


func _add_step(list: VBoxContainer, step: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var field := LineEdit.new()
	field.text = step
	field.placeholder_text = "One step, as CompuFunDB prints it"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.text_changed.connect(func(_t: String) -> void: _changed())
	row.add_child(field)
	_add_row_buttons(row)
	list.add_child(row)


func _add_row_buttons(row: HBoxContainer) -> void:
	row.add_child(LabUI.icon_button("up", "Move up", func() -> void: _move(row, -1)))
	row.add_child(LabUI.icon_button("down", "Move down", func() -> void: _move(row, 1)))
	row.add_child(LabUI.icon_button("remove", "Remove", func() -> void:
		row.get_parent().remove_child(row)
		row.queue_free()
		_save()))


func _move(row: Control, by: int) -> void:
	var list := row.get_parent()
	var to := clampi(row.get_index() + by, 0, list.get_child_count() - 1)
	if to != row.get_index():
		list.move_child(row, to)
		_save()


# --- Building

func _build() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SETTLE_SECONDS
	_settle.timeout.connect(_save)
	add_child(_settle)
	add_child(_left())
	add_child(_right())


func _left() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(LabUI.label("Problems", 22))
	var about := LabUI.label("What can be wrong with a customer's computer. An errand picks one; CompuFunDB and the post-it show its text.", 13, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var add := HBoxContainer.new()
	box.add_child(add)
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "New problem, such as Haunted printer"
	_new_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_name.text_submitted.connect(func(_t: String) -> void: _add_new())
	add.add_child(_new_name)
	add.add_child(LabUI.button("+  Problem", _add_new))
	_new_error = LabUI.label("", 13, LabUI.BAD)
	_new_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_new_error)
	return panel


func _right() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack := Control.new()
	panel.add_child(stack)
	_empty = LabUI.label("No problems yet: name one on the left.", 16, LabUI.DIM)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(_empty)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	_form = scroll
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_right", 14)
	scroll.add_child(inset)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	inset.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	_title = LabUI.label("", 24)
	head.add_child(_title)
	_built_slot = HBoxContainer.new()
	_built_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_built_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_built_slot)
	_remove = LabUI.button("Remove problem", _arm_remove, &"FlatButton")
	head.add_child(_remove)
	box.add_child(_heading("Post-it", "What the customer says is wrong. The post-it on their computer shows it."))
	_post_it = LineEdit.new()
	_post_it.placeholder_text = "Such as: Windows starts and turns off"
	_post_it.text_changed.connect(func(_t: String) -> void: _changed())
	box.add_child(_post_it)
	box.add_child(_heading("Symptoms", "What the customer or the player notices, and how it shows in the game. The player searches CompuFunDB for these words; problems that look alike share them."))
	box.add_child(_columns("The symptom", "How it shows in the game"))
	_symptoms = _rows(box)
	box.add_child(_add_button("+  Symptom", func() -> void: _add_symptom()))
	_warning = LabUI.label("", 13, LabUI.CHANGED)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_warning)
	box.add_child(_heading("Checks", "What a technician verifies on a working computer, such as \"Boots from C:\", and how it fails in the game. CompuFunDB lists the checks of every problem with the symptom searched for, among checks of other problems; the player marks those that fail, and only this problem's checks show its fix. The cause goes in the steps."))
	box.add_child(_columns("The check", "How it fails in the game"))
	_checks = _rows(box)
	box.add_child(_add_button("+  Check", func() -> void: _add_check()))
	box.add_child(_heading("Hardware steps", "What the player does inside the computer, in order, as CompuFunDB prints it."))
	_hardware = _rows(box)
	box.add_child(_add_button("+  Hardware step", func() -> void: _add_step(_hardware)))
	box.add_child(_heading("Software steps", "What the player does in Windows, in order."))
	_software = _rows(box)
	box.add_child(_add_button("+  Software step", func() -> void: _add_step(_software)))
	box.add_child(_heading("Notes", "For people: the story behind the problem, open questions. The game doesn't show them."))
	_notes = TextEdit.new()
	_notes.custom_minimum_size.y = 110
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_notes.text_changed.connect(_changed)
	box.add_child(_notes)
	_errors = LabUI.label("", 13, LabUI.BAD)
	_errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_errors)
	_form.hide()
	return panel


func _columns(what_title: String, how_title: String) -> Control:
	var columns := HBoxContainer.new()
	var what := LabUI.label(what_title, 13, LabUI.DIM)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(what)
	var how := LabUI.label(how_title, 13, LabUI.DIM)
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.size_flags_stretch_ratio = 1.6
	columns.add_child(how)
	var room := Control.new()
	room.custom_minimum_size.x = 102
	columns.add_child(room)
	return columns


func _heading(title: String, hint: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(LabUI.label(title, 16))
	var about := LabUI.label(hint, 13, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	return box


func _rows(into: Control) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	into.add_child(rows)
	return rows


func _add_button(text: String, pressed: Callable) -> Button:
	var made := LabUI.button(text, pressed, &"FlatButton")
	made.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return made
