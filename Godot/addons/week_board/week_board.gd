@tool
extends VBoxContainer
## The Week tab: a column per Day with its warp and its customers in order, and below, every flag
## with the conversations that set it and the conversations and corruption signs that check it.
## Edits change the loaded Day resources; Save (or Ctrl+S) writes them back. It stores nothing of
## its own: the days, customers and signs are the data.

const DialogueEditor := preload("res://addons/dialogue_editor/dialogue_editor.gd")
const GAME := preload("res://game.gd")
const SIGNS_DIR := "res://corruption/"
const ERROR_COLOR := Color(1.0, 0.45, 0.45)
const WARN_COLOR := Color(1.0, 0.8, 0.4)
const DIM_COLOR := Color(0.6, 0.6, 0.65)

var _days: Array[Day] = []
var _customers: Array[Customer] = []
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
	help.text = "Drag customers to reorder them or move them to another day. Double-click one to open it in the Dialogue tab."
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
	_days.clear()
	for number: int in range(1, 8):
		var path := GAME.DAY_PATH % number
		if not ResourceLoader.exists(path):
			continue
		var d := load(path) as Day
		if d == null:
			errors.append("%s is not a Day, or doesn't load" % path)
			continue
		_days.append(d)
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

	var list := ItemList.new()
	list.custom_minimum_size.y = 150
	list.size_flags_vertical = SIZE_EXPAND_FILL
	list.max_text_lines = 2
	list.auto_height = false
	for c: Customer in d.customers:
		_add_customer_item(list, c)
	list.item_activated.connect(func(index: int) -> void: _open_in_dialogue(d.customers[index]))
	list.set_drag_forwarding(
		func(at: Vector2) -> Variant: return _drag_data(list, d, at),
		func(_at: Vector2, data: Variant) -> bool: return _can_drop(d, data),
		func(at: Vector2, data: Variant) -> void: _drop(list, d, at, data))
	column.add_child(list)

	var add := OptionButton.new()
	add.add_item("Add customer...")
	for c: Customer in _customers:
		add.add_item(_customer_name(c))
	add.disabled = d.customers.size() >= Day.MAX_CUSTOMERS
	add.item_selected.connect(func(index: int) -> void:
		if index > 0:
			d.customers.append(_customers[index - 1])
			_touch(d, true))
	column.add_child(add)
	column.add_child(_button("Remove selected", func() -> void:
		var picked := list.get_selected_items()
		if picked.is_empty():
			return
		d.customers.remove_at(picked[0])
		_touch(d, true)))

	var invalid := Day.why_unplayable(d)
	if invalid != "":
		var warning := _label(invalid)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.add_theme_color_override(&"font_color", ERROR_COLOR)
		column.add_child(warning)
	return column


func _add_customer_item(list: ItemList, c: Customer) -> void:
	if c == null:
		var index := list.add_item("(empty slot)")
		list.set_item_custom_fg_color(index, ERROR_COLOR)
		return
	var problem := String(c.problem.short_name) if c.problem != null else "NO PROBLEM"
	var index := list.add_item("%s\n  %s" % [_customer_name(c), problem])
	var tip: PackedStringArray = [c.resource_path]
	if c.problem != null:
		tip.append("Post-it: " + c.problem.perceived_issue)
	for conversation: Conversation in c.conversations:
		if conversation != null:
			tip.append(DialogueEditor.conversation_label(conversation))
	list.set_item_tooltip(index, "\n".join(tip))
	if c.problem == null:
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
	return data["week_day"] == d or d.customers.size() < Day.MAX_CUSTOMERS


func _drop(list: ItemList, d: Day, at: Vector2, data: Variant) -> void:
	var from: Day = data["week_day"]
	var index: int = data["index"]
	var c: Customer = from.customers[index]
	from.customers.remove_at(index)
	var to := list.get_item_at_position(at, true)
	if from == d and to > index:
		to -= 1
	if to < 0 or to > d.customers.size():
		to = d.customers.size()
	d.customers.insert(to, c)
	_dirty[from.resource_path] = true
	_touch(d, true)


## Marks [param d] unsaved; [param redraw] draws the board again for a change to its customers.
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
	var setters: Dictionary[StringName, PackedStringArray] = {}
	var checkers: Dictionary[StringName, PackedStringArray] = {}
	for c: Customer in _customers:
		var who := c.resource_path.get_file().get_basename()
		for conversation: Conversation in c.conversations:
			if conversation == null:
				continue
			var where := "%s/%s" % [who, conversation.id]
			for flag: StringName in conversation.set_flags:
				var value: int = conversation.set_flags[flag]
				_note(setters, flag, where if value == 1 else "%s =%d" % [where, value])
			if conversation.when == null:
				continue
			for flag: StringName in conversation.when.need_flags:
				_note(checkers, flag, where)
			for flag: StringName in conversation.when.not_flags:
				_note(checkers, flag, where + " (not)")
	var signs := _sign_titles()
	for flag: StringName in signs:
		_note(checkers, flag, "sign: " + signs[flag])

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
			row.set_text(1, "F2 Signs tab only" if signs.has(flag) else "no conversation sets it")
			row.set_custom_color(1, DIM_COLOR if signs.has(flag) else WARN_COLOR)
		if not checkers.has(flag):
			row.set_text(2, "nothing checks it")
			row.set_custom_color(2, WARN_COLOR)


func _note(notes: Dictionary[StringName, PackedStringArray], flag: StringName, where: String) -> void:
	if not notes.has(flag):
		notes[flag] = PackedStringArray()
	notes[flag].append(where)


## The flag of every corruption sign scene, sign_<id>, to its title, read without instancing it.
func _sign_titles() -> Dictionary[StringName, String]:
	var titles: Dictionary[StringName, String] = {}
	var dir := DirAccess.open(SIGNS_DIR)
	if dir == null:
		_fail("Couldn't open %s: %s" % [SIGNS_DIR, error_string(DirAccess.get_open_error())])
		return titles
	for file: String in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var scene := load(SIGNS_DIR + file) as PackedScene
		if scene == null:
			_fail("%s doesn't load" % (SIGNS_DIR + file))
			continue
		var state := scene.get_state()
		var title := file.get_basename()
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"title":
				title = state.get_node_property_value(0, i)
		titles[StringName("sign_" + file.get_basename())] = title
	return titles


func _summary(d: Day) -> String:
	return var_to_str([d.number, d.warp, d.customers.map(func(c: Customer) -> String: return c.resource_path if c != null else "")])


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
