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
		var fact := (row.get_child(0) as StoryFactPicker).fact
		if fact == &"":
			continue
		if (row.get_child(1) as OptionButton).selected == 1:
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


## Opens [param editor] (a condition or "remembers" editor) in a popup under [param near], titled
## [param title]; calls [param closed] once the writer closes it, by Done or by clicking outside.
static func popup(near: Control, title: String, editor: Control, closed: Callable) -> void:
	var panel := PopupPanel.new()
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 380
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	box.add_child(head)
	box.add_child(editor)
	var done := Button.new()
	done.text = "Done"
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.pressed.connect(panel.hide)
	box.add_child(done)
	near.add_child(panel)
	panel.popup_hide.connect(func() -> void:
		closed.call()
		panel.queue_free())
	var at := near.get_global_transform_with_canvas() * Vector2(0, near.size.y)
	panel.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


func _add_row(flag: StringName, negated: bool) -> StoryFactPicker:
	var row := HBoxContainer.new()
	var picker := StoryFactPicker.new()
	picker.facts = facts
	picker.fact = flag
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size.x = 160
	picker.picked.connect(func(_fact: StringName) -> void: changed.emit(condition()))
	row.add_child(picker)
	var is_true := OptionButton.new()
	for words: String in _IS:
		is_true.add_item(words)
	is_true.select(1 if negated else 0)
	is_true.tooltip_text = "Whether the fact must be true or must not be"
	is_true.item_selected.connect(func(_index: int) -> void: changed.emit(condition()))
	row.add_child(is_true)
	var cut := Button.new()
	cut.text = "x"
	cut.flat = true
	cut.tooltip_text = "Remove this fact"
	cut.pressed.connect(func() -> void:
		_rows.remove_child(row)
		row.queue_free()
		changed.emit(condition()))
	row.add_child(cut)
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
