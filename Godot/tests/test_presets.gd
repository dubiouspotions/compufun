extends "res://tests/test.gd"
## The debug menu's presets: one per problem file, and every preset restores without a refusal.

const PRESETS := "res://ui/debug_presets.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var presets: GDScript = load(PRESETS)
	var problems: Dictionary = presets.call("problem_presets")
	var files := Array(ResourceLoader.list_directory("res://problems/")).filter(func(file: String) -> bool: return file.get_extension() == "tres")
	check("one preset per problem file", problems.size(), files.size())
	var every: Dictionary = problems.duplicate()
	every.merge(presets.get("MOMENTS"))
	for preset_name: String in every:
		check("%s restores" % preset_name, game.restore(every[preset_name]), "")
		var state: Dictionary = game.snapshot()
		check("%s: its snapshot restores the same" % preset_name, [game.restore(state), game.snapshot() == state], ["", true])
