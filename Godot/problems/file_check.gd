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


func is_fixed(setup: Win95Setup) -> bool:
	var file := setup.file_at(path)
	if file == null:
		return false
	return healthy_line == "" or Array(file.contents.split("\n")).any(_is_healthy)


func _is_healthy(line: String) -> bool:
	return line.strip_edges().nocasecmp_to(healthy_line.strip_edges()) == 0
