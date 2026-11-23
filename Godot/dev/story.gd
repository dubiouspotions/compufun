extends SceneTree
## Prints the story check of the week from the story files. Run from Godot/:
##   godot --headless -s res://dev/story.gd                     the missing links of the week
##   godot --headless -s res://dev/story.gd -- outline 0102     the errand files of errand code 0102
##   godot --headless -s res://dev/story.gd -- outline          every errand file
##   godot --headless -s res://dev/story.gd -- week-page <file>  the wiki's "The Week" page
## Exits 1 when a story file has errors.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var week := StoryFiles.load_week()
	if not args.is_empty() and args[0] == "week-page":
		if args.size() < 2:
			printerr("week-page needs the path of the Markdown file to write")
			quit(2)
			return
		var dates := range(1, StoryFiles.DAYS + 1).map(func(n: int) -> Dictionary: return root.get_node("Game").call("date_of", n))
		var commit := OS.get_environment("GITHUB_SHA").left(8) if OS.has_environment("GITHUB_SHA") else "(local)"
		var page := StoryWeekPage.markdown(week, dates, StoryCheck.missing_links(week), commit)
		var file := FileAccess.open(args[1], FileAccess.WRITE)
		if file == null:
			printerr("can't write %s: %s" % [args[1], error_string(FileAccess.get_open_error())])
			quit(1)
			return
		file.store_string(page)
		file.close()
		print("wrote %s, %d bytes" % [args[1], page.length()])
	elif not args.is_empty() and args[0] == "outline":
		for d: Day in week.days:
			for errand: Errand in d.errands:
				if args.size() < 2 or errand.code == args[1] or errand.file_name() == args[1]:
					print("# %s\n%s" % [errand.file, StoryFormat.write_errand(errand)])
	else:
		var links := StoryCheck.missing_links(week)
		for link: String in links:
			print("- " + link)
		print("%d missing links." % links.size())
	for error: String in week.errors:
		printerr("ERROR: " + error)
	quit(1 if not week.errors.is_empty() else 0)
