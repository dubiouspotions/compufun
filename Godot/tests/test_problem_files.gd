extends "res://tests/test.gd"
## The problem files (story/problems/<id>.problem): they read and write back the same text, name the
## line of an error, and the week fills their text into the cached problems/<id>.tres, so CompuFunDB
## and the post-its read the same strings as before. A draft plays at once, a refused week keeps the
## text, and a problem file without a .tres loads as text only, which the story check lists.

const PROBLEM_FILE: String = "res://story/problems/%s.problem"
const RESOURCE: String = "res://problems/%s.tres"
## Every problem's post-it and symptoms, as CompuFunDB showed them before they moved to the files.
const TODAY: Dictionary = {
	"bad_ram": ["Stops before Windows starts", ["Memory test fails at startup", "Halts before Windows"]],
	"bootfloppy": ["Computer doesn't start - just a bunch of text", ["Non-System disk error at startup", "Floppy in drive A:"]],
	"broken_hard_drive": ["Blue screen of death", ["Blue screen at startup", "Hard drive clicks"]],
	"defrag": ["Mouse glitches", ["Slow to boot", "Mouse pointer jumps", "Folders open slowly"]],
	"desktop_prank": ["Icons don't open", ["Desktop icons don't respond", "Wallpaper is a picture of the desktop", "Icons are in a folder hidden in a corner"]],
	"dust_overheat": ["Windows starts and turns off", ["Hangs and reboots at startup", "Computer overheating"]],
	"email_virus": ["CD-tray keeps on opening and closing", ["CD-tray keeps on opening and closing", "If connected to the internet the mouse moves on its own"]],
	"gpu_overheating": ["Visual artifacting", ["Visual artifacting on screen", "GPU overheating"]],
	"hamster": ["Computer smells weird and won't start", ["Hangs and reboots at startup", "Computer overheating"]],
	"hardware_puzzle": ["Computer doesn't start", ["Computer doesn't start at all when clicking start button", "User has tampered with the hardware"]],
	"inverted_colors": ["Computer's colours have changed", ["Window colours changed drastically"]],
	"no_sound": ["Can't hear sounds", ["Sound is muted"]],
	"noimages": ["Can't open images", ["Image program not found", "Programs won't start", "Customer changed something", "Start menu shortcut broken"]],
	"no_parts": ["Take a closer look at the super computer", ["No parts in the computer", "Works without any parts"]],
	"organ_failure": ["None", ["Blood comes out of the chassi", "Sound of heartbeat from computer"]],
	"screensaver": ["Wants a good-looking screensaver", ["No screensaver set"]],
}


func run() -> void:
	_round_trip()
	_errors()
	_week_fills_the_resources()
	_drafts()
	_text_only()


func _round_trip() -> void:
	var files := StoryFiles.files(StoryFiles.PROBLEMS_DIR, ".problem")
	check("a problem file per problem", files.size(), TODAY.size())
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		var parsed := StoryFormat.parse_problem(text, path)
		check("%s parses" % path, parsed.errors, PackedStringArray())
		check("%s writes back the same text" % path, StoryFormat.write_problem(parsed.value), text)
	var dust := StoryFormat.parse_problem(FileAccess.get_file_as_string(PROBLEM_FILE % "dust_overheat"), PROBLEM_FILE % "dust_overheat").value as Problem
	check("a symptom shows", dust.symptom_shows["Computer overheating"], "the fan is full of dust in the Workview")
	check("and has a category", dust.symptom_categories["Computer overheating"], "On the computer")
	var categories: Dictionary[String, String] = {}
	for path: String in files:
		var problem := StoryFormat.parse_problem(FileAccess.get_file_as_string(path), path).value as Problem
		for symptom: String in problem.symptoms:
			var category: String = problem.symptom_categories.get(symptom, "")
			check("%s: '%s' has a category" % [path, symptom], category != "", true)
			check("%s: '%s' is in the category that the other problems give it" % [path, symptom], categories.get(symptom, category), category)
			categories[symptom] = category
	check("the steps", [dust.hardware_steps.size(), dust.hardware_steps[0], dust.software_steps], [5, "Remove the computer shell", PackedStringArray()])
	check("text only, named by its file", [dust.short_name, dust.resource_path, dust.broken_part], [&"dust_overheat", PROBLEM_FILE % "dust_overheat", null])


func _errors() -> void:
	var path := PROBLEM_FILE % "bad_one"
	var text := "symptoms:\n\t\tshows: too early\n\tOne\n\tOne\n\t\tsays: what\nhardware steps:\n\tStep\n\t\tunder it\nsoftware steps: inline\ncolour: red\n"
	check("every error names its line", StoryFormat.parse_problem(text, path).errors, PackedStringArray([
		path + ":1: no 'post-it:' text, which the post-it shows",
		path + ":2: 'shows:' before any symptom",
		path + ":4: the symptom 'One' a second time",
		path + ":5: under a symptom go only 'shows:', how it shows in the game, and 'category:', its heading in CompuFunDB",
		path + ":8: a step is one line, with nothing under it",
		path + ":9: 'software steps:' takes one entry per line, under it",
		path + ":10: 'colour: red' is not a key here; the keys are post-it, symptoms, hardware steps, software steps, notes",
	]))
	var removed: Dictionary[String, String] = {PROBLEM_FILE % "no_sound": ""}
	check("a .tres without a problem file is an error", Array(StoryFiles.load_week(removed).errors).has("res://problems/no_sound.tres: no problem file res://story/problems/no_sound.problem holds its text"), true)


func _week_fills_the_resources() -> void:
	check("the week loaded", game.story_errors, PackedStringArray())
	check("it holds every problem", game.week.problems.size(), TODAY.size())
	for id: String in TODAY:
		var problem := load(RESOURCE % id) as Problem
		check("%s: the cached .tres is the week's" % id, problem == game.week.problems[StringName(id)], true)
		check("%s: its post-it and symptoms, as before" % id, [problem.perceived_issue, problem.symptoms], [TODAY[id][0], PackedStringArray(TODAY[id][1])])
	var job := Job.new(load("res://customers/skater_bro.tres"), load(RESOURCE % "dust_overheat"), 0, 0)
	check("the post-it reads it", job.perceived_issue(), "Windows starts and turns off")


func _drafts() -> void:
	var no_sound := load(RESOURCE % "no_sound") as Problem
	var text := FileAccess.get_file_as_string(PROBLEM_FILE % "no_sound")
	var drafts: Dictionary[String, String] = {PROBLEM_FILE % "no_sound": text.replace("post-it: Can't hear sounds", "post-it: Silent as a mouse")}
	check("a problem draft loads", game.load_story(drafts), PackedStringArray())
	check("it plays at once, in the cached resource", no_sound.perceived_issue, "Silent as a mouse")

	var crowded := drafts.duplicate()
	crowded[PROBLEM_FILE % "no_sound"] = text.replace("post-it: Can't hear sounds", "post-it: Refused")
	for code: String in ["0697", "0698", "0699"]:
		crowded["res://story/errands/%s_hat_guy.errand" % code] = "customer: hat_guy\ncomputer: none\n"
	check("a week that the game refuses", game.load_story(crowded).is_empty(), false)
	check("keeps the text of the week that plays", no_sound.perceived_issue, "Silent as a mouse")
	check("without drafts, the file's text", [game.load_story(), no_sound.perceived_issue], [PackedStringArray(), "Can't hear sounds"])


func _text_only() -> void:
	var drafts: Dictionary[String, String] = {
		PROBLEM_FILE % "wobbly_desk": "post-it: The desk wobbles\nsymptoms:\n\tThe monitor shakes\n",
		PROBLEM_FILE % "lonely": "post-it: Nobody brings it\n",
		"res://story/errands/0599_hat_guy.errand": "customer: hat_guy\nproblem: wobbly_desk\n\n== drop-off\n(neutral) It wobbles.\n",
	}
	var week := StoryFiles.load_week(drafts)
	check("a problem file without a .tres loads", week.errors, PackedStringArray())
	var errand := week.days[4].alternatives("0599")[0] as Errand
	check("as text only, which the errand names", [errand.problem == week.problems[&"wobbly_desk"], errand.problem.perceived_issue, errand.problem.symptoms, errand.problem.resource_path], [true, "The desk wobbles", PackedStringArray(["The monitor shakes"]), PROBLEM_FILE % "wobbly_desk"])
	check("an errand file names it back", StoryFormat.write_errand(errand).begins_with("customer: hat_guy\nproblem: wobbly_desk\n"), true)
	var links := "\n".join(StoryCheck.missing_links(week))
	check("the story check lists it without mechanics", links.contains("res://story/errands/0599_hat_guy.errand names the problem wobbly_desk, which has no repair mechanics: no res://problems/wobbly_desk.tres."), true)
	check("and a problem file that no errand names", links.contains("res://story/problems/lonely.problem: no errand names the problem lonely."), true)
	check("nothing of it reached the folder of resources", ResourceLoader.exists(RESOURCE % "wobbly_desk"), false)
