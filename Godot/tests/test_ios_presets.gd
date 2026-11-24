extends "res://tests/test.gd"
## The "iOS Release" export preset (the App Store) is the "iOS" preset (the team's TestFlight)
## without the team's tools: the same options and files, less those below (docs/ios.md).

## Files that only the team's builds carry: the Story Lab reads the bible.
const TEAM_ONLY_INCLUDES: PackedStringArray = ["story/bible/*.md"]
## Folders that only the team's builds carry.
const RELEASE_EXCLUDES: PackedStringArray = ["dev/*", "tests/*"]


func run() -> void:
	var presets := ConfigFile.new()
	check("export_presets.cfg loads", error_string(presets.load("res://export_presets.cfg")), error_string(OK))
	var team := _section(presets, "iOS")
	var store := _section(presets, "iOS Release")
	check("both iOS presets exist", [team != "", store != ""], [true, true])
	if team == "" or store == "":
		return
	check("the same options", _values(presets, store + ".options"), _values(presets, team + ".options"))
	var team_includes := PackedStringArray()
	for f in _filters(presets, team, "include_filter"):
		if not TEAM_ONLY_INCLUDES.has(f):
			team_includes.append(f)
	check("the same files, less the bible", _filters(presets, store, "include_filter"), team_includes)
	check("the same exclusions, plus dev/ and tests/", _filters(presets, store, "exclude_filter"), _sorted(_filters(presets, team, "exclude_filter") + RELEASE_EXCLUDES))


## The section ("preset.N") of the preset named [param preset_name], or "".
func _section(presets: ConfigFile, preset_name: String) -> String:
	for section in presets.get_sections():
		if not section.ends_with(".options") and presets.get_value(section, "name", "") == preset_name:
			return section
	return ""


func _values(presets: ConfigFile, section: String) -> Dictionary:
	var values := {}
	for key in presets.get_section_keys(section):
		values[key] = presets.get_value(section, key)
	return values


## The sorted, comma-separated filters of [param key] in [param section].
func _filters(presets: ConfigFile, section: String, key: String) -> PackedStringArray:
	var filters := PackedStringArray()
	for f in String(presets.get_value(section, key, "")).split(",", false):
		filters.append(f.strip_edges())
	return _sorted(filters)


func _sorted(filters: PackedStringArray) -> PackedStringArray:
	filters.sort()
	return filters
