extends "res://tests/test.gd"
## The page of Word and WordPad (win95/rich_editor.gd): typing, Enter, Backspace, selecting with
## Shift and the arrows, Ctrl+B/I/U on a selection and for what is typed next, alignment, undo and
## redo, wrapping at the line width, and red squiggles under misspelt words.


func run() -> void:
	var editor := RichEditor.new()
	editor.line_width = 200.0
	editor.spell_check = true
	editor.size = Vector2(300, 200)
	root.add_child(editor)
	await process_frame

	_type(editor, "Dear Sir")
	_key(editor, KEY_ENTER)
	_type(editor, "Teh end")
	check("typing and Enter", editor.document.plain_text(), "Dear Sir\nTeh end")
	check("the caret follows", editor.caret, Vector2i(1, 7))
	_key(editor, KEY_BACKSPACE)
	_key(editor, KEY_BACKSPACE)
	_key(editor, KEY_BACKSPACE)
	_type(editor, "n")
	check("Backspace", editor.document.plain_text(), "Dear Sir\nTeh n")

	for i: int in 5:
		_key(editor, KEY_LEFT, false, true)
	check("Shift+Left selects", editor.document.text_between(editor.caret, editor.anchor), "Teh n")
	_key(editor, KEY_B, true)
	check("Ctrl+B bolds the selection", editor.document.all_have(Vector2i(1, 0), Vector2i(1, 5), RichDocument.BOLD), true)
	_key(editor, KEY_B, true)
	check("again unbolds it", editor.document.all_have(Vector2i(1, 0), Vector2i(1, 1), RichDocument.BOLD), false)
	_key(editor, KEY_END)
	_key(editor, KEY_I, true)
	_type(editor, "x")
	check("Ctrl+I with no selection: the next letter is italic", editor.document.format_at(editor.caret) & RichDocument.ITALIC, RichDocument.ITALIC)
	check("and the one before isn't", editor.document.paragraphs[1].formats[4] & RichDocument.ITALIC, 0)
	_key(editor, KEY_E, true)
	check("Ctrl+E centres the paragraph", editor.current_align(), RichDocument.Align.CENTER)

	editor.undo()
	check("undo takes the centring back", editor.current_align(), RichDocument.Align.LEFT)
	editor.undo()
	check("and then the typing", editor.document.plain_text(), "Dear Sir\nTeh n")
	editor.redo()
	check("redo puts it back", editor.document.plain_text(), "Dear Sir\nTeh nx")

	check("a misspelt word gets a squiggle", editor.get("_misspelt")[1], [Vector2i(0, 3), Vector2i(4, 6)])
	check("known words don't", editor.get("_misspelt")[0], [])

	editor.select_all()
	_type(editor, "one two three four five six seven eight nine ten eleven twelve")
	check("typing over a selection replaces it", editor.document.paragraphs.size(), 1)
	check("a long line wraps at the line width", (editor.get("_lines") as Array).size() > 1, true)
	editor.queue_free()
	await process_frame


func _type(editor: RichEditor, text: String) -> void:
	for c: String in text:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = c.unicode_at(0)
		editor.call(&"_gui_input", event)


func _key(editor: RichEditor, keycode: Key, ctrl := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	editor.call(&"_gui_input", event)
