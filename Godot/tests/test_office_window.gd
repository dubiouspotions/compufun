extends "res://tests/test.gd"
## The Office 97 frame that Word and Excel share (win95/office/office_window.tscn): Office's File
## menu, the title "App - Document1", toolbars built from lists, status cells, F1 asking for help,
## and the Office Assistant hook.

const ASSISTANT_SOURCE := """extends Control
var window: Node
var helped := 0
func attach(to: Node) -> void:
	window = to
	to.help_requested.connect(func() -> void: helped += 1)
"""


func run() -> void:
	var desktop: Control = load("res://win95/desktop.gd").new()
	desktop.size = Vector2(640, 480)
	root.add_child(desktop)
	var scene: PackedScene = load("res://win95/office/office_window.tscn")
	var window: Control = scene.instantiate()
	window.get_node("%TitleBar").title = "Microsoft Word"
	var helper := Control.new()
	var script := GDScript.new()
	script.source_code = ASSISTANT_SOURCE
	check("the stand-in assistant compiles", script.reload(), OK)
	helper.set_script(script)
	var packed := PackedScene.new()
	packed.pack(helper)
	window.set("assistant", packed)
	desktop.add_child(window)
	await _frames(2)

	check("titled like Office", window.get_node("%TitleBar").title, "Microsoft Word - Document1")
	var file_menu: PopupMenu = window.get_node("%File")
	var labels: Array[String] = []
	for i: int in file_menu.item_count:
		labels.append(file_menu.get_item_text(i))
	check("Office 97's File menu", labels, ["New...", "Open...", "Close", "", "Save", "Save As...", "Versions...", "",
			"Page Setup...", "Print Preview", "Print...", "", "Send To", "Properties", "", "Exit"])
	check("Save waits for a file", file_menu.is_item_disabled(file_menu.get_item_index(window.FileMenu.SAVE)), true)
	check("its shortcuts show", file_menu.get_item_accelerator(0), KEY_MASK_CTRL | KEY_N)
	check("opens maximized", window.is_maximized, true)
	var layer: Control = window.get_node("%AssistantLayer")
	check("the assistant is in its layer and attached", [layer.get_child_count(), layer.get_child(0).get("window") == window], [1, true])

	var row: HBoxContainer = window.get_node("%Standard")
	window.call(&"_add_tools", row, [[&"new", "New", null], "|", [&"bold", "Bold", func() -> void: pass, true]])
	check("the grip, a button, a gap and a button", row.get_child_count(), 6)
	var bold: Button = window.call(&"tool", &"bold")
	check("the toggle button", [bold.toggle_mode, bold.tooltip_text, bold.theme_type_variation], [true, "Bold", &"OfficeToolButton"])
	check("its icon", bold.icon.resource_path, "res://win95/office/icons/bold.png")

	var cell: Label = window.call(&"add_status_cell", "Page 1", 60.0)
	check("a status cell", [cell.text, window.get_node("%StatusBar").get_child_count()], ["Page 1", 1])

	desktop.activate(window)
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	window.call(&"_unhandled_key_input", f1)
	check("F1 asks the assistant", layer.get_child(0).get("helped"), 1)
	desktop.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
