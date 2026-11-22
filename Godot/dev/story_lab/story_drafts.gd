class_name StoryDrafts
extends RefCounted
## A writer's drafts of the story files: for each res:// path, the text that replaces the file (""
## removes it), with the commit that the draft started from. They live in the user folder until
## main has the same text, so the checkout never changes. With [member to_checkout] on, edits go
## straight into the checkout instead, and no drafts are kept.

const DIR: String = "user://story_drafts/"
const INDEX: String = "drafts.json"
## The Story Lab's settings: Save to checkout, and whether its warning was shown.
const SETTINGS: String = "user://story_lab.cfg"
## The start commit of a draft made where git can't tell.
const UNKNOWN: String = "unknown"

## Where the drafts are kept: one file per path, mirroring it, and [constant INDEX].
var dir: String
## The folder that res:// paths name: "res://" in a run from the checkout.
var checkout: String = "res://"
## True: [method put] writes the checkout itself, and no drafts are kept.
var to_checkout: bool = false
## Runs git in the repo: (arguments: PackedStringArray) -> {"code": int, "out": String}.
var git: Callable = _run_git

var _texts: Dictionary[String, String] = {}
var _commits: Dictionary[String, String] = {}
# A drafts.json that doesn't read stops every write, so the drafts in it are never overwritten.
var _broken: String = ""


func _init(drafts_dir: String = DIR) -> void:
	dir = drafts_dir


## True when the Dev menu's Save to checkout is on.
static func saves_to_checkout() -> bool:
	return _setting("save_to_checkout", false)


## Remembers Save to checkout. Returns "" or what failed.
static func set_saves_to_checkout(on: bool) -> String:
	return _set_setting("save_to_checkout", on)


## True once the warning that Save to checkout changes the checkout was shown.
static func warned_about_checkout() -> bool:
	return _setting("warned_checkout", false)


## Remembers that the warning was shown. Returns "" or what failed.
static func set_warned_about_checkout() -> String:
	return _set_setting("warned_checkout", true)


## Reads the drafts from [member dir], and drops each that main now has. Returns one
## "path: what" per draft that doesn't read; while drafts.json doesn't read, nothing is written.
func load_drafts() -> PackedStringArray:
	_texts.clear()
	_commits.clear()
	_broken = ""
	var errors := PackedStringArray()
	var index_path := dir.path_join(INDEX)
	if not FileAccess.file_exists(index_path):
		return errors
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not parsed is Dictionary:
		_broken = "%s doesn't read as JSON; fix or move it to keep the drafts in %s" % [ProjectSettings.globalize_path(index_path), ProjectSettings.globalize_path(dir)]
		errors.append(_broken)
		return errors
	for path: String in parsed:
		var read := _read(_draft_file(path))
		if read.has("error"):
			errors.append("%s: the draft doesn't read: %s" % [path, read["error"]])
			continue
		_texts[path] = read["text"]
		_commits[path] = String(parsed[path])
	for path: String in _texts.keys():
		if _texts[path] == checkout_text(path):
			errors.append_array(_drop(path))
	errors.append_array(_save_index())
	return errors


## path to text of every draft; "" removes the file. Empty while [member to_checkout] is on.
func texts() -> Dictionary[String, String]:
	return _texts.duplicate()


## The paths with a draft, sorted.
func paths() -> PackedStringArray:
	var found := PackedStringArray(_texts.keys())
	found.sort()
	return found


func has(path: String) -> bool:
	return _texts.has(path)


## The commit that the draft of [param path] started from, or [constant UNKNOWN].
func start_commit(path: String) -> String:
	return _commits.get(path, UNKNOWN)


## The text of [param path] in the checkout; "" when there is no such file.
func checkout_text(path: String) -> String:
	var file := _checkout_file(path)
	if not FileAccess.file_exists(file):
		return ""
	var read := _read(file)
	if read.has("error"):
		push_error("Story drafts: %s doesn't read: %s" % [file, read["error"]])
		return ""
	return read["text"]


## The text that plays for [param path]: its draft, or else the checkout's.
func text(path: String) -> String:
	return _texts[path] if _texts.has(path) else checkout_text(path)


## Makes [param new_text] the text of [param path]; "" removes the file. A draft equal to the
## checkout's text disappears. Returns "" or what failed.
func put(path: String, new_text: String) -> String:
	if to_checkout:
		return _write_checkout(path, new_text)
	if _broken != "":
		return _broken
	if new_text == checkout_text(path):
		return "\n".join(_drop(path) + _save_index())
	var file := _draft_file(path)
	var err := DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	if err != OK:
		return "can't make %s: %s" % [file.get_base_dir(), error_string(err)]
	var failed := _write(file, new_text)
	if failed != "":
		return failed
	_texts[path] = new_text
	if not _commits.has(path):
		_commits[path] = head_commit()
	return "\n".join(_save_index())


## Renames the files in [param moves] (old path to new path) all at once, through drafts. A new
## path may be another move's old path. Returns "" or what failed.
func rename(moves: Dictionary[String, String]) -> String:
	var moved: Dictionary[String, String] = {}
	for old: String in moves:
		moved[moves[old]] = text(old)
	var failures := PackedStringArray()
	for old: String in moves:
		if not moved.has(old):
			failures.append(put(old, ""))
	for path: String in moved:
		failures.append(put(path, moved[path]))
	return "\n".join(PackedStringArray(Array(failures).filter(func(f: String) -> bool: return f != "")))


## Drops the draft of [param path]: main's text plays again. Returns "" or what failed.
func discard(path: String) -> String:
	if _broken != "":
		return _broken
	return "\n".join(_drop(path) + _save_index())


## The text of [param path] at the draft's start commit: {"text"} ("" when the file wasn't there),
## or {} when git can't tell.
func start_text(path: String) -> Dictionary:
	var commit := start_commit(path)
	if commit == UNKNOWN or git.call(PackedStringArray(["cat-file", "-e", commit + "^{commit}"]))["code"] != 0:
		return {}
	var spec := "%s:%s" % [commit, repo_path(path)]
	if git.call(PackedStringArray(["cat-file", "-e", spec]))["code"] != 0:
		return {"text": ""}
	var shown: Dictionary = git.call(PackedStringArray(["show", spec]))
	return {"text": shown["out"]} if shown["code"] == 0 else {}


## True when the checkout's file changed since the draft of [param path] started: main changed it.
func main_changed(path: String) -> bool:
	var start := start_text(path)
	return not start.is_empty() and start["text"] != checkout_text(path)


## Keeps the draft of [param path] over main's change: it starts from the checkout's commit now.
func keep_mine(path: String) -> String:
	if not _texts.has(path):
		return "%s has no draft" % path
	_commits[path] = head_commit()
	return "\n".join(_save_index())


## The commit of the checkout, or [constant UNKNOWN] where git can't tell.
func head_commit() -> String:
	var head: Dictionary = git.call(PackedStringArray(["rev-parse", "HEAD"]))
	return String(head["out"]).strip_edges() if head["code"] == 0 else UNKNOWN


## [param path] from the repo root, such as Godot/story/days/day_1.day.
static func repo_path(path: String) -> String:
	return "Godot/" + path.trim_prefix("res://")


func _drop(path: String) -> PackedStringArray:
	_texts.erase(path)
	_commits.erase(path)
	var file := _draft_file(path)
	if not FileAccess.file_exists(file):
		return PackedStringArray()
	var err := DirAccess.remove_absolute(file)
	return PackedStringArray() if err == OK else PackedStringArray(["can't remove the draft %s: %s" % [file, error_string(err)]])


func _save_index() -> PackedStringArray:
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return PackedStringArray(["can't make %s: %s" % [dir, error_string(err)]])
	var failed := _write(dir.path_join(INDEX), JSON.stringify(_commits, "\t", true))
	return PackedStringArray([failed]) if failed != "" else PackedStringArray()


func _write_checkout(path: String, new_text: String) -> String:
	var file := _checkout_file(path)
	if new_text == "":
		if not FileAccess.file_exists(file):
			return ""
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		return "" if err == OK else "can't remove %s: %s" % [file, error_string(err)]
	var err := DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	if err != OK:
		return "can't make %s: %s" % [file.get_base_dir(), error_string(err)]
	return _write(file, new_text)


func _draft_file(path: String) -> String:
	return dir.path_join(path.trim_prefix("res://"))


func _checkout_file(path: String) -> String:
	return checkout.path_join(path.trim_prefix("res://"))


# Writes and reads back; returns "" or what failed.
func _write(file: String, content: String) -> String:
	var out := FileAccess.open(file, FileAccess.WRITE)
	if out == null:
		return "can't write %s: %s" % [file, error_string(FileAccess.get_open_error())]
	out.store_string(content)
	out.close()
	var back := _read(file)
	if back.has("error"):
		return "can't read back %s: %s" % [file, back["error"]]
	if back["text"] != content:
		return "%s read back different from what was written" % file
	return ""


func _read(file: String) -> Dictionary:
	var input := FileAccess.open(file, FileAccess.READ)
	if input == null:
		return {"error": error_string(FileAccess.get_open_error())}
	return {"text": input.get_as_text()}


static func _run_git(arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var args := PackedStringArray(["-C", GitHubIssues.repo_dir()])
	args.append_array(arguments)
	var code := OS.execute("git", args, output)
	return {"code": code, "out": String(output[0]) if not output.is_empty() else ""}


static func _setting(key: String, default: bool) -> bool:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_error("Story Lab: %s doesn't read: %s" % [SETTINGS, error_string(err)])
	return config.get_value("story_lab", key, default)


static func _set_setting(key: String, value: bool) -> String:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		return "%s doesn't read: %s" % [SETTINGS, error_string(err)]
	config.set_value("story_lab", key, value)
	err = config.save(SETTINGS)
	return "" if err == OK else "can't write %s: %s" % [SETTINGS, error_string(err)]
