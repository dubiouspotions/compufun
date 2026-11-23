class_name StoryFiles
extends RefCounted
## Loads the week from the story files (docs/dialogue.md), with a writer's drafts over them.

const DAYS_DIR: String = "res://story/days/"
const ERRANDS_DIR: String = "res://story/errands/"
const PROBLEMS_DIR: String = StoryFormat.PROBLEM_FILES_DIR
const DAYS: int = 7

## The loaded week: the days 1 to 7 in order, each with its errands, its problems, and one
## "path:line: what" per error. A week with errors must not play.
class Week:
	extends RefCounted
	var days: Array[Day] = []
	## The problem of every problem file, by id: the cached res://problems/<id>.tres, or a Problem
	## made in memory, text only, for a problem file without one. Holding them keeps the cached
	## resources, and so their text, alive.
	var problems: Dictionary[StringName, Problem] = {}
	var errors: PackedStringArray = []
	# The text of each problem file, by id, as it parsed.
	var _texts: Dictionary[StringName, Problem] = {}

	## Fills the text of this week's problem files into [member problems]. [method load_week] does
	## it for a week without errors; call it again to put this week's text back after another week
	## filled the same cached resources.
	func fill_problems() -> void:
		for id: StringName in _texts:
			problems[id].take_text(_texts[id])


## The week from the story files. [param drafts] maps a res:// path to the text that replaces the
## file; an empty text removes the file, and a path that no file has adds one. Without errors, the
## text of the problem files goes into their Problem resources at once (see [member Week.problems]),
## so every reader of a problem sees it.
static func load_week(drafts: Dictionary[String, String] = {}) -> Week:
	var week := Week.new()
	_load_problems(week, drafts)
	for n: int in range(1, DAYS + 1):
		var path := "%sday_%d.day" % [DAYS_DIR, n]
		var text := _text(path, drafts, week.errors)
		if text == "":
			week.errors.append("%s: missing" % path)
			var empty := Day.new()
			empty.number = n
			week.days.append(empty)
			continue
		var parsed := StoryFormat.parse_day(text, path)
		week.errors.append_array(parsed.errors)
		week.days.append(parsed.value as Day)
	for path: String in files(ERRANDS_DIR, ".errand", drafts):
		var parsed := StoryFormat.parse_errand(_text(path, drafts, week.errors), path, week.problems)
		week.errors.append_array(parsed.errors)
		var errand := parsed.value as Errand
		if errand.day_number() >= 1 and errand.day_number() <= DAYS:
			week.days[errand.day_number() - 1].errands.append(errand)
	if week.errors.is_empty():
		week.fill_problems()
	return week


# Parses the problem files into [param week], each with its .tres; a .tres without a problem file is
# an error.
static func _load_problems(week: Week, drafts: Dictionary[String, String]) -> void:
	for path: String in files(PROBLEMS_DIR, ".problem", drafts):
		var parsed := StoryFormat.parse_problem(_text(path, drafts, week.errors), path)
		week.errors.append_array(parsed.errors)
		var text := parsed.value as Problem
		var resource_path := StoryFormat.PROBLEMS_DIR + text.short_name + ".tres"
		var problem := text
		if ResourceLoader.exists(resource_path):
			problem = load(resource_path) as Problem
			if problem == null:
				week.errors.append("%s: doesn't load as a Problem, so %s has no mechanics" % [resource_path, path])
				problem = text
			elif problem.short_name != text.short_name:
				week.errors.append("%s: short_name is '%s', not its file name '%s'" % [resource_path, problem.short_name, text.short_name])
		week.problems[text.short_name] = problem
		week._texts[text.short_name] = text
	for file: String in ResourceLoader.list_directory(StoryFormat.PROBLEMS_DIR):
		if file.ends_with(".tres") and not week.problems.has(StringName(file.get_basename())):
			week.errors.append("%s%s: no problem file %s%s.problem holds its text" % [StoryFormat.PROBLEMS_DIR, file, PROBLEMS_DIR, file.get_basename()])


## The res:// paths of the files in [param dir] that end in [param extension], with [param drafts]
## over them, sorted by name.
static func files(dir: String, extension: String, drafts: Dictionary[String, String] = {}) -> PackedStringArray:
	var found := PackedStringArray()
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(extension) and drafts.get(dir + name, "-") != "":
			found.append(dir + name)
	for path: String in drafts:
		if path.get_base_dir() + "/" == dir and path.ends_with(extension) and drafts[path] != "" and path not in found:
			found.append(path)
	found.sort()
	return found


static func _text(path: String, drafts: Dictionary[String, String], errors: PackedStringArray) -> String:
	if drafts.has(path):
		return drafts[path]
	if not FileAccess.file_exists(path):
		return ""
	var text := FileAccess.get_file_as_string(path)
	if text == "" and FileAccess.get_open_error() != OK:
		errors.append("%s: can't read it: %s" % [path, error_string(FileAccess.get_open_error())])
	return text
