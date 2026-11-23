class_name FileCheck
extends SoftwareCheck
## A problem in one file: the break renames it, or swaps a line of its text, and the fix puts that
## back. Noimages: PBRUSH.EXE renamed to PBRUSH.EX_. A dead mouse: "device=*vmouse" commented out of
## SYSTEM.INI.

## The healthy file, from drive C or the desktop: "C:\WINDOWS\PBRUSH.EXE", "Desktop\todo.txt".
## Win95 ignores case.
@export var path: String = ""
## The break renames the file to this, in the same folder. Empty keeps the name.
@export var broken_name: String = ""
## A line that the healthy file holds, for example "device=*vmouse". Empty: only the name counts.
## Spaces around a line and case don't matter.
@export var healthy_line: String = ""
## The break replaces [member healthy_line] with this line, for example ";device=*vmouse". Empty
## removes it.
@export var broken_line: String = ""


func apply_break(setup: Win95Setup) -> void:
	var file := setup.file_at(path)
	if file == null:
		if broken_name == "" or setup.file_at(path.substr(0, path.rfind("\\") + 1) + broken_name) == null:
			push_error("FileCheck: %s is not on the computer, so the break has nothing to break" % path)
		return  # already broken on an earlier visit
	if healthy_line != "":
		var lines := PackedStringArray()
		for line in file.contents.split("\n"):
			if not _is_healthy(line):
				lines.append(line)
			elif broken_line != "":
				lines.append(broken_line)
		file.contents = "\n".join(lines)
	if broken_name != "":
		file.name = broken_name


## Renames the file back and puts [member healthy_line] back (see [method fixed_contents]).
func apply_fix(setup: Win95Setup) -> void:
	var file := broken_file(setup)
	if file == null:
		push_error("FileCheck: %s is not on the computer, also not as %s, so the fix has nothing to fix" % [path, broken_name])
		return
	file.name = healthy_name()
	file.contents = fixed_contents(file.contents)


## The file that the break left: at [member path], or renamed to [member broken_name]; null when
## neither is on the computer.
func broken_file(setup: Win95Setup) -> Win95File:
	var file := setup.file_at(path)
	if file == null and broken_name != "":
		file = setup.file_at(path.substr(0, path.rfind("\\") + 1) + broken_name)
	return file


## The file's name when it is healthy: the last part of [member path].
func healthy_name() -> String:
	return path.substr(path.rfind("\\") + 1)


## [param contents] with [member healthy_line] back in place of [member broken_line], or at the end
## when no broken line is there; unchanged when the healthy line is in, or there is none.
func fixed_contents(contents: String) -> String:
	var lines := contents.split("\n")
	if healthy_line == "" or Array(lines).any(_is_healthy):
		return contents
	var replaced := false
	for i in lines.size():
		if broken_line != "" and lines[i].strip_edges().nocasecmp_to(broken_line.strip_edges()) == 0:
			lines[i] = healthy_line
			replaced = true
	if not replaced:
		lines.append(healthy_line)
	return "\n".join(lines)


func is_fixed(setup: Win95Setup) -> bool:
	var file := setup.file_at(path)
	if file == null:
		return false
	return healthy_line == "" or Array(file.contents.split("\n")).any(_is_healthy)


func _is_healthy(line: String) -> bool:
	return line.strip_edges().nocasecmp_to(healthy_line.strip_edges()) == 0
