extends "res://tests/test.gd"
## Every preset of the debug menu restores in the week from the story files, and a snapshot of it
## restores to the same state.


func run() -> void:
	var presets: Dictionary = (load("res://ui/debug_presets.gd") as GDScript).get_script_constant_map()["PRESETS"]
	for preset_name: String in presets:
		check("the preset '%s' restores" % preset_name, game.restore(presets[preset_name]), "")
		var state: Dictionary = game.snapshot()
		check("its snapshot restores the same", [game.restore(state), game.snapshot() == state], ["", true])
