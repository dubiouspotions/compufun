class_name StoryFiles
extends RefCounted
## Loads the week from the story files (docs/dialogue.md), with a writer's drafts over them.

const DAYS_DIR: String = "res://story/days/"
const ERRANDS_DIR: String = "res://story/errands/"
const DAYS: int = 7

## The loaded week: the days 1 to 7 in order, each with its errands, and one "path:line: what" per
## problem. A week with errors must not play.
class Week:
	extends RefCounted
	var days: Array[Day] = []
	var errors: PackedStringArray = []


## The week from the story files. [param drafts] maps a res:// path to the text that replaces the
## file; an empty text removes the file, and a path that no file has adds one.
static func load_week(drafts: Dictionary[String, String] = {}) -> Week:
	var week := Week.new()
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
		var parsed := StoryFormat.parse_errand(_text(path, drafts, week.errors), path)
		week.errors.append_array(parsed.errors)
		var errand := parsed.value as Errand
		if errand.day_number() >= 1 and errand.day_number() <= DAYS:
			week.days[errand.day_number() - 1].errands.append(errand)
	return week


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
