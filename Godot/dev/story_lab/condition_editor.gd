class_name StoryConditionEditor
extends VBoxContainer
## The Story Lab's one editor of a condition (a Condition resource), in plain words: rows of
## "[fact] is true / is not true", the days it may happen on, and "+ another fact". No fact and
## every day means always. It is the same scene wherever a condition shows: a choice's "only if",
## an answer's if, a conversation's "only when" and an errand's "comes when".

## The writer changed the condition: [param when] is the new one, null for always.
signal changed(when: Condition)

const SCENE: String = "res://dev/story_lab/condition_editor.tscn"
const _IS: PackedStringArray = ["is true", "is not true"]
# The room around a popup's card that its shadow draws in, in pixels.
const _SHADOW: float = 16.0

## The known facts that the fact pickers offer, as flag names. Set it before [method edit].
var facts: PackedStringArray = []

var _rows: VBoxContainer
var _from: OptionButton
var _to: OptionButton
var _shown: Condition


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rows = VBoxContainer.new()
	add_child(_rows)
	var more := Button.new()
	more.text = "+ another fact"
	more.flat = true
	more.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more.tooltip_text = "Add a fact that must also be true, or must not be"
	more.pressed.connect(func() -> void: _add_row(&"", false).open())
	add_child(more)
	var days := HBoxContainer.new()
	days.add_child(_text("On days"))
	_from = _day_picker("The first day it can happen on")
	days.add_child(_from)
	days.add_child(_text("to"))
	_to = _day_picker("The last day it can happen on")
	days.add_child(_to)
	add_child(days)
	_from.item_selected.connect(func(index: int) -> void:
		if _to.selected < index:
			_to.select(index)
		changed.emit(condition()))
	_to.item_selected.connect(func(index: int) -> void:
		if _from.selected > index:
			_from.select(index)
		changed.emit(condition()))
	edit(_shown)


## The editor scene, made: call [method edit] on it once it is in the tree.
static func make(known: PackedStringArray) -> StoryConditionEditor:
	var editor := (load(SCENE) as PackedScene).instantiate() as StoryConditionEditor
	editor.facts = known
	return editor


## Shows [param when] to edit; null shows always. Changes go to new Conditions, never to [param when].
func edit(when: Condition) -> void:
	if not is_node_ready():
		_shown = when
		return
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var shown := when if when != null else Condition.new()
	for flag: StringName in shown.need_flags:
		_add_row(flag, false)
	for flag: StringName in shown.not_flags:
		_add_row(flag, true)
	_from.select(shown.from_day - 1)
	_to.select(shown.to_day - 1)


## The condition as edited: null when it always holds.
func condition() -> Condition:
	var when := Condition.new()
	for row: Node in _rows.get_children():
		var line := row.get_child(0)
		var fact := (line.get_child(0) as StoryFactPicker).fact
		if fact == &"":
			continue
		if (line.get_child(1) as OptionButton).selected == 1:
			when.not_flags.append(fact)
		else:
			when.need_flags.append(fact)
	when.from_day = _from.selected + 1
	when.to_day = _to.selected + 1
	return null if describe(when) == "always" else when


## [param when] as a sentence, such as "skater told us, not gone skater bro, on days 2 to 4";
## "always" for null or a condition that always holds.
static func describe(when: Condition) -> String:
	if when == null:
		return "always"
	var parts := PackedStringArray()
	for flag: StringName in when.need_flags:
		parts.append(StoryFactPicker.humanize(flag))
	for flag: StringName in when.not_flags:
		parts.append("not " + StoryFactPicker.humanize(flag))
	if when.from_day == when.to_day:
		parts.append("on day %d" % when.from_day)
	elif when.from_day != 1 or when.to_day != 7:
		parts.append("on days %d to %d" % [when.from_day, when.to_day])
	return ", ".join(parts) if not parts.is_empty() else "always"


## Opens [param editor] (a condition or "remembers" editor) in a card titled [param title], with Done
## at its bottom right; calls [param closed] once the writer closes it, by Done or by clicking
## outside. The card goes below [param avoid] (the box that it edits, in canvas coordinates; empty
## for [param near]'s own rect), or beside or above it, wherever it fits inside the view.
static func popup(near: Control, title: String, editor: Control, closed: Callable, avoid: Rect2 = Rect2()) -> void:
	var panel := PopupPanel.new()
	panel.transparent_bg = true
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var room := MarginContainer.new()  # the window's edge around the card, for its shadow
	for side: String in ["left", "top", "right", "bottom"]:
		room.add_theme_constant_override("margin_" + side, int(_SHADOW))
	panel.add_child(room)
	var card := PanelContainer.new()
	var look := StyleBoxFlat.new()
	look.bg_color = LabUI.CARD
	look.border_color = LabUI.ACCENT.darkened(0.25)
	look.set_border_width_all(1)
	look.set_corner_radius_all(10)
	look.set_content_margin_all(14)
	look.shadow_color = Color(0, 0, 0, 0.55)
	look.shadow_size = 12
	look.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", look)
	room.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 400
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.add_child(LabUI.label(title, 16))
	box.add_child(editor)
	var foot := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var done := LabUI.button("Done", panel.hide, &"AccentButton")
	done.custom_minimum_size.x = 90
	foot.add_child(done)
	box.add_child(foot)
	near.add_child(panel)
	panel.popup_hide.connect(func() -> void:
		closed.call()
		panel.queue_free())
	var around := avoid if avoid.has_area() else near.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, near.size)
	var bounds := near.get_viewport().get_visible_rect()
	panel.popup(_spot_for(around, room.get_combined_minimum_size(), bounds))
	room.minimum_size_changed.connect(func() -> void:
		if panel.visible:
			var spot := _spot_for(around, room.get_combined_minimum_size(), bounds)
			panel.position = spot.position
			panel.size = spot.size)


# Where a window of [param wanted] size goes: below [param around], else to its right, its left
# or above it, the first that fits in [param bounds]; else below, pushed inside.
static func _spot_for(around: Rect2, wanted: Vector2, bounds: Rect2) -> Rect2i:
	var gap := 6.0 - _SHADOW
	var tries: Array[Vector2] = [
		Vector2(around.position.x - _SHADOW, around.end.y + gap),
		Vector2(around.end.x + gap, around.position.y - _SHADOW),
		Vector2(around.position.x - gap - wanted.x, around.position.y - _SHADOW),
		Vector2(around.position.x - _SHADOW, around.position.y - gap - wanted.y),
	]
	for at: Vector2 in tries:
		if bounds.encloses(Rect2(at, wanted)):
			return Rect2i(Vector2i(at), Vector2i(wanted))
	var pushed := tries[0].clamp(bounds.position, (bounds.end - wanted).max(bounds.position))
	return Rect2i(Vector2i(pushed), Vector2i(wanted))


func _add_row(flag: StringName, negated: bool) -> StoryFactPicker:
	var row := VBoxContainer.new()
	var line := HBoxContainer.new()
	row.add_child(line)
	var host := VBoxContainer.new()
	host.hide()
	var picker := StoryFactPicker.new()
	picker.facts = facts
	picker.list_host = host
	picker.fact = flag
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size.x = 160
	picker.picked.connect(func(_fact: StringName) -> void: changed.emit(condition()))
	line.add_child(picker)
	var is_true := OptionButton.new()
	for words: String in _IS:
		is_true.add_item(words)
	is_true.select(1 if negated else 0)
	is_true.tooltip_text = "Whether the fact must be true or must not be"
	is_true.item_selected.connect(func(_index: int) -> void: changed.emit(condition()))
	line.add_child(is_true)
	var cut := Button.new()
	cut.text = "x"
	cut.flat = true
	cut.tooltip_text = "Remove this fact"
	cut.pressed.connect(func() -> void:
		_rows.remove_child(row)
		row.queue_free()
		changed.emit(condition()))
	line.add_child(cut)
	row.add_child(host)
	_rows.add_child(row)
	return picker


func _day_picker(tip: String) -> OptionButton:
	var days := OptionButton.new()
	for day: int in range(1, 8):
		days.add_item(str(day))
	days.tooltip_text = tip
	return days


func _text(words: String) -> Label:
	var label := Label.new()
	label.text = words
	return label
