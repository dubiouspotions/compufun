extends "res://tests/test.gd"
## The Story Lab's condition editor writes the Condition that its rows of facts and its days say,
## says it as a sentence, and names a new fact the way flags are written.


func run() -> void:
	var editor := StoryConditionEditor.make(PackedStringArray(["skater_cambion", "gone_skater_bro"]))
	root.add_child(editor)
	await process_frame
	var said: Array[Condition] = []
	editor.changed.connect(func(when: Condition) -> void: said.append(when))
	check("empty means always", [editor.condition(), StoryConditionEditor.describe(null)], [null, "always"])

	var parsed := StoryFormat.parse_condition("skater_cambion, not gone_skater_bro, days 2-4", "test")
	editor.edit(parsed.value)
	check("it shows a condition and gives it back", StoryFormat.write_condition(editor.condition()), "skater_cambion, not gone_skater_bro, days 2-4")
	check("in words", StoryConditionEditor.describe(editor.condition()), "skater cambion, not gone skater bro, on days 2 to 4")

	_button(editor, "+ another fact").pressed.emit()
	var pickers := editor.find_children("*", "StoryFactPicker", true, false)
	var picker := pickers[pickers.size() - 1] as StoryFactPicker
	var search: LineEdit = picker.list_host.find_children("*", "LineEdit", true, false)[0]
	check("the new fact's search opens in the editor, under its row", [picker.is_open(), editor.is_ancestor_of(search)], [true, true])
	search.text = "Skater told us"
	search.text_changed.emit(search.text)
	var list: ItemList = picker.list_host.find_children("*", "ItemList", true, false)[0]
	check("the field keeps the writer's words while typing", [search.text, list.get_item_text(0)], ["Skater told us", "New fact: Skater told us"])
	search.text_submitted.emit(search.text)
	check("a new fact, named in plain words, becomes a flag name when picked", [editor.condition().need_flags, picker.is_open()], [[&"skater_cambion", &"skater_told_us"], false])
	check("each change is signalled", said.size(), 1)

	var days: Array = editor.find_children("*", "OptionButton", true, false).filter(func(o: OptionButton) -> bool: return o.item_count == 7)
	(days[0] as OptionButton).select(4)
	(days[0] as OptionButton).item_selected.emit(4)
	check("a first day after the last moves the last along", [editor.condition().from_day, editor.condition().to_day], [5, 5])
	check("one day in words", StoryConditionEditor.describe(editor.condition()).ends_with("on day 5"), true)

	for cut: Node in editor.find_children("*", "Button", true, false):
		if (cut as Button).text == "x":
			(cut as Button).pressed.emit()
	(days[0] as OptionButton).select(0)
	(days[0] as OptionButton).item_selected.emit(0)
	(days[1] as OptionButton).select(6)
	(days[1] as OptionButton).item_selected.emit(6)
	check("no facts and every day is always again", editor.condition(), null)

	check("typing a name writes it as a flag", [StoryFactPicker.slug("Skater told us!"), StoryFactPicker.slug("a - b")], ["skater_told_us", "a_b"])
	check("a flag in words", StoryFactPicker.humanize(&"gone_skater_bro"), "gone skater bro")


func _button(under: Node, text: String) -> Button:
	for node: Node in under.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null
