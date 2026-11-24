extends VBoxContainer
## The Game tab of the debug menu: the Game state, editable. Every edit goes through
## Game.restore(), so the tab can set only states that restore accepts, and shows why when not.

const JOB_FLAGS: Array[String] = ["hardware_fixed", "software_fixed", "tested", "powered"]

var _status: Label
var _rows: VBoxContainer
# True while the day slider is dragged: the day changes when the drag ends, not on every step.
var _dragging_day: bool = false


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
	var errands: Array[Errand] = Game.day.errands if Game.day != null else []
	var codes := Game.day.codes() if Game.day != null else PackedStringArray()

	_section("Day")
	_row("Day", _day_slider())
	if not Game.story_errors.is_empty():
		var note := _text("The story files have errors, so the last week that loaded plays:\n" + "\n".join(Game.story_errors))
		note.modulate = Color(1.0, 0.5, 0.5)
		_row("", note)
	_row("Phase", _enum_picker(Game.Phase, Game.phase, "phase"))
	_row("Arrivals", _spin(0, codes.size(), Game.arrivals, func(value: int) -> void: _edit("arrivals", value)))
	_row("Daypart", _enum_picker(Game.Daypart, Game.daypart, "daypart"))
	_row("Today's errands", _text("\n".join(errands.map(_errand_text))))

	_section("Visitor")
	# The visitor: nobody, a drop-off of one of today's errands (which sets the arrivals to its code), or
	# a pickup of a job on the counter.
	var visits: Array[Array] = [["", "NONE", Game.arrivals]]
	var visitor_picker := OptionButton.new()
	visitor_picker.add_item("Nobody")
	for errand: Errand in errands:
		visits.append([errand.customer.resource_path, "DROP_OFF", codes.find(errand.code) + 1])
		visitor_picker.add_item("%s drops off (%s)" % [errand.customer.spoken_name(), errand.file_name()])
	for j: Job in Game.jobs:
		visits.append([j.customer.resource_path, "PICKUP", Game.arrivals])
		visitor_picker.add_item("%s picks up (slot %d)" % [j.customer.spoken_name(), j.slot])
	var current := visits.find_custom(func(v: Array) -> bool:
		return v[0] == state["visitor"] and v[1] == state["visit"] and (v[1] != "DROP_OFF" or v[2] == Game.arrivals))
	if current < 0 and Game.visitor != null:
		visitor_picker.add_item("%s %s" % [Game.visitor.spoken_name(), String(Game.Visit.find_key(Game.visit)).to_lower()])
		visits.append([state["visitor"], state["visit"], Game.arrivals])
		current = visits.size() - 1
	visitor_picker.select(current)
	visitor_picker.item_selected.connect(func(index: int) -> void:
		var changed := Game.snapshot()
		changed["visitor"] = visits[index][0]
		changed["visit"] = visits[index][1]
		changed["arrivals"] = visits[index][2]
		changed["visitor_state"] = "NONE" if index == 0 else (
				state["visitor_state"] if state["visitor_state"] != "NONE" else "TALKING")
		_apply(changed))
	_row("Visitor", visitor_picker)
	if Game.visitor != null:
		_row("Visitor state", _enum_picker(Game.VisitorState, Game.visitor_state, "visitor_state"))
	_row("Conversation", _text(state["conversation"] if state["conversation"] != "" else "none"))
	var off_hook := CheckBox.new()
	off_hook.text = "Phone off the hook"
	off_hook.button_pressed = Game.phone_off_hook
	off_hook.toggled.connect(func(on: bool) -> void: _edit("phone_off_hook", on))
	_rows.add_child(off_hook)

	_section("Counter (%d of %d)" % [Game.jobs.size(), Game.MAX_JOBS])
	var job_states: Array = state["jobs"]
	for i: int in job_states.size():
		_rows.add_child(_job_row(i, Game.jobs[i]))
	var add_picker := OptionButton.new()
	var with_computer := errands.filter(func(errand: Errand) -> bool: return errand.brings != Errand.Brings.NOTHING)
	for errand: Errand in with_computer:
		add_picker.add_item(_errand_text(errand))
	var add := _button("Add job", func() -> void: _add_job(with_computer[add_picker.selected] if add_picker.selected >= 0 else null))
	add.disabled = with_computer.is_empty() or Game.jobs.size() >= Game.MAX_JOBS
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


## A slider over the days that have a day file, with a tick per day; the number shows next to it.
## With one day file it is locked. A gap between day files is refused, and the slider springs back.
func _day_slider() -> Control:
	var days := Game.day_numbers()
	var row := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = days.min() if not days.is_empty() else 1
	slider.max_value = days.max() if not days.is_empty() else 1
	slider.editable = days.size() > 1
	slider.step = 1
	slider.tick_count = int(slider.max_value - slider.min_value) + 1
	slider.ticks_on_borders = true
	slider.value = Game.day_number
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(slider)
	var number := _text(str(Game.day_number))
	number.custom_minimum_size.x = 32
	row.add_child(number)
	slider.value_changed.connect(func(value: float) -> void:
		number.text = str(int(value))
		if not _dragging_day:
			_edit("day", int(value)))
	slider.drag_started.connect(func() -> void: _dragging_day = true)
	slider.drag_ended.connect(func(value_changed: bool) -> void:
		_dragging_day = false
		if value_changed:
			_edit("day", int(slider.value)))
	return row


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
	var title := _text("Slot %d: %s" % [job.slot, _errand_text(job.errand) if job.errand != null else job.customer.spoken_name()])
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


func _add_job(errand: Errand) -> void:
	if errand == null:
		_status.text = "Pick an errand to add."
		return
	var state := Game.snapshot()
	var taken: Array = state["jobs"].map(func(j: Dictionary) -> int: return j["slot"])
	var slot := 0
	while taken.has(slot):
		slot += 1
	if errand.file == "":
		_status.text = "%s is in no story file, so a snapshot can't name it." % _errand_text(errand)
		return
	state["jobs"].append({"errand": errand.file_name(), "slot": slot, "order": Game.jobs.size()})
	_apply(state)


## "0102_skater_bro: dust_overheat, leaves", for the lists of errands.
static func _errand_text(errand: Errand) -> String:
	var problem := String(errand.problem.short_name) if errand.problem != null else "no problem"
	var label := errand.file_name() if errand.file != "" else errand.customer.spoken_name()
	return "%s: %s, %s" % [label, problem, String(Errand.Brings.find_key(errand.brings)).to_lower()]


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
