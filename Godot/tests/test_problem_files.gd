extends "res://tests/test.gd"
## The problem files (story/problems/<id>.problem): they read and write back the same text, name the
## line of an error, and the week fills their text into the cached problems/<id>.tres, so CompuFunDB
## and the post-its read the files' text. A draft plays at once, a refused week keeps the
## text, and a problem file without a .tres loads as text only, which the story check lists.

const PROBLEM_FILE: String = "res://story/problems/%s.problem"
const RESOURCE: String = "res://problems/%s.tres"


# A problem's checks, each with how it fails, read and written back as they were.
func _problem_checks() -> void:
	var path := PROBLEM_FILE % "bootfloppy"
	var text := "post-it: Won't start\nsymptoms:\n\tStops at a message\nchecks:\n\tyes: Floppy in drive A:\n\t\tshows: it sticks out\n\tno: Windows starts\n"
	var parsed := StoryFormat.parse_problem(text, path)
	var problem := parsed.value as Problem
	check("checks parse", [parsed.errors, problem.checks, problem.check_yes, problem.check_shows], [PackedStringArray(), PackedStringArray(["Floppy in drive A:", "Windows starts"]), {"Floppy in drive A:": true, "Windows starts": false}, {"Floppy in drive A:": "it sticks out"}])
	check("and write back as they were", StoryFormat.write_problem(problem), text)
	var bare := StoryFormat.parse_problem("post-it: x\nchecks:\n\tWindows starts\n", path).value as Problem
	check("a check without yes: or no: is a no:", bare.check_yes, {"Windows starts": false})
	var twice := StoryFormat.parse_problem("post-it: x\nchecks:\n\tA\n\tA\n", path)
	check("a check twice is an error", twice.errors, PackedStringArray([path + ":4: the check 'A' a second time"]))


func run() -> void:
	_round_trip()
	_problem_checks()
	_errors()
	_week_fills_the_resources()
	_drafts()
	_text_only()


func _round_trip() -> void:
	var files := StoryFiles.files(StoryFiles.PROBLEMS_DIR, ".problem")
	check("a problem file per problem", files.size(), Array(ResourceLoader.list_directory("res://problems/")).filter(func(f: String) -> bool: return f.ends_with(".tres")).size())
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		var parsed := StoryFormat.parse_problem(text, path)
		check("%s parses" % path, parsed.errors, PackedStringArray())
		check("%s writes back the same text" % path, StoryFormat.write_problem(parsed.value), text)
	var dust := StoryFormat.parse_problem(FileAccess.get_file_as_string(PROBLEM_FILE % "dust_overheat"), PROBLEM_FILE % "dust_overheat").value as Problem
	check("a check shows how it fails", dust.check_shows.has("CPU fan is clean and spins freely"), true)
	check("the steps", [dust.hardware_steps.size(), dust.hardware_steps[0], dust.software_steps], [4, "Open case", PackedStringArray()])
	check("text only, named by its file", [dust.short_name, dust.resource_path, dust.broken_part], [&"dust_overheat", PROBLEM_FILE % "dust_overheat", null])


func _errors() -> void:
	var path := PROBLEM_FILE % "bad_one"
	var text := "symptoms:\n\t\tshows: too early\n\tOne\n\tOne\n\t\tsays: what\nhardware steps:\n\tStep\n\t\tunder it\nsoftware steps: inline\ncolour: red\n"
	check("every error names its line", StoryFormat.parse_problem(text, path).errors, PackedStringArray([
		path + ":1: no 'post-it:' text, which the post-it shows",
		path + ":2: 'shows:' before any symptom",
		path + ":4: the symptom 'One' a second time",
		path + ":5: under a symptom goes only 'shows:' and how it shows in the game",
		path + ":8: a step is one line, with nothing under it",
		path + ":9: 'software steps:' takes one entry per line, under it",
		path + ":10: 'colour: red' is not a key here; the keys are post-it, cause, symptoms, checks, hardware steps, software steps, notes",
	]))
	var removed: Dictionary[String, String] = {PROBLEM_FILE % "no_sound": ""}
	check("a .tres without a problem file is an error", Array(StoryFiles.load_week(removed).errors).has("res://problems/no_sound.tres: no problem file res://story/problems/no_sound.problem holds its text"), true)


func _week_fills_the_resources() -> void:
	check("the week loaded", game.story_errors, PackedStringArray())
	for path: String in StoryFiles.files(StoryFiles.PROBLEMS_DIR, ".problem"):
		var id := path.get_file().get_basename()
		var file := StoryFormat.parse_problem(FileAccess.get_file_as_string(path), path).value as Problem
		var problem := load(RESOURCE % id) as Problem
		check("%s: the cached .tres is the week's" % id, problem == game.week.problems[StringName(id)], true)
		check("%s: its text is the file's" % id, [problem.perceived_issue, problem.symptoms, problem.checks, problem.hardware_steps, problem.software_steps], [file.perceived_issue, file.symptoms, file.checks, file.hardware_steps, file.software_steps])
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
