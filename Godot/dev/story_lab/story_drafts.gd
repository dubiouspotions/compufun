class_name StoryDrafts
extends RefCounted
## A writer's drafts of the story files: for each res:// path, the text that replaces the file (""
## removes it), with the commit that the draft started from. They live in the user folder until
## main has the same text, so the checkout never changes. With [member to_checkout] on, edits go
## straight into the checkout instead, and no drafts are kept.
##
## Beside the drafts, each path can have unfinished text: the writer's text of the file that doesn't
## parse yet, kept in [constant UNFINISHED] under [member dir] so that a quit doesn't lose it. It is
## not a draft: [method texts], [method paths], [method has] and [method text] don't see it, so the
## game never plays it and Send never sends it, also while [member to_checkout] is on.

const DIR: String = "user://story_drafts/"
const INDEX: String = "drafts.json"
## The folder under [member dir] that holds the unfinished text, one file per path, mirroring it.
const UNFINISHED: String = "unfinished/"
## The Story Lab's settings: Save to checkout, and whether its warning was shown.
const SETTINGS: String = "user://story_lab.cfg"
## The start commit of a draft made where neither git nor the build can tell.
const UNKNOWN: String = "unknown"
## The code of [member git] when git doesn't run: no checkout (an export, a device) or no git.
const NO_GIT: int = -1

## Where the drafts are kept: one file per path, mirroring it, and [constant INDEX].
var dir: String
## The folder that res:// paths name: "res://" in a run from the checkout.
var checkout: String = "res://"
## True: [method put] writes the checkout itself, and no drafts are kept.
var to_checkout: bool = false
## Runs git in the repo: (arguments: PackedStringArray) -> {"code": int, "out": String}; code
## [constant NO_GIT] when git doesn't run.
var git: Callable = _run_git
## The commit of this build, for where git doesn't run: () -> String, or [constant UNKNOWN].
var build_commit: Callable = _build_commit

var _texts: Dictionary[String, String] = {}
var _commits: Dictionary[String, String] = {}
var _unfinished: Dictionary[String, String] = {}
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


## Reads the drafts and the unfinished text from [member dir], and drops each draft that main now
## has. Returns one "path: what" per file that doesn't read; while drafts.json doesn't read, no
## draft is written.
func load_drafts() -> PackedStringArray:
	_texts.clear()
	_commits.clear()
	_broken = ""
	var errors := _load_unfinished()
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


## path to text of every draft; "" removes the file. Empty while [member to_checkout] is on: the
## drafts wait in [member dir] until it is off.
func texts() -> Dictionary[String, String]:
	var none: Dictionary[String, String] = {}
	return _texts.duplicate() if not to_checkout else none


## The paths with a draft, sorted.
func paths() -> PackedStringArray:
	var found := PackedStringArray(texts().keys())
	found.sort()
	return found


func has(path: String) -> bool:
	return texts().has(path)


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
	return _texts[path] if has(path) else checkout_text(path)


## Makes [param new_text] the text of [param path]; "" removes the file, and its unfinished text
## with it. A draft equal to the checkout's text disappears. Returns "" or what failed.
func put(path: String, new_text: String) -> String:
	if new_text == "" and _unfinished.has(path):
		var dropped := put_unfinished(path, "")
		if dropped != "":
			return dropped
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


## Renames the files in [param moves] (old path to new path) all at once, through drafts; their
## unfinished text moves with them. A new path may be another move's old path. Returns "" or what
## failed.
func rename(moves: Dictionary[String, String]) -> String:
	var moved: Dictionary[String, String] = {}
	var carried: Dictionary[String, String] = {}
	for old: String in moves:
		moved[moves[old]] = text(old)
		carried[moves[old]] = unfinished(old)
	var failures := PackedStringArray()
	for old: String in moves:
		if not moved.has(old):
			failures.append(put(old, ""))
	for path: String in moved:
		failures.append(put(path, moved[path]))
		failures.append(put_unfinished(path, carried[path]))
	return "\n".join(PackedStringArray(Array(failures).filter(func(f: String) -> bool: return f != "")))


## Drops the draft of [param path] and its unfinished text: main's text plays again. Returns "" or
## what failed.
func discard(path: String) -> String:
	var dropped := put_unfinished(path, "")
	if dropped != "":
		return dropped
	if _broken != "":
		return _broken
	return "\n".join(_drop(path) + _save_index())


## The unfinished text of [param path]: the whole file as the writer has it, which doesn't parse; ""
## when it has none.
func unfinished(path: String) -> String:
	return _unfinished.get(path, "")


func has_unfinished(path: String) -> bool:
	return _unfinished.has(path)


## The paths with unfinished text, sorted.
func unfinished_paths() -> PackedStringArray:
	var found := PackedStringArray(_unfinished.keys())
	found.sort()
	return found


## Keeps [param new_text] as the unfinished text of [param path], written and read back at once; ""
## drops it. Its draft and the checkout don't change. Returns "" or what failed.
func put_unfinished(path: String, new_text: String) -> String:
	if new_text == _unfinished.get(path, ""):
		return ""
	var file := _unfinished_file(path)
	if new_text == "":
		_unfinished.erase(path)
		if not FileAccess.file_exists(file):
			return ""
		var removed := DirAccess.remove_absolute(file)
		return "" if removed == OK else "can't remove the unfinished text %s: %s" % [file, error_string(removed)]
	var err := DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	if err != OK:
		return "can't make %s: %s" % [file.get_base_dir(), error_string(err)]
	var failed := _write(file, new_text)
	if failed != "":
		return failed
	_unfinished[path] = new_text
	return ""


## The text of [param path] at the draft's start commit: {"text"} ("" when the file wasn't there),
## or {} when git can't tell. Where git doesn't run, a draft that started on this build starts
## from the build's own file, and any other is {}.
func start_text(path: String) -> Dictionary:
	var commit := start_commit(path)
	if commit == UNKNOWN:
		return {}
	var found: Dictionary = git.call(PackedStringArray(["cat-file", "-e", commit + "^{commit}"]))
	if found["code"] == NO_GIT:
		return {"text": checkout_text(path)} if commit == build_commit.call() else {}
	if found["code"] != 0:
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


## The commit of the checkout; where git doesn't run, the build's; or [constant UNKNOWN].
func head_commit() -> String:
	var head: Dictionary = git.call(PackedStringArray(["rev-parse", "HEAD"]))
	if head["code"] == NO_GIT:
		return build_commit.call()
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
		var removed := DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
		return "" if removed == OK else "can't remove %s: %s" % [file, error_string(removed)]
	var err := DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	if err != OK:
		return "can't make %s: %s" % [file.get_base_dir(), error_string(err)]
	return _write(file, new_text)


func _draft_file(path: String) -> String:
	return dir.path_join(path.trim_prefix("res://"))


func _unfinished_file(path: String) -> String:
	return dir.path_join(UNFINISHED).path_join(path.trim_prefix("res://"))


# Reads every file under UNFINISHED into _unfinished; returns one "path: what" per file that doesn't read.
func _load_unfinished(sub: String = "") -> PackedStringArray:
	if sub == "":
		_unfinished.clear()
	var errors := PackedStringArray()
	var folder := dir.path_join(UNFINISHED).path_join(sub)
	if not DirAccess.dir_exists_absolute(folder):
		return errors
	for child: String in DirAccess.get_directories_at(folder):
		errors.append_array(_load_unfinished(sub.path_join(child)))
	for file: String in DirAccess.get_files_at(folder):
		var path := "res://" + sub.path_join(file)
		var read := _read(folder.path_join(file))
		if read.has("error"):
			errors.append("%s: the unfinished text doesn't read: %s" % [path, read["error"]])
		else:
			_unfinished[path] = read["text"]
	return errors


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
	if not GitHubIssues.in_checkout():
		return {"code": NO_GIT, "out": "no git checkout at %s" % GitHubIssues.repo_dir()}
	var output: Array = []
	var args := PackedStringArray(["-C", GitHubIssues.repo_dir()])
	args.append_array(arguments)
	var code := OS.execute("git", args, output)
	return {"code": code, "out": String(output[0]) if not output.is_empty() else ""}


# The short hash from BuildInfo, or UNKNOWN.
static func _build_commit() -> String:
	var commit := BuildInfo.commit()
	return commit.get_slice(" ", 0) if commit != BuildInfo.UNKNOWN_COMMIT else UNKNOWN


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
