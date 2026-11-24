extends "res://tests/test.gd"
## Office on a customer's computer: its install (C:\Program Files, the Start menu, StartUp), the
## documents that the customer opened last, File > Properties' Summary kept with the file, and the
## Shortcut Bar docked at the top right.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: its scripts name the Game autoload
const OFFICE_WINDOW := "res://win95/office/office_window.tscn"


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
