extends "res://tests/test.gd"
## The title bar shows the "?" button only on windows that ask for it, such as property sheets.


func run() -> void:
	var bar: Node = load("res://win95/title_bar.tscn").instantiate()
	root.add_child(bar)
	await process_frame
	var help: Control = bar.get_node("%Help")
	check("help hidden by default", help.visible, false)
	bar.set(&"show_help", true)
	check("show_help shows it", help.visible, true)
	var sheet: Node = load("res://win95/property_sheet.tscn").instantiate()
	check("property sheets show it", sheet.get_node("%TitleBar").get(&"show_help"), true)
	sheet.free()
