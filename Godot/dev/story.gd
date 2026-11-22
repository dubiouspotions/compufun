extends SceneTree
## Prints the story as text. Run from Godot/:
##   godot --headless -s res://dev/story.gd               the missing links of the week
##   godot --headless -s res://dev/story.gd -- outline    every customer's conversation trees
##   godot --headless -s res://dev/story.gd -- outline skater_bro
## Exits 1 when a file doesn't load.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var errors: Array[String] = []
	var customers: Array[Customer] = preload("res://addons/dialogue_editor/dialogue_editor.gd").load_customers(errors)
	if not args.is_empty() and args[0] == "outline":
		for c: Customer in customers:
			if args.size() < 2 or c.resource_path.get_file().get_basename() == args[1]:
				print(Story.outline(c))
	else:
		var links := Story.missing_links(customers, FlagField.load_days(errors), errors)
		for link: String in links:
			print("- " + link)
		print("%d missing links." % links.size())
	for error: String in errors:
		printerr("ERROR: " + error)
	quit(1 if not errors.is_empty() else 0)
