extends "res://tests/test.gd"
## "-- --story-lab" opens the Story Lab, and "-- --errand <name>" opens that errand in it, full-window.


func run() -> void:
	var menu: Node = load("res://dev/dev_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var lab_scene: PackedScene = menu.get(&"story_lab")
	check("no Lab argument opens nothing", [menu.call(&"open_from_args", PackedStringArray(["--restore", "x.json"])), menu.call(&"_child", lab_scene)], ["", null])
	check("--story-lab opens the Lab", [menu.call(&"open_from_args", PackedStringArray(["--story-lab"])), (menu.call(&"_child", lab_scene) as CanvasItem).visible], ["", true])
	await process_frame
	var lab: Node = menu.call(&"_child", lab_scene)
	check("--errand opens the errand whose name starts so", menu.call(&"open_from_args", PackedStringArray(["--errand", "0101"])), "")
	check("in story mode", [lab.get(&"_story_mode"), lab.get(&"_selected")], [true, StoryFiles.ERRANDS_DIR + "0101_middle_manager.errand"])
	check("a name that matches no errand says so", (menu.call(&"open_from_args", PackedStringArray(["--errand", "9999"])) as String).begins_with("--errand '9999' names 0 errand files"), true)
	check("one that matches several says so", (menu.call(&"open_from_args", PackedStringArray(["--errand", "01"])) as String).contains("not one"), true)
	menu.free()
