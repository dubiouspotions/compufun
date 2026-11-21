class_name BuildInfo
## Which commit this build is: git in an editor run, COMMIT_FILE (written by CI) in an export.

## Written by CI and export.sh before an export; listed in each preset's include_filter.
const COMMIT_FILE: String = "res://build_commit.txt"
## The same format as tools/write-build-commit.sh.
const GIT_FORMAT: PackedStringArray = ["log", "-1", "--format=%h %cd", "--date=format:%Y-%m-%d %H:%M"]


## The short hash and commit time, like "cd55d5b 2026-11-21 16:40", or "unknown commit" (with a
## warning saying why).
static func commit() -> String:
	if OS.has_feature("editor"):
		var output: Array = []
		var args := PackedStringArray(["-C", ProjectSettings.globalize_path("res://")])
		args.append_array(GIT_FORMAT)
		var code := OS.execute("git", args, output, true)
		var text := String(output[0]).strip_edges() if not output.is_empty() else ""
		if code == 0 and text != "":
			return text
		push_warning("BuildInfo: git %s failed (%d): %s" % [" ".join(args), code, text])
		return "unknown commit"
	var file := FileAccess.open(COMMIT_FILE, FileAccess.READ)
	if file == null:
		push_warning("BuildInfo: cannot read %s: %s" % [COMMIT_FILE, error_string(FileAccess.get_open_error())])
		return "unknown commit"
	return file.get_line().strip_edges()


## The window title: the game's name and [method commit].
static func title() -> String:
	return "%s %s" % [ProjectSettings.get_setting("application/config/name"), commit()]
