class_name BuildInfo
## Which version and commit this build is: git in an editor run, INFO_FILE (written by CI) in an
## export.

## Written by tools/write-build-info.sh before an export: line 1 the version, line 2 the commit.
## Listed in each preset's include_filter.
const INFO_FILE: String = "res://build_info.txt"
## The same commands as tools/write-build-info.sh.
const GIT_DESCRIBE: PackedStringArray = ["describe", "--tags", "--match", "v[0-9]*.[0-9]*.[0-9]*"]
const GIT_COMMIT: PackedStringArray = ["log", "-1", "--format=%h %cd", "--date=format:%Y-%m-%d %H:%M"]


## The release version, like "0.8.1", or for a build between releases the last release and the
## commits since, like "0.8.1-5-gcd55d5b". "unversioned" when no release tag is reachable, and
## "unknown version" (with a warning saying why) when neither git nor INFO_FILE can tell.
static func version() -> String:
	if OS.has_feature("editor"):
		var described := _git(GIT_DESCRIBE, false)
		return described.trim_prefix("v") if described != "" else "unversioned"
	return _info_line(0, "unknown version")


## The short hash and commit time, like "cd55d5b 2026-11-21 16:40", or "unknown commit" (with a
## warning saying why).
static func commit() -> String:
	if OS.has_feature("editor"):
		var text := _git(GIT_COMMIT, true)
		return text if text != "" else "unknown commit"
	return _info_line(1, "unknown commit")


## The window title: the game's name, [method version] and [method commit].
static func title() -> String:
	return "%s %s (%s)" % [ProjectSettings.get_setting("application/config/name"), version(), commit()]


## git's output, or "" when it fails. [param warn] reports the failure; describe fails normally when
## no release tag is reachable.
static func _git(command: PackedStringArray, warn: bool) -> String:
	var output: Array = []
	var args := PackedStringArray(["-C", ProjectSettings.globalize_path("res://")])
	args.append_array(command)
	var code := OS.execute("git", args, output, true)
	var text := String(output[0]).strip_edges() if not output.is_empty() else ""
	if code == 0 and text != "":
		return text
	if warn:
		push_warning("BuildInfo: git %s failed (%d): %s" % [" ".join(args), code, text])
	return ""


static func _info_line(index: int, fallback: String) -> String:
	var file := FileAccess.open(INFO_FILE, FileAccess.READ)
	if file == null:
		push_warning("BuildInfo: cannot read %s: %s" % [INFO_FILE, error_string(FileAccess.get_open_error())])
		return fallback
	var lines := file.get_as_text().split("\n", false)
	if index >= lines.size():
		push_warning("BuildInfo: %s has no line %d" % [INFO_FILE, index + 1])
		return fallback
	return lines[index].strip_edges()
