@tool
extends VBoxContainer
## The Week tab: a column per Day with its warp, the flags it sets and its errands in order, and below, every flag
## with the conversations that set it and the conversations and corruption signs that check it.
## Edits change the loaded Day resources; Save (or Ctrl+S) writes them back. It stores nothing of
## its own: the days, errands, customers and signs are the data.

const DialogueEditor := preload("res://addons/dialogue_editor/dialogue_editor.gd")
const GAME := preload("res://game.gd")
const PROBLEMS_DIR := "res://problems/"
const ERROR_COLOR := Color(1.0, 0.45, 0.45)
const WARN_COLOR := Color(1.0, 0.8, 0.4)
const DIM_COLOR := Color(0.6, 0.6, 0.65)

var _days: Array[Day] = []
var _customers: Array[Customer] = []
var _problems: Array[Problem] = []
## The paths of the days with unsaved edits.
var _dirty: Dictionary[String, bool] = {}

var _status: Label
var _columns: HBoxContainer
var _flags: Tree


func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	var bar := HBoxContainer.new()
	add_child(bar)
	bar.add_child(_button("Save", save_all))
	bar.add_child(_button("Reload", refresh))
	var help := Label.new()
	help.text = "Drag errands to reorder them or move them to another day. Double-click one to open it in the Dialogue tab."
	help.add_theme_color_override(&"font_color", DIM_COLOR)
	bar.add_child(help)
	_status = Label.new()
	bar.add_child(_status)

	var split := VSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 260
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_columns = HBoxContainer.new()
	_columns.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.add_child(_columns)

	_flags = Tree.new()
	_flags.size_flags_vertical = SIZE_EXPAND_FILL
	_flags.columns = 3
	_flags.column_titles_visible = true
	_flags.hide_root = true
	for i: int in 3:
		_flags.set_column_title(i, ["Flag", "Set by", "Checked by"][i])
		_flags.set_column_expand(i, true)
	split.add_child(_flags)
	refresh()


## Re-reads the days, the customers and the signs, and draws them again. Unsaved edits stay: they
## are on the loaded resources.
func refresh() -> void:
	if _columns == null:
		return
	_show_status("Unsaved: " + ", ".join(PackedStringArray(_dirty.keys())) if not _dirty.is_empty() else "")
	var errors: Array[String] = []
	_customers = DialogueEditor.load_customers(errors)
	_problems = _load_problems(errors)
	_days = FlagField.load_days(errors)
	for error: String in errors:
		_fail(error)
	for child: Node in _columns.get_children():
		child.queue_free()
	for d: Day in _days:
		_columns.add_child(_day_column(d))
	_fill_flags()


## Saves every day with unsaved edits, and reads each file back to check it.
func save_all() -> void:
	var saved := 0
	for path: String in _dirty.keys():
		var d := load(path) as Day
		var err := ResourceSaver.save(d, path)
		if err != OK:
			_fail("Couldn't save %s: %s" % [path, error_string(err)])
			continue
		var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Day
		if back == null or _summary(back) != _summary(d):
			_fail("%s didn't read back as saved" % path)
			continue
		_dirty.erase(path)
		saved += 1
	if saved > 0 and _dirty.is_empty():
		_show_status("Saved %d day(s)." % saved)


## A message for the editor to show on quit while there are unsaved edits, or "".
func unsaved_status() -> String:
	if _dirty.is_empty():
		return ""
	return "Save the days %s?" % ", ".join(PackedStringArray(_dirty.keys()))


func _day_column(d: Day) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 210
	column.add_child(_label("Day %d%s" % [d.number, " *" if _dirty.has(d.resource_path) else ""]))

	var warp_row := HBoxContainer.new()
	column.add_child(warp_row)
	warp_row.add_child(_label("Warp"))
	var warp := SpinBox.new()
	warp.max_value = 1.0
	warp.step = 0.05
	warp.value = d.warp
	warp.value_changed.connect(func(value: float) -> void:
		d.warp = value
		_touch(d, false))
	warp_row.add_child(warp)

	var sets := FlagField.new(DialogueEditor.flags_text(d.set_flags), "Sets flags at start: sign_x, flag=2", _offers)
	sets.tooltip_text = "The flags that the day sets as it starts: name, or name=number; 0 clears it."
	sets.edited.connect(func(text: String) -> void:
		var parsed: Variant = DialogueEditor.parse_flags(text)
		if parsed is String:
			_show_status("Day %d flags not changed: %s" % [d.number, parsed])
			return
		d.set_flags = parsed
		_touch(d, false))
	# The flag table follows when the field is left, so typing keeps its focus.
	sets.edit.focus_exited.connect(_fill_flags)
	column.add_child(sets)

	var list := ItemList.new()
	list.custom_minimum_size.y = 150
	list.size_flags_vertical = SIZE_EXPAND_FILL
	list.max_text_lines = 2
	list.auto_height = false
	for each: Errand in d.errands:
		_add_errand_item(list, each)
	list.item_activated.connect(func(index: int) -> void: _open_in_dialogue(d.errands[index].customer if d.errands[index] != null else null))
	list.set_drag_forwarding(
		func(at: Vector2) -> Variant: return _drag_data(list, d, at),
		func(_at: Vector2, data: Variant) -> bool: return _can_drop(d, data),
		func(at: Vector2, data: Variant) -> void: _drop(list, d, at, data))
	column.add_child(list)

	var problem := OptionButton.new()
	problem.add_item("Problem of the selected...")
	for each: Problem in _problems:
		problem.add_item(String(each.short_name))
	problem.disabled = true
	list.item_selected.connect(func(index: int) -> void:
		var picked := d.errands[index]
		problem.disabled = picked == null
		problem.select(_problems.find(picked.problem) + 1 if picked != null else 0))
	problem.item_selected.connect(func(index: int) -> void:
		var picked := list.get_selected_items()
		if index > 0 and not picked.is_empty() and d.errands[picked[0]] != null:
			d.errands[picked[0]].problem = _problems[index - 1]
			_touch(d, true))
	column.add_child(problem)

	var add := OptionButton.new()
	add.add_item("Add customer...")
	for c: Customer in _customers:
		add.add_item(_customer_name(c))
	add.disabled = d.errands.size() >= GAME.MAX_CUSTOMERS
	add.item_selected.connect(func(index: int) -> void:
		if index > 0:
			var each := Errand.new()
			each.customer = _customers[index - 1]
			d.errands.append(each)
			_touch(d, true))
	column.add_child(add)
	column.add_child(_button("Remove selected", func() -> void:
		var picked := list.get_selected_items()
		if picked.is_empty():
			return
		d.errands.remove_at(picked[0])
		_touch(d, true)))

	var invalid := GAME.check_day(d)
	if invalid != "":
		var warning := _label(invalid)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.add_theme_color_override(&"font_color", ERROR_COLOR)
		column.add_child(warning)
	return column


func _add_errand_item(list: ItemList, each: Errand) -> void:
	if each == null or each.customer == null:
		var empty := list.add_item("(no customer)")
		list.set_item_custom_fg_color(empty, ERROR_COLOR)
		return
	var c := each.customer
	var problem := String(each.problem.short_name) if each.problem != null else "pick a problem"
	var index := list.add_item("%s\n  %s" % [_customer_name(c), problem])
	var tip: PackedStringArray = [c.resource_path]
	if each.problem != null:
		tip.append("Post-it: " + each.problem.perceived_issue)
	for conversation: Conversation in c.conversations:
		if conversation != null:
			tip.append(DialogueEditor.conversation_label(conversation))
	list.set_item_tooltip(index, "\n".join(tip))
	if each.problem == null:
		list.set_item_custom_fg_color(index, ERROR_COLOR)


func _drag_data(list: ItemList, d: Day, at: Vector2) -> Variant:
	var index := list.get_item_at_position(at, true)
	if index < 0:
		return null
	list.set_drag_preview(_label(list.get_item_text(index).get_slice("\n", 0)))
	return {"week_day": d, "index": index}


func _can_drop(d: Day, data: Variant) -> bool:
	if not data is Dictionary or not data.has("week_day"):
		return false
	return data["week_day"] == d or d.errands.size() < GAME.MAX_CUSTOMERS


func _drop(list: ItemList, d: Day, at: Vector2, data: Variant) -> void:
	var from: Day = data["week_day"]
	var index: int = data["index"]
	var moved: Errand = from.errands[index]
	from.errands.remove_at(index)
	if from != d:
		# A copy: the original belongs to the other day's file.
		moved = moved.duplicate()
	var to := list.get_item_at_position(at, true)
	if from == d and to > index:
		to -= 1
	if to < 0 or to > d.errands.size():
		to = d.errands.size()
	d.errands.insert(to, moved)
	_dirty[from.resource_path] = true
	_touch(d, true)


## Marks [param d] unsaved; [param redraw] draws the board again for a change to its errands.
func _touch(d: Day, redraw: bool) -> void:
	_dirty[d.resource_path] = true
	_show_status("Unsaved: " + ", ".join(PackedStringArray(_dirty.keys())))
	if redraw:
		# Deferred: the edit can come from a signal of a control that the redraw frees.
		refresh.call_deferred()


func _open_in_dialogue(c: Customer) -> void:
	if c == null:
		return
	var dialogue := get_tree().get_first_node_in_group(DialogueEditor.GROUP) as DialogueEditor
	if dialogue == null:
		_fail("The Dialogue tab is not open: enable the Dialogue editor plugin")
		return
	EditorInterface.set_main_screen_editor("Dialogue")
	dialogue.show_customer(c.resource_path)


## Lists every flag that a conversation sets or checks, and the flag of every corruption sign.
func _fill_flags() -> void:
	_flags.clear()
	var errors: Array[String] = []
	var flag_index := FlagField.index(_customers, _days, errors)
	for error: String in errors:
		_fail(error)
	var setters: Dictionary = flag_index["setters"]
	var checkers: Dictionary = flag_index["checkers"]
	var signs: Dictionary = flag_index["signs"]

	var names: Array[StringName] = []
	for flag: StringName in setters.keys() + checkers.keys():
		if flag not in names:
			names.append(flag)
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var root := _flags.create_item()
	for flag: StringName in names:
		var row := _flags.create_item(root)
		row.set_text(0, flag)
		row.set_text(1, ", ".join(setters.get(flag, PackedStringArray())))
		row.set_text(2, ", ".join(checkers.get(flag, PackedStringArray())))
		if not setters.has(flag):
			row.set_text(1, "F2 Signs tab only" if signs.has(flag) else "nothing sets it")
			row.set_custom_color(1, DIM_COLOR if signs.has(flag) else WARN_COLOR)
		if not checkers.has(flag):
			row.set_text(2, "nothing checks it")
			row.set_custom_color(2, WARN_COLOR)


## Every Problem in [constant PROBLEMS_DIR], by short name. Adds a message to [param errors] for each
## file that doesn't load as one.
func _load_problems(errors: Array[String]) -> Array[Problem]:
	var problems: Array[Problem] = []
	var dir := DirAccess.open(PROBLEMS_DIR)
	if dir == null:
		errors.append("Couldn't open %s: %s" % [PROBLEMS_DIR, error_string(DirAccess.get_open_error())])
		return problems
	for file: String in dir.get_files():
		if file.ends_with(".tres"):
			var problem := load(PROBLEMS_DIR + file) as Problem
			if problem == null:
				errors.append("%s is not a Problem, or doesn't load" % (PROBLEMS_DIR + file))
				continue
			problems.append(problem)
	problems.sort_custom(func(a: Problem, b: Problem) -> bool: return String(a.short_name) < String(b.short_name))
	return problems


## The flags that a FlagField offers, from the loaded days and customers.
func _offers() -> Dictionary:
	var errors: Array[String] = []
	var known := FlagField.offers(FlagField.index(_customers, _days, errors))
	for error: String in errors:
		_fail(error)
	return known


func _summary(d: Day) -> String:
	return var_to_str([d.number, d.warp, d.set_flags, d.errands.map(func(each: Errand) -> Array:
		return [each.customer.resource_path if each.customer != null else "", each.problem.resource_path if each.problem != null else ""] if each != null else [])])


func _customer_name(c: Customer) -> String:
	var spoken := c.spoken_name()
	return spoken if spoken != "" else c.resource_path.get_file().get_basename()


func _show_status(text: String) -> void:
	_status.text = text
	_status.remove_theme_color_override(&"font_color")


func _fail(message: String) -> void:
	push_error("Week board: " + message)
	_status.text = message
	_status.add_theme_color_override(&"font_color", ERROR_COLOR)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button
