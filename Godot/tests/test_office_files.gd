extends "res://tests/test.gd"
## Office on a customer's computer: its install (C:\Program Files, the Start menu, StartUp), the
## documents that the customer opened last, File > Properties' Summary kept with the file, and the
## Shortcut Bar docked at the top right.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: its scripts name the Game autoload
const OFFICE_WINDOW := "res://win95/office/office_window.tscn"
const EXCEL_PATH := "C:\\Program Files\\Microsoft Office\\Office\\EXCEL.EXE"
const WORD_PATH := "C:\\Program Files\\Microsoft Office\\Office\\WINWORD.EXE"


func run() -> void:
	var setup := _office_setup()
	var running := setup.copy()
	check("Office goes in C:\\Program Files, made for it", [running.file_at("C:\\Program Files\\Microsoft Office\\Office\\WINWORD.EXE") != null, running.file_at("C:\\Program Files").is_folder], [true, true])
	check("Word's shortcut sits in Programs", running.file_at("C:\\WINDOWS\\Start Menu\\Programs\\Microsoft Word").target, "C:\\Program Files\\Microsoft Office\\Office\\WINWORD.EXE")
	var startup := running.file_at(Win95Setup.STARTUP_PATH)
	check("the Shortcut Bar joins the stock StartUp folder", [running.file_at("C:\\WINDOWS\\Start Menu\\Programs").children.filter(func(f: Win95File) -> bool: return f.name == "StartUp").size(), startup.children.map(func(f: Win95File) -> String: return f.name).has("Microsoft Office Shortcut Bar")], [1, true])
	check("the recent documents start with what the customer opened last", running.recent_documents.map(func(f: Win95File) -> String: return f.name), ["Letter.doc"])
	check("the setup itself stays as it was", [setup.drive_c.size(), setup.recent_documents.size()], [2, 0])

	var computer := Computer.new()
	computer.win95_setup = setup
	var customer := Customer.new()
	customer.computer = computer
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	await process_frame
	var boot: Node = win95.get("_boot")
	if is_instance_valid(boot):
		await boot.finished
		await create_timer(1.0).timeout  # the boot plays the startup sound after finished
	var state: Node = win95.get_node("ComputerState")
	var desktop: Control = win95.get_node("Desktop")
	running = state.setup
	var tasks: Array = state.tasks()
	var bar: Control = tasks[0].bar if not tasks.is_empty() else null
	check("the boot starts the Shortcut Bar from StartUp, docked at the top right above every window", [bar != null and bar.get_parent() == desktop, bar.position.y if bar else -1.0, bar.position.x + bar.size.x if bar else -1.0, bar.z_index if bar else 0], [true, 0.0, desktop.size.x - 62.0, 1])
	check("with Word's button", tasks[0].button("Microsoft Word") != null if bar else false, true)

	var window: Control = desktop.call(&"open", load(OFFICE_WINDOW))
	window.show_properties()
	var sheet: Control = window.blocked_by
	check("an untitled document's Properties: Author is the user", [sheet.get_node("%TitleBar").title, sheet.get_node("%Author").text, sheet.get_node("%Tabs").current_tab], ["Document1 Properties", "Bob", 1])
	sheet.get_node("%Ok").pressed.emit()
	await process_frame

	var letter := running.file_at("C:\\My Documents\\Letter.doc")
	window.open_file(letter, state)
	window.show_properties()
	sheet = window.blocked_by
	check("a document's Properties show its Summary", [sheet.get_node("%TitleBar").title, sheet.get_node("%Title").text, sheet.get_node("%Comments").text, sheet.get_node("%Location").text], ["Letter Properties", "To the tax office", "Send before June 15", "C:\\My Documents"])
	sheet.get_node("%Company").text = "Retired"
	sheet.get_node("%Title").text = ""
	sheet.get_node("%Ok").pressed.emit()
	await process_frame
	check("OK keeps the Summary with the file", letter.summary, {&"company": "Retired", &"comments": "Send before June 15"})
	window.show_properties()
	sheet = window.blocked_by
	sheet.get_node("%Company").text = "changed"
	sheet.get_node("%Cancel").pressed.emit()
	await process_frame
	check("Cancel keeps it as it was", letter.summary[&"company"], "Retired")
	check("Office notes what it opens among the recent documents", running.recent_documents[0], letter)

	if bar != null:
		tasks[0].stop()
		await process_frame
		check("End Task takes the bar away", is_instance_valid(bar), false)

	root.remove_child(win95)
	win95.free()

	_on_every_customer()
	await _the_office_girls_documents()


# A computer with Windows' stock Start menu, one document, Office, the Shortcut Bar and Bob's name.
func _office_setup() -> Win95Setup:
	var windows := Win95File.new()
	windows.name = "Windows"
	windows.is_folder = true
	windows.children = [load("res://win95/start_menu_stock.tres")]
	var letter := Win95File.new()
	letter.name = "Letter.doc"
	letter.contents = "{\\rtf1 Dear Sir,\\par}"
	letter.summary = {&"title": "To the tax office", &"comments": "Send before June 15"}
	var documents := Win95File.new()
	documents.name = "My Documents"
	documents.is_folder = true
	documents.children = [letter]
	var setup := Win95Setup.new()
	setup.drive_c = [windows, documents]
	setup.program_files = [load("res://win95/office/office97.tres")]
	setup.start_menu_programs = [load("res://win95/office/word_shortcut.tres"), load("res://win95/office/shortcut_bar_startup.tres")]
	setup.recently_opened = ["C:\\My Documents\\Letter.doc"]
	setup.registered_owner = "Bob"
	return setup


# Every customer's computer has Word in C:\Program Files and the Start menu, and .doc goes to Word.
func _on_every_customer() -> void:
	for path in DirAccess.get_files_at("res://customers"):
		var customer := load("res://customers/" + path) as Customer if path.ends_with(".tres") else null
		if customer == null or customer.computer == null or customer.computer.win95_setup == null:
			continue
		var setup := customer.computer.win95_setup.copy()
		var word := setup.file_at(WORD_PATH)
		check("%s has Excel, in the Start menu too" % path, [setup.file_at(EXCEL_PATH) != null and setup.file_at(EXCEL_PATH).program != null, setup.file_at("C:\\WINDOWS\\Start Menu\\Programs\\Microsoft Excel").target], [true, EXCEL_PATH])
		check("%s has Word, in the Start menu too" % path, [word != null and (load("res://win95/computer_state.gd") as GDScript).call(&"is_runnable", word), setup.file_at("C:\\WINDOWS\\Start Menu\\Programs\\Microsoft Word").target], [true, WORD_PATH])
		var state: Node = load("res://win95/computer_state.gd").new()
		state.setup = setup
		var for_doc: Array = state.programs_for("doc")
		check("%s opens .doc in Word before WordPad" % path, [for_doc[0].name, for_doc.size()], ["WINWORD.EXE", 2])
		state.free()


# Her documents open in Word from Explorer, Start > Documents and the Shortcut Bar's computer.
func _the_office_girls_documents() -> void:
	var customer: Customer = load("res://customers/office_girl.tres")
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	await process_frame
	var boot: Node = win95.get("_boot")
	if is_instance_valid(boot):
		await boot.finished
		await create_timer(1.0).timeout  # the boot plays the startup sound after finished
	var state: Node = win95.get_node("ComputerState")
	var desktop: Node = win95.get_node("Desktop")
	var invitation: Win95File = state.setup.file_at("C:\\My Documents\\Midsummer party.doc")
	check("her invitation holds its RTF file's text", invitation.contents, FileAccess.get_file_as_string("res://customers/office_girl/documents/midsummer_party.doc"))
	check("Start > Documents starts with what she opened last", state.setup.recent_documents.map(func(f: Win95File) -> String: return f.name), ["Containers May 1996.xls", "Midsummer party.doc", "Invoices May 1996.xls"])
	var bar: Variant = state.tasks()[0].bar if not state.tasks().is_empty() else null
	check("her Shortcut Bar runs, with Word and Excel", [bar != null, state.tasks()[0].button("Microsoft Excel") != null if bar != null else false], [true, true])
	win95.open_file(invitation)
	var word: Control = desktop.active_window()
	check("it opens in Word", [word.scene_file_path, word.get_node("%TitleBar").title], ["res://win95/office/word.tscn", "Microsoft Word - Midsummer party.doc"])
	check("as text that reads", word.document_text().contains("Strawberry cake"), true)
	var file_menu: PopupMenu = word.get_node("%File")
	file_menu.about_to_popup.emit()
	var items: Array[String] = []
	for i in file_menu.item_count:
		items.append(file_menu.get_item_text(i))
	check("Word's File menu lists it above Exit", items.slice(items.find("Exit") - 2), ["1 Midsummer party", "", "Exit"])
	word.show_properties()
	var sheet: Control = word.blocked_by
	check("its Properties: her Summary and Word's Template", [sheet.get_node("%Author").text, sheet.get_node("%Company").text, sheet.get_node("%Template").text], ["Sam Hilton", "Harbour Import AB", "Normal"])
	sheet.close()
	await process_frame
	win95.open_file(state.setup.file_at("C:\\My Documents\\Containers May 1996.xls"))
	var excel: Control = desktop.active_window()
	check("her containers open in Excel", [excel.scene_file_path, excel.get_node("%TitleBar").title], ["res://win95/office/excel.tscn", "Microsoft Excel - Containers May 1996.xls"])
	check("as cells that read", excel.document_text().contains("Held at customs!"), true)
	excel.show_properties()
	check("with Excel's Summary: no Template row", [excel.blocked_by.get_node("%Title").text, excel.blocked_by.get_node("%Template").visible], ["Containers", false])
	root.remove_child(win95)
	win95.free()
