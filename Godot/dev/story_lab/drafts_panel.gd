class_name StoryDraftsPanel
extends Control
## The Story Lab's list of drafts, over the Lab: each file the writer changed, whether main changed
## it since, whether it has unfinished text, and Discard. A draft that main changed since shows both
## texts side by side, to keep the writer's or take main's.

## The drafts changed: one was discarded, kept or replaced by main's text.
signal changed

var _drafts: StoryDrafts
var _list: VBoxContainer
var _compare: Control
var _mine: CodeEdit
var _main: CodeEdit
var _compare_title: Label
var _comparing: String = ""


func _ready() -> void:
	_build()
	hide()


## Shows the drafts of [param drafts], asking git which ones main changed since.
func show_drafts(drafts: StoryDrafts) -> void:
	_drafts = drafts
	_compare.hide()
	_fill()
	show()


## The paths of the drafts whose file main changed since the draft started.
static func main_changed(drafts: StoryDrafts) -> PackedStringArray:
	var found := PackedStringArray()
	for path: String in drafts.paths():
		if drafts.main_changed(path):
			found.append(path)
	return found


## The paths that have a draft, unfinished text or both, sorted.
static func edited(drafts: StoryDrafts) -> PackedStringArray:
	var found: Dictionary[String, bool] = {}
	for path: String in drafts.paths() + drafts.unfinished_paths():
		found[path] = true
	var paths := PackedStringArray(found.keys())
	paths.sort()
	return paths


## What the draft of [param path] does: "new", "removed" or "changed".
static func kind(drafts: StoryDrafts, path: String) -> String:
	if drafts.texts()[path] == "":
		return "removed"
	return "new" if drafts.checkout_text(path) == "" else "changed"


func _fill() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var paths := edited(_drafts)
	if paths.is_empty():
		_list.add_child(LabUI.label("No drafts: the game plays main's story files.", 15, LabUI.DIM))
		return
	var changed_on_main := main_changed(_drafts)
	for path: String in paths:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label := LabUI.label(path.trim_prefix("res://story/"), 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if _drafts.has(path):
			var what := kind(_drafts, path)
			row.add_child(LabUI.chip(what, {"new": LabUI.GOOD, "removed": LabUI.BAD, "changed": LabUI.CHANGED}[what], 12))
			row.add_child(LabUI.label("from " + _drafts.start_commit(path).left(8), 12, LabUI.DIM))
		if _drafts.has_unfinished(path):
			var unfinished := LabUI.chip("unfinished text", LabUI.BAD, 12)
			unfinished.tooltip_text = "Your text of this file doesn't parse yet. The game plays the last version that parsed, and Send leaves the unfinished text out. Open the errand to finish it."
			unfinished.mouse_filter = Control.MOUSE_FILTER_PASS
			row.add_child(unfinished)
		if path in changed_on_main:
			var warning := LabUI.chip("main changed since you edited this", LabUI.BAD, 12)
			row.add_child(warning)
			row.add_child(LabUI.button("Compare", _open_compare.bind(path)))
		var discard := Button.new()
		discard.text = "Discard"
		discard.theme_type_variation = &"FlatButton"
		discard.tooltip_text = "Drop this draft and its unfinished text; main's text plays again"
		discard.pressed.connect(func() -> void:
			if discard.text == "Discard":
				discard.text = "Discard: sure?"
				return
			_report(_drafts.discard(path)))
		row.add_child(discard)
		_list.add_child(row)


func _open_compare(path: String) -> void:
	_comparing = path
	_compare_title.text = "%s: main changed it since you started from %s" % [path.trim_prefix("res://story/"), _drafts.start_commit(path).left(8)]
	_mine.text = _drafts.texts()[path]
	_main.text = _drafts.checkout_text(path)
	_compare.show()


func _report(failed: String) -> void:
	if failed != "":
		push_error("Story Lab drafts: " + failed)
	_compare.hide()
	_fill()
	changed.emit()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			hide())
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: int in [SIDE_LEFT, SIDE_RIGHT]:
		panel.set_offset(side, 260.0 if side == SIDE_LEFT else -260.0)
	panel.set_offset(SIDE_TOP, 120.0)
	panel.set_offset(SIDE_BOTTOM, -120.0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := LabUI.label("Drafts", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(LabUI.button("Close", hide))
	var about := LabUI.label("Your edits live in your user folder until main has the same text; then they disappear. Send makes them a GitHub issue for the team.", 14, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_compare = VBoxContainer.new()
	_compare.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_compare.hide()
	box.add_child(_compare)
	_compare_title = LabUI.label("", 16, LabUI.BAD)
	_compare.add_child(_compare_title)
	var sides := HBoxContainer.new()
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sides.add_theme_constant_override("separation", 12)
	_compare.add_child(sides)
	_mine = _side(sides, "Yours")
	_main = _side(sides, "Main's now")
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	_compare.add_child(choices)
	choices.add_child(LabUI.button("Keep mine", func() -> void: _report(_drafts.keep_mine(_comparing)), &"AccentButton"))
	choices.add_child(LabUI.button("Take main's", func() -> void: _report(_drafts.discard(_comparing))))
	choices.add_child(LabUI.button("Not now", _compare.hide, &"FlatButton"))


func _side(into: Control, title: String) -> CodeEdit:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	into.add_child(box)
	box.add_child(LabUI.label(title, 14, LabUI.DIM))
	var code := CodeEdit.new()
	code.editable = false
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.gutters_draw_line_numbers = true
	code.indent_size = 4
	box.add_child(code)
	return code
