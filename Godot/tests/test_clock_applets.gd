extends "res://tests/test.gd"
## The taskbar shows the computer's clock; Date/Time sets it; System shows the setup; Add/Remove
## Programs uninstalls.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload

var state: Node
var setup: Win95Setup


func run() -> void:
	var job := Job.new(customer(), 0, 0)
	game.jobs = [job] as Array[Job]
	state = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame  # _ready waits for the first frame under -s
	setup = state.setup

	test_systray()
	test_date_time()
	test_system()
	test_add_remove()

	state.free()
	game.jobs = [] as Array[Job]


func test_systray() -> void:
	var tray: Node = load("res://win95/systray.tscn").instantiate()
	root.add_child(tray)
	tray.set(&"computer", state)
	var clock: Label = tray.get_node("%Clock")
	check("the taskbar shows the computer's clock", clock.text, Win95Time.clock(state.now()))
	state.apply_settings({&"clock_offset_seconds": setup.clock_offset_seconds + 3 * 3600} as Dictionary[StringName, Variant])
	check("and follows a Date/Time change at once", clock.text, Win95Time.clock(state.now()))
	state.apply_settings({&"clock_offset_seconds": 0} as Dictionary[StringName, Variant])
	tray.free()


func test_date_time() -> void:
	var desktop: Control = load("res://win95/desktop.gd").new()  # loaded at run time, like ComputerState
	desktop.computer = state
	root.add_child(desktop)
	var sheet: Node = desktop.call(&"open", load("res://win95/applets/date_time.tscn"))
	var page: Node = sheet.get_node("%Tabs/Date & Time")
	var day1: Dictionary = state.now()
	var shown: Dictionary = page.call(&"shown")
	check("Date & Time opens on the computer's date", [shown.year, shown.month, shown.day], [day1.year, day1.month, day1.day])
	check("and changes nothing until edited", page.call(&"pending"), {})

	(sheet.get_node("%Year") as SpinBox).value = 1999
	var month: OptionButton = sheet.get_node("%Month")
	month.select(1)
	month.item_selected.emit(1)
	shown = page.call(&"shown")
	check("May 31 in February becomes its last day", [shown.year, shown.month, shown.day], [1999, 2, 28])
	month.select(11)
	month.item_selected.emit(11)
	sheet.get_node("%Calendar").emit_signal(&"day_picked", 31)
	var time: Node = sheet.get_node("%Time")
	time.emit_signal(&"time_edited", 23, 59, 0)
	time.set(&"segment", 0)
	time.call(&"step", 1)
	shown = page.call(&"shown")
	check("the hour wraps without changing the date", [shown.month, shown.day, shown.hour, shown.minute], [12, 31, 0, 59])
	time.call(&"step", -1)
	shown = page.call(&"shown")
	check("the page shows the chosen date and time", [shown.year, shown.month, shown.day, shown.hour, shown.minute], [1999, 12, 31, 23, 59])
	check("an edit enables Apply", (sheet.get_node("%Apply") as Button).disabled, false)
	var pending: Dictionary = page.call(&"pending")
	check("pending() is the offset that shows that date", pending, {&"clock_offset_seconds": state.offset_for(shown)})

	sheet.call(&"apply")
	var now: Dictionary = state.now()
	check("Apply moves the computer's clock", [now.year, now.month, now.day, now.hour, now.minute], [1999, 12, 31, 23, 59])
	shown = page.call(&"shown")
	check("and the page keeps showing it", [shown.year, shown.month, shown.day, shown.hour], [1999, 12, 31, 23])
	check("with nothing left to apply", page.call(&"pending"), {})
	desktop.free()
	state.apply_settings({&"clock_offset_seconds": 0} as Dictionary[StringName, Variant])


func test_system() -> void:
	setup.version = "4.00.950 B"
	setup.registered_owner = "Pierre"
	setup.registered_organization = "Castle Ltd"
	setup.product_id = "24261-OEM-0000000-86468"
	setup.processor = "Pentium(r)"
	setup.memory_mb = 64
	var desktop: Control = load("res://win95/desktop.gd").new()
	desktop.computer = state
	root.add_child(desktop)
	var sheet: Node = desktop.call(&"open", load("res://win95/applets/system.tscn"))
	var shown := ["%Version", "%Owner", "%Organization", "%ProductId", "%Processor", "%Memory", "%PerformanceMemory"].map(
		func(path: String) -> String: return (sheet.get_node(path) as Label).text)
	check("System shows the setup", shown, ["4.00.950 B", "Pierre", "Castle Ltd", "24261-OEM-0000000-86468", "Pentium(r)", "64.0MB RAM", "64.0 MB of RAM"])
	check("System has no Apply", (sheet.get_node("%Apply") as Button).visible, false)
	sheet.free()
	setup.registered_owner = ""
	state.job.customer.display_name = "Skater bro"
	sheet = desktop.call(&"open", load("res://win95/applets/system.tscn"))
	check("an empty owner shows the customer's name", (sheet.get_node("%Owner") as Label).text, "Skater bro")
	desktop.free()


func test_add_remove() -> void:
	var desktop: Control = load("res://win95/desktop.gd").new()
	desktop.computer = state
	root.add_child(desktop)
	var sheet: Node = desktop.call(&"open", load("res://win95/applets/add_remove_programs.tscn"))
	var list: ItemList = sheet.get_node("%Programs")
	var add_remove: Button = sheet.get_node("%AddRemove")
	check("Add/Remove lists the folders in Program Files", items(list), ["Accessories", "Raytrace 2"])
	check("with Add/Remove... greyed until one is selected", add_remove.disabled, true)
	list.select(1)
	list.item_selected.emit(1)
	add_remove.pressed.emit()
	var box: Node = desktop.call(&"active_window")
	check("Add/Remove... asks first", box != sheet and box.get_node("%Text").text.contains("'Raytrace 2'"), true)
	check("and removes nothing yet", setup.file_at("C:\\Program Files\\Raytrace 2") != null, true)
	for button: Button in box.get_node("%Buttons").get_children():
		if button.text == "Yes":
			button.pressed.emit()
	check("Yes uninstalls the program at once", setup.file_at("C:\\Program Files\\Raytrace 2"), null)
	check("with its Start Menu shortcuts", setup.file_at("C:\\WINDOWS\\Start Menu\\Programs").children.map(func(f: Win95File) -> String: return f.name), ["Notepad"])
	check("and the list follows", [items(list), add_remove.disabled], [["Accessories"], true])
	desktop.free()


func items(list: ItemList) -> Array[String]:
	var names: Array[String] = []
	for i in list.item_count:
		names.append(list.get_item_text(i))
	return names


func customer() -> Customer:
	var raytrace := folder("Raytrace 2", [file("RAYTRACE.EXE")])
	var shortcut := file("Raytrace")
	shortcut.target = "C:\\Program Files\\Raytrace 2\\RAYTRACE.EXE"
	var notepad := file("Notepad")
	notepad.target = "C:\\WINDOWS\\NOTEPAD.EXE"
	var start_menu := folder("Start Menu", [folder("Programs", [shortcut, notepad])])
	var c := Customer.new()
	c.computer = Computer.new()
	c.computer.win95_setup = Win95Setup.new()
	c.computer.win95_setup.drive_c = [folder("WINDOWS", [start_menu]), folder("Program Files", [raytrace, folder("Accessories", [])])]
	c.problem = Problem.new()
	return c


func file(file_name: String) -> Win95File:
	var f := Win95File.new()
	f.name = file_name
	return f


func folder(folder_name: String, children: Array[Resource]) -> Win95File:
	var f := Win95File.new()
	f.name = folder_name
	f.is_folder = true
	f.children = children
	return f
