extends "res://tests/test.gd"
## Properties on My Computer, from its icon on the desktop or inside its window, opens System
## Properties, as in Win95.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: it names the Game autoload


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
	var icons: Node = win95.get_node("Desktop/DesktopIcons")

	check("My Computer's Properties opens System", _properties_id(win95, icons, icons.get_node("MyComputer")), &"system")
	win95.call(&"_open_context", icons, icons.get_node("MyComputer"), Vector2.ZERO)
	await _properties(win95)
	check("Properties on My Computer's icon opens System Properties", titles(desktop), ["System Properties"])
	desktop.windows()[0].free()

	icons.item_opened.emit(icons.get_node("MyComputer"))
	await process_frame
	var drives: Node = desktop.windows()[0].items
	check("so does Properties inside its window", _properties_id(win95, drives, null), &"system")
	win95.call(&"_open_context", drives, null, Vector2.ZERO)
	await _properties(win95)
	check("Properties inside My Computer's window opens it too", titles(desktop), ["My Computer", "System Properties"])
	win95.free()


# Picks Properties in the open context menu, and waits out the applet's load.
func _properties(win95: Node) -> void:
	win95.call(&"_on_action", &"system")
	var waited := 0
	while waited < 120:
		await process_frame
		waited += 1


# The action of Properties in the context menu of [param item] in [param view] (null: its background).
func _properties_id(win95: Node, view: Node, item: Node) -> StringName:
	for entry in win95.call(&"_entries_for", view, item):
		if entry.label == "Properties":
			return entry.id
	return &"(no Properties)"


func titles(desktop: Node) -> Array:
	return desktop.windows().filter(func(w: Control) -> bool: return w.visible).map(func(w: Control) -> String: return w.get_node("%TitleBar").title)
