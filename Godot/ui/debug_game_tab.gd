extends VBoxContainer
## The Game tab of the debug menu: the Game state, editable. Every edit goes through
## Game.restore(), so the tab can set only states that restore accepts, and shows why when not.

const JOB_FLAGS: Array[String] = ["hardware_fixed", "software_fixed", "powered", "post_it_ticked"]

var _status: Label
var _rows: VBoxContainer


func _ready() -> void:
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.5, 0.5))
	add_child(_status)
	_rows = VBoxContainer.new()
	add_child(_rows)
	Game.changed.connect(_refresh)
	visibility_changed.connect(_refresh)


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var state := Game.snapshot()
	var customers: Array[Customer] = Game.day.customers if Game.day != null else []

	_section("Day")
	_row("Day", _spin(1, 7, Game.day_number, func(value: int) -> void: _edit("day", value)))
	_row("Phase", _enum_picker(Game.Phase, Game.phase, "phase"))
	_row("Arrivals", _spin(0, customers.size(), Game.arrivals, func(value: int) -> void: _edit("arrivals", value)))
	_row("Daypart", _enum_picker(Game.Daypart, Game.daypart, "daypart"))

	_section("Visitor")
	# The visitor: nobody, a drop-off of today's customers, or a pickup of a job on the counter.
	var visits: Array[Array] = [["", "NONE"]]
	var visitor_picker := OptionButton.new()
	visitor_picker.add_item("Nobody")
	for c: Customer in customers:
		visits.append([c.resource_path, "DROP_OFF"])
		visitor_picker.add_item("%s drops off" % c.display_name)
	for j: Job in Game.jobs:
		visits.append([j.customer.resource_path, "PICKUP"])
		visitor_picker.add_item("%s picks up (slot %d)" % [j.customer.display_name, j.slot])
	var current := visits.find([state["visitor"], state["visit"]])
	visitor_picker.select(current)
	visitor_picker.item_selected.connect(func(index: int) -> void:
		var changed := Game.snapshot()
		changed["visitor"] = visits[index][0]
		changed["visit"] = visits[index][1]
		changed["visitor_state"] = "NONE" if index == 0 else (
				state["visitor_state"] if state["visitor_state"] != "NONE" else "TALKING")
		_apply(changed))
	_row("Visitor", visitor_picker)
	if Game.visitor != null:
		_row("Visitor state", _enum_picker(Game.VisitorState, Game.visitor_state, "visitor_state"))
	_row("Conversation", _text(state["conversation"] if state["conversation"] != "" else "none"))

	_section("Counter (%d of %d)" % [Game.jobs.size(), Game.MAX_JOBS])
	var job_states: Array = state["jobs"]
	for i: int in job_states.size():
		_rows.add_child(_job_row(i, Game.jobs[i]))
	var add_picker := OptionButton.new()
	for c: Customer in customers:
		add_picker.add_item(c.display_name)
	var add := _button("Add job", func() -> void: _add_job(customers[add_picker.selected] if add_picker.selected >= 0 else null))
	add.disabled = customers.is_empty() or Game.jobs.size() >= Game.MAX_JOBS
	_row("", add_picker, add)

	_section("Flags")
	for flag_name: StringName in Game.flags:
		var value := _spin(-999, 999, Game.flags[flag_name], func(number: int) -> void: _edit_flag(flag_name, number))
		_row(String(flag_name), value, _button("X", _edit_flag.bind(flag_name, 0)))
	var new_flag := LineEdit.new()
	new_flag.placeholder_text = "new_flag"
	new_flag.text_submitted.connect(func(text: String) -> void: _edit_flag(StringName(text.strip_edges()), 1))
	_row("", new_flag, _button("Set", func() -> void: _edit_flag(StringName(new_flag.text.strip_edges()), 1)))

	_section("Conversations played")
	var seen := Game.seen.keys()
	var clear := _button("Clear", _edit.bind("seen", []))
	clear.disabled = seen.is_empty()
	_row(", ".join(seen) if not seen.is_empty() else "none", Control.new(), clear)


## One job: its customer, its repair, whether it is in focus or on the cable, and a remove button.
func _job_row(index: int, job: Job) -> Control:
	var frame := PanelContainer.new()
	var look := StyleBoxFlat.new()
	look.bg_color = Color(1, 1, 1, 0.06)
	look.set_corner_radius_all(4)
	frame.add_theme_stylebox_override(&"panel", look)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	frame.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	margin.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _text("Slot %d: %s (%s)" % [job.slot, job.customer.display_name, job.problem.short_name])
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	for key: String in ["focus_slot", "connected_slot"]:
		var on := (Game.focus == job) if key == "focus_slot" else (Game.connected == job)
		var toggle := _button(("Focus" if key == "focus_slot" else "Cable") + (" *" if on else ""),
				_edit.bind(key, -1 if on else job.slot))
		head.add_child(toggle)
	head.add_child(_button("X", _remove_job.bind(index)))
	var checks := HBoxContainer.new()
	box.add_child(checks)
	for key: String in JOB_FLAGS:
		var check := CheckBox.new()
		check.text = key.capitalize().replace(" Fixed", "").replace("Post It ", "")
		check.button_pressed = job.get(key)
		check.toggled.connect(func(on: bool) -> void:
			var changed := Game.snapshot()
			changed["jobs"][index][key] = on
			_apply(changed))
		checks.add_child(check)
	return frame


func _add_job(customer: Customer) -> void:
	if customer == null:
		_status.text = "Pick a customer to add."
		return
	var state := Game.snapshot()
	var taken: Array = state["jobs"].map(func(j: Dictionary) -> int: return j["slot"])
	var slot := 0
	while taken.has(slot):
		slot += 1
	state["jobs"].append({"customer": customer.resource_path, "slot": slot, "order": Game.jobs.size()})
	_apply(state)


func _remove_job(index: int) -> void:
	var state := Game.snapshot()
	var slot: int = state["jobs"][index]["slot"]
	state["jobs"].remove_at(index)
	for key: String in ["focus_slot", "connected_slot"]:
		if state[key] == slot:
			state[key] = -1
	_apply(state)


func _edit(key: String, value: Variant) -> void:
	var state := Game.snapshot()
	state[key] = value
	_apply(state)


func _edit_flag(flag_name: StringName, value: int) -> void:
	if flag_name == &"":
		_status.text = "A flag needs a name."
		return
	var state := Game.snapshot()
	state["flags"][flag_name] = value
	_apply(state)


func _apply(state: Dictionary) -> void:
	_status.text = Game.restore(state)
	_refresh()


## A dropdown of the names in [param enum_type], set to [param value]; picking one edits [param key].
func _enum_picker(enum_type: Dictionary, value: int, key: String) -> OptionButton:
	var picker := OptionButton.new()
	for value_name: String in enum_type:
		picker.add_item(value_name, enum_type[value_name])
	picker.select(picker.get_item_index(value))
	picker.item_selected.connect(func(index: int) -> void: _edit(key, enum_type.find_key(picker.get_item_id(index))))
	return picker


func _row(label: String, control: Control, extra: Control = null) -> void:
	var row := HBoxContainer.new()
	_rows.add_child(row)
	var name_label := _text(label)
	name_label.custom_minimum_size.x = 200
	row.add_child(name_label)
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(control)
	if extra != null:
		row.add_child(extra)


## A heading with space above it, so the tab reads as groups.
func _section(title: String) -> void:
	if _rows.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		_rows.add_child(gap)
		_rows.add_child(HSeparator.new())
	var heading := _text(title)
	heading.add_theme_font_size_override(&"font_size", 24)
	_rows.add_child(heading)


func _text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _spin(low: int, high: int, value: int, on_change: Callable) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.value = value
	box.value_changed.connect(func(number: float) -> void: on_change.call(int(number)))
	return box
