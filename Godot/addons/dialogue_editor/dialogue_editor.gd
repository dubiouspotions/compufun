@tool
extends VBoxContainer
## The Dialogue tab: every customer in customers/, its conversations and their lines, in one
## place. Edits change the loaded Customer resources, the same ones the inspector shows, and
## Save (or Ctrl+S) writes them back. Play says a line in the customer's voice and the mood of its
## pose, and renders the voice file first if it is missing.

const CUSTOMERS_DIR := "res://customers/"
const ERROR_COLOR := Color(1.0, 0.45, 0.45)
## The group of the Dialogue tab, so another tab can call [method show_customer].
const GROUP := &"dialogue_editor"

var _customers: Array[Customer] = []
var _customer: Customer
var _conversation: Conversation
## The paths of the customers with unsaved edits.
var _dirty: Dictionary[String, bool] = {}
## People whose nickname was edited. Saved with the customer, because the nickname lives on the person.
var _dirty_people: Dictionary[String, Person] = {}

var _status: Label
var _customer_list: ItemList
var _new_customer: LineEdit
var _name_edit: LineEdit
var _voice_picker: OptionButton
## The voice persons that _voice_picker lists, in its order.
var _persons: Array[VoicePerson] = []
var _preview: AudioStreamPlayer
var _conversation_list: ItemList
var _new_conversation: LineEdit
## The conversation's tree: the conversation, the player's choices and the customer's replies.
var _tree: Tree
## The node of the tree that the editor below it shows: the conversation, a Choice or a Reply.
var _node: Resource
## Where the editor of [member _node] draws, under the tree.
var _node_box: VBoxContainer


func _ready() -> void:
	add_to_group(GROUP)
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
	_name_edit.placeholder_text = "Nickname"
	_name_edit.text_changed.connect(_on_name_changed)
	middle.add_child(_name_edit)
	var voice_row := HBoxContainer.new()
	middle.add_child(voice_row)
	voice_row.add_child(_label("Voice"))
	_voice_picker = OptionButton.new()
	_voice_picker.size_flags_horizontal = SIZE_EXPAND_FILL
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

	# The tree above the editor of its picked node; the bar between them drags.
	var right := VSplitContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	split.add_child(right)
	var tree_column := VBoxContainer.new()
	tree_column.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(tree_column)
	tree_column.add_child(_label("The conversation, the player's choices (>) and the customer's replies (-). Pick one to edit it."))
	_tree = Tree.new()
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.item_selected.connect(func() -> void:
		_node = _tree.get_selected().get_metadata(0)[0]
		_render_node())
	tree_column.add_child(_tree)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_node_box = VBoxContainer.new()
	_node_box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_node_box)
	_preview = AudioStreamPlayer.new()
	add_child(_preview)
	refresh()


## Re-reads the customer files in customers/ and keeps the current selection.
func refresh() -> void:
	if _customer_list == null:
		return
	var selected_path := _customer.resource_path if _customer != null else ""
	_customer_list.clear()
	var errors: Array[String] = []
	_customers = load_customers(errors)
	for error: String in errors:
		_fail(error)
	for customer: Customer in _customers:
		_customer_list.add_item(_customer_label(customer))
	var index := _customers.find_custom(func(c: Customer) -> bool: return c.resource_path == selected_path)
	if index >= 0:
		_customer_list.select(index)
	_select_customer(index)


## Shows the customer saved at [param path], as a click on it in the list does.
func show_customer(path: String) -> void:
	refresh()
	var index := _customers.find_custom(func(c: Customer) -> bool: return c.resource_path == path)
	if index < 0:
		_fail("%s is not in %s" % [path, CUSTOMERS_DIR])
		return
	_customer_list.select(index)
	_select_customer(index)


## Every Customer file in [constant CUSTOMERS_DIR]. Adds a message to [param errors] for each file
## that doesn't load as a Customer, and for a folder that doesn't open.
static func load_customers(errors: Array[String]) -> Array[Customer]:
	var customers: Array[Customer] = []
	var dir := DirAccess.open(CUSTOMERS_DIR)
	if dir == null:
		errors.append("Couldn't open %s: %s" % [CUSTOMERS_DIR, error_string(DirAccess.get_open_error())])
		return customers
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var customer := load(CUSTOMERS_DIR + file) as Customer
		if customer == null:
			errors.append("%s is not a Customer, or doesn't load" % (CUSTOMERS_DIR + file))
			continue
		customers.append(customer)
	return customers


## Saves every customer with unsaved edits, and reads each file back to check it.
func save_all() -> void:
	for path: String in _dirty.keys():
		var customer: Customer = load(path)
		_save(customer)


## A message for the editor to show on quit while there are unsaved edits, or "".
func unsaved_status() -> String:
	if _dirty.is_empty() and _dirty_people.is_empty():
		return ""
	var paths: Array[String] = []
	for path: String in _dirty.keys():
		paths.append(path)
	for path: String in _dirty_people.keys():
		if not paths.has(path):
			paths.append(path)
	return "Save the dialogue of %s?" % ", ".join(paths)


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
	var person := customer.person
	if person != null and _dirty_people.has(person.resource_path):
		if not _save_person(person):
			return false
	_show_status("Saved " + path)
	return true


func _save_person(person: Person) -> bool:
	var path := person.resource_path
	var err := ResourceSaver.save(person, path)
	if err != OK:
		_fail("Couldn't save %s: %s" % [path, error_string(err)])
		return false
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Person
	if back == null or back.nickname != person.nickname or back.name != person.name or back.email != person.email or back.voice != person.voice:
		_fail("Saved %s, but the file reads back different" % path)
		return false
	_dirty_people.erase(path)
	EditorInterface.get_resource_filesystem().update_file(path)
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
	return var_to_str([customer.display_name, customer.voice.resource_path if customer.voice != null else "", Story.outline(customer)])


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
	_name_edit.text = _customer.spoken_name() if _customer != null else ""
	_voice_picker.disabled = _customer == null or _customer.person == null
	if _customer != null:
		_fill_persons()
	_conversation_list.clear()
	if _customer == null:
		_select_conversation(-1)
		return
	for c: Conversation in _customer.conversations:
		_conversation_list.add_item(conversation_label(c))
	var keep := _customer.conversations.find(_conversation)
	if keep < 0 and not _customer.conversations.is_empty():
		keep = 0
	if keep >= 0:
		_conversation_list.select(keep)
	_select_conversation(keep)


func _on_name_changed(text: String) -> void:
	if _customer == null:
		return
	if _customer.person != null:
		_customer.person.nickname = text
		if _customer.person.resource_path != "":
			_dirty_people[_customer.person.resource_path] = _customer.person
	_customer.display_name = text
	_customer_list.set_item_text(_customers.find(_customer), _customer_label(_customer))
	_touch()


func _on_voice_selected(index: int) -> void:
	if _customer == null:
		return
	if _customer.person == null:
		_fail("%s has no person; set one in the inspector before its voice" % _customer.display_name)
		_fill_persons()
		return
	_customer.person.voice = _persons[index]
	if _customer.person.resource_path != "":
		_dirty_people[_customer.person.resource_path] = _customer.person
	_touch()


# Lists the voice persons of voices/persons/ (made in the Voice Lab, F3), with the customer's.
func _fill_persons() -> void:
	_persons.clear()
	_voice_picker.clear()
	for resource: Resource in _saved(Voices.PERSONS_DIR):
		if resource is VoicePerson:
			_persons.append(resource)
			_voice_picker.add_item(resource.resource_path.get_file().get_basename().capitalize())
	if _customer.voice != null and not _persons.has(_customer.voice):
		_persons.append(_customer.voice)
		_voice_picker.add_item("%s (not in voices/persons)" % _customer.voice.resource_path.get_file().get_basename())
	_voice_picker.select(_persons.find(_customer.voice))


## Says [param line] in the customer's voice. A missing voice file is rendered first, which needs
## Chimera's path in Editor Settings > Humanerror > Voices.
func _play_line(line: DialogueLine) -> void:
	if line.text.strip_edges().is_empty():
		_fail("The line has no text to say")
		return
	if _customer.voice == null:
		_fail("%s's person has no voice; pick one under Voice" % _customer.display_name)
		return
	var effect := VoiceEffect.of(line, _conversation)
	var person := _customer.voice.resource_path.get_file().get_basename()
	if ClassDB.class_exists(&"ChimeraVoice"):
		# Live, as the game says it: the person, the mood and the effect, all three layers.
		var live := Voices.say_live(line, _customer.voice, effect)
		if live == null:
			_fail("Couldn't say the line live; see the Output panel")
			return
		_preview.stream = live
		_preview.play()
		_show_status("Playing live (%s, %s, %s)" % [person, line.pose, effect.resource_path.get_file().get_basename() if effect != null else "no effect"])
		return
	var voice := _customer.voice.body
	var path := Voices.path_of(line, voice)
	if not FileAccess.file_exists(path):
		var chimera: String = EditorInterface.get_editor_settings().get_setting(Voices.CHIMERA_SETTING)
		var problem := Voices.chimera_problem(chimera)
		if problem == "":
			problem = Voices.render(line, voice, chimera)
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
	_show_status("Playing %s (%s, %s)" % [path.get_file(), voice, line.pose])


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
	_node = _conversation
	_render_detail()


func _render_detail() -> void:
	_tree.clear()
	if _conversation == null:
		for child: Node in _node_box.get_children():
			child.queue_free()
		_node_box.add_child(_label("Pick a conversation."))
		return
	_fill_tree(_tree.create_item(), _conversation, null)
	# Selecting draws the node's editor (item_selected).
	_tree_item(_node if _tree_item(_node) != null else _conversation).select(0)


# Adds [param node] (the conversation, a Choice or a Reply) and the tree under it to [param item].
# The item's metadata is [node, the array that holds it]; null for the conversation.
func _fill_tree(item: TreeItem, node: Resource, holder: Variant) -> void:
	item.set_metadata(0, [node, holder])
	item.set_text(0, _node_label(node))
	if node is Choice:
		for reply: Reply in node.replies:
			if reply != null:
				_fill_tree(item.create_child(), reply, node.replies)
	elif node is Reply:
		for choice: Choice in node.choices:
			if choice != null:
				_fill_tree(item.create_child(), choice, node.choices)


func _tree_item(node: Resource, from: TreeItem = null) -> TreeItem:
	var item := from if from != null else _tree.get_root()
	if item == null:
		return null
	if item.get_metadata(0)[0] == node:
		return item
	for child: TreeItem in item.get_children():
		var found := _tree_item(node, child)
		if found != null:
			return found
	return null


func _node_label(node: Resource) -> String:
	if node is Conversation:
		return "Conversation: " + conversation_label(node)
	if node is Choice:
		var tags := Story.tags(node.when, {})
		if node.ends:
			tags.append("ends")
		return "> %s%s" % [node.text.left(50) if node.text != "" else "(no text)", "  [%s]" % ", ".join(tags) if not tags.is_empty() else ""]
	var reply := node as Reply
	var first := reply.lines[0].text.left(50) if not reply.lines.is_empty() and reply.lines[0] != null else "(no lines)"
	var reply_tags := Story.tags(reply.when, reply.set_flags)
	return "- %s%s" % [first, "  [%s]" % ", ".join(reply_tags) if not reply_tags.is_empty() else ""]


# Draws the editor of the selected node.
func _render_node() -> void:
	for child: Node in _node_box.get_children():
		child.queue_free()
	if _node is Conversation:
		var id_row := HBoxContainer.new()
		_node_box.add_child(id_row)
		id_row.add_child(_label("Id"))
		var id_edit := LineEdit.new()
		id_edit.text = _conversation.id
		id_edit.size_flags_horizontal = SIZE_EXPAND_FILL
		id_edit.text_changed.connect(_on_id_changed)
		id_row.add_child(id_edit)
		_render_when()
		_render_lines(_conversation)
		_node_box.add_child(_button("Add a choice for the player", _add_choice.bind(_conversation)))
	elif _node is Choice:
		var choice := _node as Choice
		var text_row := HBoxContainer.new()
		_node_box.add_child(text_row)
		text_row.add_child(_label("The player says"))
		var text := LineEdit.new()
		text.text = choice.text
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.text_changed.connect(func(changed: String) -> void:
			choice.text = changed
			_relabel())
		text_row.add_child(text)
		var ends := CheckBox.new()
		ends.text = "Ends the conversation after the reply"
		ends.button_pressed = choice.ends
		ends.toggled.connect(func(on: bool) -> void:
			choice.ends = on
			_relabel())
		_node_box.add_child(ends)
		_node_box.add_child(_label("Offered when (empty: always)"))
		_condition_rows(choice)
		_node_box.add_child(_label("The first reply whose condition matches plays."))
		_node_box.add_child(_node_buttons([["Add a reply", _add_reply.bind(choice)]]))
	else:
		var reply := _node as Reply
		_node_box.add_child(_label("Plays when (empty: always)"))
		_condition_rows(reply)
		_sets_row(reply)
		_render_lines(reply)
		_node_box.add_child(_node_buttons([["Add a choice for the player", _add_choice.bind(reply)]]))


# The buttons of a choice or a reply: [param extra] ([text, action] pairs), then Up, Down, Delete.
func _node_buttons(extra: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	for pair: Array in extra:
		row.add_child(_button(pair[0], pair[1]))
	row.add_child(_button("Up", _move_node.bind(-1)))
	row.add_child(_button("Down", _move_node.bind(1)))
	row.add_child(_button("Delete", _delete_node))
	return row


func _render_lines(reply: Reply) -> void:
	_node_box.add_child(_label("Lines (the customer says them in this order)"))
	for i: int in reply.lines.size():
		_node_box.add_child(_line_row(reply.lines, i))
	_node_box.add_child(_button("Add line", _add_line.bind(reply.lines)))


func _relabel() -> void:
	var item := _tree.get_selected()
	if item != null:
		item.set_text(0, _node_label(_node))
	_touch()


func _add_choice(to: Reply) -> void:
	var choice := Choice.new()
	var reply := Reply.new()
	reply.lines = [DialogueLine.new()]
	choice.replies = [reply]
	to.choices.append(choice)
	_node = choice
	_touch()
	_render_detail()


func _add_reply(to: Choice) -> void:
	var reply := Reply.new()
	reply.lines = [DialogueLine.new()]
	to.replies.append(reply)
	_node = reply
	_touch()
	_render_detail()


func _move_node(step: int) -> void:
	var holder: Variant = _tree_item(_node).get_metadata(0)[1]
	if holder == null:
		return
	var index: int = holder.find(_node)
	var to := index + step
	if to < 0 or to >= holder.size():
		return
	holder[index] = holder[to]
	holder[to] = _node
	_touch()
	_render_detail()


func _delete_node() -> void:
	var item := _tree_item(_node)
	var holder: Array = item.get_metadata(0)[1]
	holder.erase(_node)
	_node = item.get_parent().get_metadata(0)[0]
	_touch()
	_render_detail()


## The trigger, once, and the condition of the conversation. A condition is made on the first edit.
func _render_when() -> void:
	var c := _conversation
	var row := HBoxContainer.new()
	_node_box.add_child(row)
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
	row.add_child(_label("Effect"))
	row.add_child(_effect_picker(c.effect, "None", func(picked: VoiceEffect) -> void:
		c.effect = picked
		_touch()))

	_condition_rows(c)
	_sets_row(c)


# The days and flags of [param holder]'s condition (a Reply or a Choice); made on the first edit.
func _condition_rows(holder: Resource) -> void:
	var when: Condition = holder.when if holder.when != null else Condition.new()
	var days := HBoxContainer.new()
	_node_box.add_child(days)
	days.add_child(_label("Days"))
	for field: String in ["from_day", "to_day"]:
		var box := SpinBox.new()
		box.min_value = 1
		box.max_value = 7
		box.value = when.get(field)
		box.value_changed.connect(func(value: float) -> void:
			_condition_of(holder).set(field, int(value))
			_changed_when())
		days.add_child(box)
	for field: String in ["need_flags", "not_flags"]:
		var flags_row := HBoxContainer.new()
		_node_box.add_child(flags_row)
		flags_row.add_child(_label("Needs flags" if field == "need_flags" else "Not with flags"))
		var edit := FlagField.new(", ".join(PackedStringArray(when.get(field))), "flag_a, flag_b", _offers)
		edit.edited.connect(func(text: String) -> void:
			var names: Array[StringName] = []
			for part: String in text.split(",", false):
				if part.strip_edges() != "":
					names.append(StringName(part.strip_edges()))
			_condition_of(holder).set(field, names)
			_changed_when())
		flags_row.add_child(edit)


func _sets_row(reply: Reply) -> void:
	var sets_row := HBoxContainer.new()
	_node_box.add_child(sets_row)
	sets_row.add_child(_label("Sets flags"))
	var sets := FlagField.new(flags_text(reply.set_flags), "flag_a, sign_bell=2, flag_b=0 (0 clears)", _offers)
	sets.edited.connect(func(text: String) -> void:
		var parsed: Variant = parse_flags(text)
		if parsed is String:
			_show_status("Sets flags not changed: " + parsed)
			return
		reply.set_flags = parsed
		_show_status("")
		_changed_when())
	sets_row.add_child(sets)


## The flags that a FlagField offers: every flag that a customer, a day or a sign uses.
func _offers() -> Dictionary:
	var errors: Array[String] = []
	var known := FlagField.offers(FlagField.index(_customers, FlagField.load_days(errors), errors))
	for error: String in errors:
		_fail(error)
	return known


## [param flags] as "name, name=2": the text of a Sets flags field.
static func flags_text(flags: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = []
	for flag: StringName in flags:
		parts.append(String(flag) if flags[flag] == 1 else "%s=%d" % [flag, flags[flag]])
	return ", ".join(parts)


## The flags in [param text], written as [method flags_text] does, or a String that says why not.
static func parse_flags(text: String) -> Variant:
	var flags: Dictionary[StringName, int] = {}
	for part: String in text.split(",", false):
		var pair := part.split("=")
		var flag := pair[0].strip_edges()
		if flag == "":
			continue
		var value := pair[1].strip_edges() if pair.size() == 2 else "1"
		if pair.size() > 2 or not value.is_valid_int():
			return "'%s' is not a flag: write name or name=number" % part.strip_edges()
		flags[StringName(flag)] = value.to_int()
	return flags


func _condition_of(holder: Resource) -> Condition:
	if holder.when == null:
		holder.when = Condition.new()
	return holder.when


func _changed_when() -> void:
	_conversation_list.set_item_text(_customer.conversations.find(_conversation), conversation_label(_conversation))
	_relabel()


## The id and when it plays, for the conversation list.
static func conversation_label(c: Conversation) -> String:
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
	if not c.set_flags.is_empty():
		parts.append("sets " + flags_text(c.set_flags))
	return "%s  (%s)" % [c.id, ", ".join(parts)]


func _line_row(lines: Array[DialogueLine], index: int) -> Control:
	var line := lines[index]
	if line == null:
		line = DialogueLine.new()
		lines[index] = line
	var row := HBoxContainer.new()
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 160
	row.add_child(side)
	side.add_child(_pose_picker(line))
	side.add_child(_effect_picker(line.effect, "Conversation's", func(picked: VoiceEffect) -> void:
		line.effect = picked
		_touch()))
	var buttons := HBoxContainer.new()
	side.add_child(buttons)
	buttons.add_child(_button("Play", _play_line.bind(line)))
	buttons.add_child(_button("Up", _move_line.bind(lines, index, -1)))
	buttons.add_child(_button("Down", _move_line.bind(lines, index, 1)))
	buttons.add_child(_button("X", _remove_line.bind(lines, index)))
	var text := TextEdit.new()
	text.text = line.text
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size.y = 64
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.text_changed.connect(func() -> void:
		line.text = text.text
		_relabel())
	row.add_child(text)
	return row


## A dropdown of the voice effects in voices/effects/ (made in the Voice Lab, F3), with
## [param empty_label] for none; [param on_pick] gets the picked VoiceEffect or null.
func _effect_picker(current: VoiceEffect, empty_label: String, on_pick: Callable) -> OptionButton:
	var picker := OptionButton.new()
	picker.add_item(empty_label)
	var effects: Array = [null]
	for resource: Resource in _saved(Voices.EFFECTS_DIR):
		if resource is VoiceEffect:
			effects.append(resource)
			picker.add_item(resource.resource_path.get_file().get_basename().capitalize())
	if current != null and not effects.has(current):
		effects.append(current)
		picker.add_item("%s (not in voices/effects)" % current.resource_path.get_file().get_basename())
	picker.select(effects.find(current))
	picker.item_selected.connect(func(index: int) -> void: on_pick.call(effects[index]))
	return picker


## Every .tres in [param dir], loaded; one that won't load is reported and left out.
static func _saved(dir: String) -> Array[Resource]:
	var found: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(".tres"):
			var resource := load(dir.path_join(file_name))
			if resource == null:
				push_error("Dialogue: can't load %s" % dir.path_join(file_name))
				continue
			found.append(resource)
	return found


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
	_conversation_list.set_item_text(_customer.conversations.find(_conversation), conversation_label(_conversation))
	_touch()


func _add_line(lines: Array[DialogueLine]) -> void:
	lines.append(DialogueLine.new())
	_touch()
	_render_detail()


func _move_line(lines: Array[DialogueLine], index: int, step: int) -> void:
	var to := index + step
	if to < 0 or to >= lines.size():
		return
	var line := lines[index]
	lines[index] = lines[to]
	lines[to] = line
	_touch()
	_render_detail()


func _remove_line(lines: Array[DialogueLine], index: int) -> void:
	lines.remove_at(index)
	_touch()
	_render_detail()


func _touch() -> void:
	_dirty[_customer.resource_path] = true
	_customer.emit_changed()
	_show_status("Unsaved: %s" % ", ".join(_dirty.keys()))


func _customer_label(customer: Customer) -> String:
	return "%s (%s)" % [customer.spoken_name(), customer.resource_path.get_file()]


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
