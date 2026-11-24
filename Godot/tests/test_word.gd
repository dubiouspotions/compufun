extends "res://tests/test.gd"
## Word 97 (win95/office/word.tscn) on a customer's computer: WINWORD.EXE opens "Microsoft Word -
## Document1"; a .doc opens, takes bold from the Bold button and centring from Center, and Save
## writes RTF into the running copy; WordPad opens the same file with the bold and the centring;
## Word's toolbar follows the caret, its status bar shows the line, and a misspelt word gets a squiggle.

const WORD_PATH := "C:\\Program Files\\Microsoft Office\\Office\\WINWORD.EXE"


func run() -> void:
	var job := Job.new(load("res://customers/retired_accountant.tres"), null, 0, 0)
	game.jobs = [job] as Array[Job]
	var setup: Win95Setup = game.setup_for(job)
	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	game.set_powered(job, true)
	game.connect_cable(job)
	await process_frame
	var win95: Control = bench._desktops.get(job)
	var state: Node = win95.get_node("%ComputerState")
	var desktop: Node = win95.get_node("Desktop")
	(win95.get("_boot") as Node).finished.emit()

	var program := Win95File.new()
	program.name = "WINWORD.EXE"
	program.program = load("res://win95/office/word.tscn")
	var word_file: Win95File = state.call(&"install", program, "Microsoft Office")
	var letter := Win95File.new()
	letter.name = "letter.doc"
	letter.contents = "Dear Sir,\nThe paperclip is gone."
	setup.desktop.append(letter)

	win95.call(&"open_file", word_file)
	var word := _front(desktop)
	check("WINWORD.EXE opens Word", word.get_node("%TitleBar").title, "Microsoft Word - Document1")
	word.call(&"open_file", letter, state)
	check("the letter opens in it", word.get_node("%TitleBar").title, "Microsoft Word - letter.doc")
	var text: RichEditor = word.get_node("%Text")
	check("as plain paragraphs", text.document.plain_text(), "Dear Sir,\nThe paperclip is gone.")

	text.anchor = Vector2i(0, 0)
	text.caret = Vector2i(0, 9)
	(word.call(&"tool", &"bold") as Button).pressed.emit()
	(word.call(&"tool", &"center") as Button).pressed.emit()
	check("Bold and Center change the document", [text.document.all_have(Vector2i(0, 0), Vector2i(0, 9), RichDocument.BOLD), text.current_align()],
			[true, RichDocument.Align.CENTER])
	check("and their buttons stay pushed in", [(word.call(&"tool", &"bold") as Button).button_pressed, (word.call(&"tool", &"center") as Button).button_pressed], [true, true])
	check("unsaved", word.call(&"_is_dirty"), true)
	word.call(&"save")
	check("Save writes RTF into the running copy", [Rtf.is_rtf(letter.contents), letter.contents.contains("{\\b\\fs20 Dear Sir,}"), word.call(&"_is_dirty")], [true, true, false])

	text.caret = Vector2i(1, 4)
	text.anchor = text.caret
	text.caret_moved.emit()
	check("the toolbar follows the caret", (word.call(&"tool", &"bold") as Button).button_pressed, false)
	check("the status bar shows its line and column", [(word.get("_cells")["Ln"] as Label).text, (word.get("_cells")["Col"] as Label).text], ["Ln 2", "Col 5"])
	text.type_text("posessed ")
	check("a misspelt word gets a squiggle", text.get("_misspelt")[1].has(Vector2i(4, 12)), true)
	word.call(&"close")

	var wordpad: Control = desktop.call(&"open", load("res://win95/wordpad.tscn"))
	wordpad.call(&"open_file", letter, state)
	var page: RichEditor = wordpad.get_node("%Text")
	check("WordPad opens Word's file", page.document.plain_text(), "Dear Sir,\nThe paperclip is gone.")
	check("with the bold and the centring", [page.document.all_have(Vector2i(0, 0), Vector2i(0, 9), RichDocument.BOLD), page.document.paragraphs[0].align],
			[true, RichDocument.Align.CENTER])
	game.jobs = [] as Array[Job]
	bench.free()


func _front(desktop: Node) -> Control:
	var windows: Array = desktop.call(&"windows")
	return windows.filter(func(w: Control) -> bool: return w.visible and not w.is_queued_for_deletion()).back()
