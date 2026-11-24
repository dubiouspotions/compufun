extends "res://tests/test.gd"
## Every export preset packs the story files that the game loads: Godot packs a file that isn't a
## resource only when the preset's include_filter names it, and a missing one stops the game at load.

const PRESETS := "res://export_presets.cfg"
## Read only by the Story Lab, which the desktop and web exports leave out.
const STORY_LAB_ONLY := "story/bible/"


func run() -> void:
	var presets := ConfigFile.new()
	check("the export presets read", presets.load(PRESETS), OK)
	var files := _story_files("res://story")
	check("the story has files to check", files.is_empty(), false)
	for section: String in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var preset: String = presets.get_value(section, "name")
		var filters := Array((presets.get_value(section, "include_filter", "") as String).split(",", false))
		for file: String in files:
			check("%s packs %s" % [preset, file], filters.any(func(f: String) -> bool: return file.match(f.strip_edges())), true)


# The paths under [param dir], relative to res://, of the files that aren't scripts or resources.
func _story_files(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_story_files(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		var path := dir.path_join(file).trim_prefix("res://")
		if file.get_extension() in ["gd", "uid", "tres", "tscn", "import"] or path.begins_with(STORY_LAB_ONLY):
			continue
		found.append(path)
	return found
