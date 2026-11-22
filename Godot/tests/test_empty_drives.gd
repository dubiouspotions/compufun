extends "res://tests/test.gd"
## Opening A: with no floppy, or D: (it never holds a disc), shows "not accessible" with Retry and
## Cancel; Retry opens A: once a floppy is in, and a floppy in A: opens it at once.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time, and IconView and FileIcon go untyped: they name the Game autoload


func run() -> void:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var customer := Customer.new()
	customer.computer = computer
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	await process_frame
	var desktop: Node = win95.get_node("Desktop")
	var setup: Win95Setup = win95.get_node("ComputerState").setup

	var icons: Node = win95.get_node("Desktop/DesktopIcons")
	icons.item_opened.emit(icons.get_node("MyComputer"))
	check("My Computer opens", titles(desktop), ["My Computer"])
	var drives: Node = desktop.windows()[0].items

	open(drives, "(D:)")
	check("an empty D: says it is not ready", message(desktop), ["D:\\", "D:\\ is not accessible.\n\nThe device is not ready.", ["Retry", "Cancel"]])
	press(desktop, "Retry")
	check("Retry on an empty D: says so again", message(desktop)[0], "D:\\")
	press(desktop, "Cancel")
	await process_frame
	check("Cancel closes the box", titles(desktop), ["My Computer"])

	open(drives, "(A:)")
	check("an empty A: says it is not ready", message(desktop), ["A:\\", "A:\\ is not accessible.\n\nThe device is not ready.", ["Retry", "Cancel"]])
	setup.floppy_in_a = true
	press(desktop, "Retry")
	await process_frame
	check("Retry with a floppy in opens A:", titles(desktop), ["My Computer", "3\u00bd Floppy (A:)"])

	desktop.windows()[1].close()
	await process_frame
	open(drives, "(A:)")
	check("a floppy in A: opens it", titles(desktop), ["My Computer", "3\u00bd Floppy (A:)"])

	root.remove_child(win95)
	win95.free()


func titles(desktop: Node) -> Array:
	return desktop.windows().filter(func(w: Control) -> bool: return w.visible).map(func(w: Control) -> String: return w.get_node("%TitleBar").title)


# The title, text and buttons of the message box in front.
func message(desktop: Node) -> Array:
	var box: Control = desktop.windows()[-1]
	if not box.has_method(&"show_message"):
		return ["no message box in front: %s" % titles(desktop)]
	return [box.get_node("%TitleBar").title, box.get_node("%Text").text, box.get_node("%Buttons").get_children().map(func(b: Button) -> String: return b.text)]


func press(desktop: Node, button: String) -> void:
	for b: Button in desktop.windows()[-1].get_node("%Buttons").get_children():
		if b.text == button:
			b.pressed.emit()
			return
	check("a %s button on the box in front" % button, message(desktop), [])


func open(view: Node, drive: String) -> void:
	for item in view.get_children():
		if item.has_meta(&"win95_file") and (item.get_meta(&"win95_file") as Win95File).name.ends_with(drive):
			view.item_opened.emit(item)
			return
	check("%s in My Computer" % drive, view.get_children().map(func(item: Node) -> String: return item.name), [])
