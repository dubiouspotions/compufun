class_name StoryFlagsEditor
extends VBoxContainer
## The Story Lab's editor of what a reply remembers (its flags), in plain words: rows of
## "[fact] becomes true / false / a number", and "+ another fact". True stores 1, false clears the
## fact (0), and a number is for the rare staged fact, such as a corruption sign's stage.

## The writer changed the facts: [param flags] maps each fact to its number, 0 to clear it.
signal changed(flags: Dictionary[StringName, int])

const SCENE: String = "res://dev/story_lab/flags_editor.tscn"
const _BECOMES: PackedStringArray = ["becomes true", "becomes false", "becomes a number"]

## The known facts that the fact pickers offer, as flag names. Set it before [method edit].
var facts: PackedStringArray = []

var _rows: VBoxContainer
var _shown: Dictionary[StringName, int] = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rows = VBoxContainer.new()
	add_child(_rows)
	var more := Button.new()
	more.text = "+ another fact"
	more.flat = true
	more.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more.tooltip_text = "Add a fact that this reply makes true or false"
	more.pressed.connect(func() -> void: _add_row(&"", 1).open())
	add_child(more)
	edit(_shown)


## The editor scene, made with [param known] as its facts.
static func make(known: PackedStringArray) -> StoryFlagsEditor:
	var editor := (load(SCENE) as PackedScene).instantiate() as StoryFlagsEditor
	editor.facts = known
	return editor


## Shows a copy of [param flags] (fact to number) to edit.
func edit(edited_flags: Dictionary[StringName, int]) -> void:
	if not is_node_ready():
		_shown = edited_flags.duplicate()
		return
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for flag: StringName in edited_flags:
		_add_row(flag, edited_flags[flag])


## The facts as edited: fact to number, 0 to clear it.
func flags() -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for row: Node in _rows.get_children():
		var line := row.get_child(0)
		var fact := (line.get_child(0) as StoryFactPicker).fact
		if fact == &"":
			continue
		var becomes := (line.get_child(1) as OptionButton).selected
		found[fact] = [1, 0, int((line.get_child(2) as SpinBox).value)][becomes]
	return found


## [param flags] in words, such as "skater told us, cambion is false, logo stage is 2"; "" for none.
static func describe(described: Dictionary[StringName, int]) -> String:
	var parts := PackedStringArray()
	for flag: StringName in described:
		var words := StoryFactPicker.humanize(flag)
		match described[flag]:
			1:
				parts.append(words)
			0:
				parts.append(words + " is false")
			_:
				parts.append("%s is %d" % [words, described[flag]])
	return ", ".join(parts)


func _add_row(flag: StringName, value: int) -> StoryFactPicker:
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
	picker.picked.connect(func(_fact: StringName) -> void: changed.emit(flags()))
	line.add_child(picker)
	var becomes := OptionButton.new()
	for words: String in _BECOMES:
		becomes.add_item(words)
	becomes.tooltip_text = "True remembers the fact; false forgets it; a number is for a fact with stages"
	line.add_child(becomes)
	var number := SpinBox.new()
	number.min_value = 2
	number.max_value = 99
	number.value = maxi(value, 2)
	number.tooltip_text = "The stage that the fact is at"
	number.value_changed.connect(func(_value: float) -> void: changed.emit(flags()))
	line.add_child(number)
	becomes.select(0 if value == 1 else (1 if value == 0 else 2))
	number.visible = becomes.selected == 2
	becomes.item_selected.connect(func(index: int) -> void:
		number.visible = index == 2
		changed.emit(flags()))
	var cut := Button.new()
	cut.text = "x"
	cut.flat = true
	cut.tooltip_text = "Remove this fact"
	cut.pressed.connect(func() -> void:
		_rows.remove_child(row)
		row.queue_free()
		changed.emit(flags()))
	line.add_child(cut)
	row.add_child(host)
	_rows.add_child(row)
	return picker
