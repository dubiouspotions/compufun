@tool
extends VBoxContainer
## The Dialogue tab: every customer in customers/, its conversations and their lines, in one
## place. Edits change the loaded Customer resources, the same ones the inspector shows, and
## Save (or Ctrl+S) writes them back. Play says a line in the customer's voice and the mood of its
## pose, and renders the voice file first if it is missing.

const CUSTOMERS_DIR := "res://customers/"
const ERROR_COLOR := Color(1.0, 0.45, 0.45)
const VOICES: Array[String] = ["male", "female", "child"]

var _customers: Array[Customer] = []
var _customer: Customer
var _conversation: Conversation
## The paths of the customers with unsaved edits.
var _dirty: Dictionary[String, bool] = {}

var _status: Label
var _customer_list: ItemList
var _new_customer: LineEdit
var _name_edit: LineEdit
var _voice_picker: OptionButton
var _preview: AudioStreamPlayer
var _conversation_list: ItemList
var _new_conversation: LineEdit
var _detail: VBoxContainer


func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	var bar := HBoxContainer.new()
	add_child(bar)
	bar.add_child(_button("Save", save_all))
	bar.add_child(_button("Reload list", refresh))
	_status = Label.new()
	bar.add_child(_status)

	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)

	var left := _column(split, 220)
	left.add_child(_label("Customers"))
	_customer_list = _item_list(left)
	_customer_list.item_selected.connect(_on_customer_selected)
	_new_customer = _input_row(left, "new_file_name", "New customer", _create_customer)

	var middle := _column(split, 260)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name in the game"
	_name_edit.text_changed.connect(_on_name_changed)
	middle.add_child(_name_edit)
	var voice_row := HBoxContainer.new()
	middle.add_child(voice_row)
	voice_row.add_child(_label("Voice"))
	_voice_picker = OptionButton.new()
	_voice_picker.size_flags_horizontal = SIZE_EXPAND_FILL
	for voice: String in VOICES:
		_voice_picker.add_item(voice)
	_voice_picker.item_selected.connect(_on_voice_selected)
	voice_row.add_child(_voice_picker)
	middle.add_child(_button("Person, problem: open in inspector", _open_in_inspector))
	middle.add_child(_label("Conversations: the first that matches plays"))
	_conversation_list = _item_list(middle)
	_conversation_list.item_selected.connect(_on_conversation_selected)
	_new_conversation = _input_row(middle, "id, for example arrive", "Add", _add_conversation)
	var order := HBoxContainer.new()
	middle.add_child(order)
	order.add_child(_button("Up", _move_conversation.bind(-1)))
	order.add_child(_button("Down", _move_conversation.bind(1)))
	order.add_child(_button("Delete", _delete_conversation))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	_preview = AudioStreamPlayer.new()
	add_child(_preview)
	refresh()


## Re-reads the customer files in customers/ and keeps the current selection.
func refresh() -> void:
	if _customer_list == null:
		return
	var selected_path := _customer.resource_path if _customer != null else ""
	_customers.clear()
	_customer_list.clear()
	var dir := DirAccess.open(CUSTOMERS_DIR)
	if dir == null:
		_fail("Couldn't open %s: %s" % [CUSTOMERS_DIR, error_string(DirAccess.get_open_error())])
		return
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var path := CUSTOMERS_DIR + file
		var customer := load(path) as Customer
		if customer == null:
			_fail("%s is not a Customer, or doesn't load" % path)
			continue
		_customers.append(customer)
		_customer_list.add_item(_customer_label(customer))
	var index := _customers.find_custom(func(c: Customer) -> bool: return c.resource_path == selected_path)
	if index >= 0:
		_customer_list.select(index)
	_select_customer(index)


## Saves every customer with unsaved edits, and reads each file back to check it.
func save_all() -> void:
	for path: String in _dirty.keys():
		var customer: Customer = load(path)
		_save(customer)


## A message for the editor to show on quit while there are unsaved edits, or "".
func unsaved_status() -> String:
	if _dirty.is_empty():
		return ""
	return "Save the dialogue of %s?" % ", ".join(_dirty.keys())


func _save(customer: Customer) -> bool:
	var path := customer.resource_path
	var invalid := _validate(customer)
	if invalid != "":
		_fail("Didn't save %s: %s" % [path, invalid])
		return false
	var err := ResourceSaver.save(customer, path)
	if err != OK:
		_fail("Couldn't save %s: %s" % [path, error_string(err)])
		return false
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Customer
	if back == null or _summary(back) != _summary(customer):
		_fail("Saved %s, but the file reads back different" % path)
		return false
	_dirty.erase(path)
	EditorInterface.get_resource_filesystem().update_file(path)
	_show_status("Saved " + path)
	return true


## Why [param customer] can't be saved, or "" if it can.
func _validate(customer: Customer) -> String:
	var seen: Dictionary[StringName, bool] = {}
	for c: Conversation in customer.conversations:
		if c == null:
			return "an empty conversation slot"
		if c.id == &"":
			return "a conversation has no id"
		if seen.has(c.id):
			return "two conversations have the id '%s'" % c.id
		seen[c.id] = true
	return ""


## The text content of [param customer] as one string, to compare a save with its read-back.
func _summary(customer: Customer) -> String:
	var conversations: Array = []
	for c: Conversation in customer.conversations:
		var lines: Array = []
		for line: DialogueLine in c.lines:
			lines.append([line.text, line.pose] if line != null else null)
		var when: Array = [c.when.from_day, c.when.to_day, c.when.need_flags, c.when.not_flags] if c.when != null else []
		conversations.append([c.id, c.trigger, c.once, when, lines])
	return var_to_str([customer.display_name, customer.voice, conversations])


func _create_customer(file_name: String) -> void:
	var regex := RegEx.create_from_string("^[a-z0-9_]+$")
	if regex.search(file_name) == null:
		_fail("A file name is lowercase letters, digits and _, not '%s'" % file_name)
		return
	var path := CUSTOMERS_DIR + file_name + ".tres"
	if FileAccess.file_exists(path):
		_fail("%s already exists; it was not overwritten" % path)
		return
	var customer := Customer.new()
	customer.display_name = file_name.capitalize()
	var conversation := Conversation.new()
	conversation.id = &"arrive"
	conversation.lines = [DialogueLine.new()]
	customer.conversations = [conversation]
	var err := ResourceSaver.save(customer, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		_fail("Couldn't create %s: %s" % [path, error_string(err)])
		return
	EditorInterface.get_resource_filesystem().update_file(path)
	_new_customer.clear()
	_customer = customer
	refresh()
	_show_status("Created %s. Set its person and problem in the inspector." % path)


func _on_customer_selected(index: int) -> void:
	_select_customer(index)


func _select_customer(index: int) -> void:
	_customer = _customers[index] if index >= 0 else null
	_name_edit.editable = _customer != null
	_name_edit.text = _customer.display_name if _customer != null else ""
	_voice_picker.disabled = _customer == null
	if _customer != null:
		_voice_picker.select(VOICES.find(_customer.voice))
	_conversation_list.clear()
	if _customer == null:
		_select_conversation(-1)
		return
	for c: Conversation in _customer.conversations:
		_conversation_list.add_item(_conversation_label(c))
	var keep := _customer.conversations.find(_conversation)
	if keep < 0 and not _customer.conversations.is_empty():
		keep = 0
	if keep >= 0:
		_conversation_list.select(keep)
	_select_conversation(keep)


func _on_name_changed(text: String) -> void:
	if _customer == null:
		return
	_customer.display_name = text
	_customer_list.set_item_text(_customers.find(_customer), _customer_label(_customer))
	_touch()


func _on_voice_selected(index: int) -> void:
	if _customer == null:
		return
	_customer.voice = VOICES[index]
	_touch()


## Says [param line] in the customer's voice. A missing voice file is rendered first, which needs
## Chimera's path in Editor Settings > Humanerror > Voices.
func _play_line(line: DialogueLine) -> void:
	if line.text.strip_edges().is_empty():
		_fail("The line has no text to say")
		return
	var path := Voices.path_of(line, _customer.voice)
	if not FileAccess.file_exists(path):
		var chimera: String = EditorInterface.get_editor_settings().get_setting(Voices.CHIMERA_SETTING)
		var problem := Voices.chimera_problem(chimera)
		if problem == "":
			problem = Voices.render(line, _customer.voice, chimera)
		if problem != "":
			_fail(problem)
			return
		EditorInterface.get_resource_filesystem().scan()
	var stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
	if stream == null:
		_fail("Couldn't read the voice file %s" % path)
		return
	_preview.stream = stream
	_preview.play()
	_show_status("Playing %s (%s, %s)" % [path.get_file(), _customer.voice, line.pose])


func _open_in_inspector() -> void:
	if _customer != null:
		EditorInterface.edit_resource(_customer)


func _add_conversation(id: String) -> void:
	if _customer == null:
		_fail("Pick a customer first")
		return
	if id == "" or _customer.conversation(StringName(id)) != null:
		_fail("'%s' is empty or already a conversation of %s" % [id, _customer.resource_path])
		return
	var conversation := Conversation.new()
	conversation.id = StringName(id)
	conversation.lines = [DialogueLine.new()]
	_customer.conversations.append(conversation)
	_new_conversation.clear()
	_conversation = conversation
	_touch()
	_select_customer(_customers.find(_customer))


func _move_conversation(step: int) -> void:
	if _customer == null or _conversation == null:
		return
	var index := _customer.conversations.find(_conversation)
	var to := index + step
	if to < 0 or to >= _customer.conversations.size():
		return
	_customer.conversations[index] = _customer.conversations[to]
	_customer.conversations[to] = _conversation
	_touch()
	_select_customer(_customers.find(_customer))


func _delete_conversation() -> void:
	if _customer == null or _conversation == null:
		return
	_customer.conversations.erase(_conversation)
	_conversation = null
	_touch()
	_select_customer(_customers.find(_customer))


func _on_conversation_selected(index: int) -> void:
	_select_conversation(index)


func _select_conversation(index: int) -> void:
	_conversation = _customer.conversations[index] if _customer != null and index >= 0 else null
	_render_detail()


func _render_detail() -> void:
	for child: Node in _detail.get_children():
		child.queue_free()
	if _conversation == null:
		_detail.add_child(_label("Pick a conversation."))
		return

	var id_row := HBoxContainer.new()
	_detail.add_child(id_row)
	id_row.add_child(_label("Id"))
	var id_edit := LineEdit.new()
	id_edit.text = _conversation.id
	id_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	id_edit.text_changed.connect(_on_id_changed)
	id_row.add_child(id_edit)
	_render_when()

	_detail.add_child(_label("Lines (the customer says them in this order)"))
	for i: int in _conversation.lines.size():
		_detail.add_child(_line_row(i))
	_detail.add_child(_button("Add line", _add_line))


## The trigger, once, and the condition of the conversation. A condition is made on the first edit.
func _render_when() -> void:
	var c := _conversation
	var when := c.when if c.when != null else Condition.new()
	var row := HBoxContainer.new()
	_detail.add_child(row)
	row.add_child(_label("Plays on"))
	var trigger := OptionButton.new()
	for key: String in Conversation.Trigger.keys():
		trigger.add_item(key)
	trigger.select(c.trigger)
	trigger.item_selected.connect(func(index: int) -> void:
		c.trigger = index as Conversation.Trigger
		_changed_when())
	row.add_child(trigger)
	var once := CheckBox.new()
	once.text = "Only once"
	once.button_pressed = c.once
	once.toggled.connect(func(on: bool) -> void:
		c.once = on
		_changed_when())
	row.add_child(once)

	var days := HBoxContainer.new()
	_detail.add_child(days)
	days.add_child(_label("Days"))
	for field: String in ["from_day", "to_day"]:
		var box := SpinBox.new()
		box.min_value = 1
		box.max_value = 7
		box.value = when.get(field)
		box.value_changed.connect(func(value: float) -> void:
			_condition().set(field, int(value))
			_changed_when())
		days.add_child(box)

	for field: String in ["need_flags", "not_flags"]:
		var flags_row := HBoxContainer.new()
		_detail.add_child(flags_row)
		flags_row.add_child(_label("Needs flags" if field == "need_flags" else "Not with flags"))
		var edit := LineEdit.new()
		edit.placeholder_text = "flag_a, flag_b"
		edit.size_flags_horizontal = SIZE_EXPAND_FILL
		edit.text = ", ".join(PackedStringArray(when.get(field)))
		edit.text_changed.connect(func(text: String) -> void:
			var names: Array[StringName] = []
			for part: String in text.split(",", false):
				if part.strip_edges() != "":
					names.append(StringName(part.strip_edges()))
			_condition().set(field, names)
			_changed_when())
		flags_row.add_child(edit)


func _condition() -> Condition:
	if _conversation.when == null:
		_conversation.when = Condition.new()
	return _conversation.when


func _changed_when() -> void:
	_conversation_list.set_item_text(_customer.conversations.find(_conversation), _conversation_label(_conversation))
	_touch()


## The id and when it plays, for the conversation list.
func _conversation_label(c: Conversation) -> String:
	if c == null:
		return "(empty)"
	var parts: PackedStringArray = [Conversation.Trigger.keys()[c.trigger]]
	if c.when != null:
		if c.when.from_day != 1 or c.when.to_day != 7:
			parts.append("day %d-%d" % [c.when.from_day, c.when.to_day])
		for flag: StringName in c.when.need_flags:
			parts.append(String(flag))
		for flag: StringName in c.when.not_flags:
			parts.append("not " + String(flag))
	if c.once:
		parts.append("once")
	return "%s  (%s)" % [c.id, ", ".join(parts)]


func _line_row(index: int) -> Control:
	var line := _conversation.lines[index]
	if line == null:
		line = DialogueLine.new()
		_conversation.lines[index] = line
	var row := HBoxContainer.new()
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 160
	row.add_child(side)
	side.add_child(_pose_picker(line))
	var buttons := HBoxContainer.new()
	side.add_child(buttons)
	buttons.add_child(_button("Play", _play_line.bind(line)))
	buttons.add_child(_button("Up", _move_line.bind(index, -1)))
	buttons.add_child(_button("Down", _move_line.bind(index, 1)))
	buttons.add_child(_button("X", _remove_line.bind(index)))
	var text := TextEdit.new()
	text.text = line.text
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size.y = 64
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.text_changed.connect(func() -> void:
		line.text = text.text
		_touch())
	row.add_child(text)
	return row


## A dropdown of [constant Person.POSES], marking those the customer's person has no portrait
## for. A pose outside the list stays selected and is marked unknown, never dropped silently.
func _pose_picker(line: DialogueLine) -> OptionButton:
	var poses := Person.POSES.duplicate()
	if not poses.has(line.pose):
		poses.append(line.pose)
	var picker := OptionButton.new()
	for pose: StringName in poses:
		var text := String(pose)
		if not Person.POSES.has(pose):
			text += " (unknown)"
		elif _customer.person == null or not _customer.person.portraits.has(pose):
			text += " (no photo)"
		picker.add_item(text)
	picker.select(poses.find(line.pose))
	picker.item_selected.connect(func(index: int) -> void:
		line.pose = poses[index]
		_touch())
	return picker


func _on_id_changed(text: String) -> void:
	_conversation.id = StringName(text)
	_conversation_list.set_item_text(_customer.conversations.find(_conversation), _conversation_label(_conversation))
	_touch()


func _add_line() -> void:
	_conversation.lines.append(DialogueLine.new())
	_touch()
	_render_detail()


func _move_line(index: int, step: int) -> void:
	var to := index + step
	if to < 0 or to >= _conversation.lines.size():
		return
	var line := _conversation.lines[index]
	_conversation.lines[index] = _conversation.lines[to]
	_conversation.lines[to] = line
	_touch()
	_render_detail()


func _remove_line(index: int) -> void:
	_conversation.lines.remove_at(index)
	_touch()
	_render_detail()


func _touch() -> void:
	_dirty[_customer.resource_path] = true
	_customer.emit_changed()
	_show_status("Unsaved: %s" % ", ".join(_dirty.keys()))


func _customer_label(customer: Customer) -> String:
	return "%s (%s)" % [customer.display_name, customer.resource_path.get_file()]


func _show_status(text: String) -> void:
	_status.text = text
	_status.remove_theme_color_override(&"font_color")


func _fail(message: String) -> void:
	push_error("Dialogue editor: " + message)
	_status.text = message
	_status.add_theme_color_override(&"font_color", ERROR_COLOR)


func _column(parent: Control, width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	parent.add_child(column)
	return column


func _item_list(parent: Control) -> ItemList:
	var list := ItemList.new()
	list.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(list)
	return list


## A LineEdit with a button; the button and Enter call [param action] with the trimmed text.
func _input_row(parent: Control, placeholder: String, label: String, action: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(text: String) -> void: action.call(text.strip_edges()))
	row.add_child(edit)
	row.add_child(_button(label, func() -> void: action.call(edit.text.strip_edges())))
	return edit


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button
