extends VBoxContainer
## The Presets tab of the debug menu: one button per preset, a Game state that is set at once.
## A preset is in the format of Game.snapshot(); "Copy state" copies the current one, so a new
## preset is a paste. Missing keys start the day fresh (see Game.restore()). A job names its errand by
## file name, or a customer and a problem when the story has no such errand.

const PRESETS: Dictionary[String, Dictionary] = {
	"Day 1 starts": {"day": 1, "phase": "CLOSED"},
	"Skater bro at the counter": {"day": 1, "arrivals": 2, "visitor": "res://customers/skater_bro.tres",
			"visit": "DROP_OFF", "visitor_state": "TALKING"},
	"Skater bro's computer, not fixed": {"day": 1, "arrivals": 2, "focus_slot": 0,
			"jobs": [{"errand": "0102_skater_bro", "slot": 0}]},
	"Skater bro's computer, ready to call": {"day": 1, "arrivals": 2, "focus_slot": 0,
			"jobs": [{"errand": "0102_skater_bro", "slot": 0, "hardware_fixed": true}]},
	"Retired accountant at the counter, Skater bro's computer waiting": {"day": 1, "arrivals": 3, "focus_slot": 0,
			"visitor": "res://customers/retired_accountant.tres", "visit": "DROP_OFF", "visitor_state": "TALKING",
			"jobs": [{"errand": "0102_skater_bro", "slot": 0}]},
	"Retired accountant's computer connected, no sound": {"day": 1, "arrivals": 3, "focus_slot": 1, "connected_slot": 1,
			"jobs": [{"errand": "0102_skater_bro", "slot": 0},
				{"errand": "0103_retired_accountant", "slot": 1, "order": 1, "powered": true}]},
	"Activist guy's computer, bad RAM, connected": {"day": 1, "arrivals": 4, "focus_slot": 0, "connected_slot": 0,
			"jobs": [{"errand": "0104_activist_guy", "slot": 0}]},
	"Young entrepreneur's computer, desktop prank, connected": {"day": 1, "arrivals": 2, "focus_slot": 0, "connected_slot": 0,
			"jobs": [{"customer": "res://customers/young_entrepreneur.tres", "problem": "desktop_prank", "slot": 0, "powered": true}]},
	"Hat guy's computer, every .EXE gone, connected": {"day": 3, "arrivals": 1, "focus_slot": 0, "connected_slot": 0,
			"jobs": [{"customer": "res://customers/hat_guy.tres", "problem": "noimages", "slot": 0, "powered": true}]},
	"Nice guy's computer, broken hard drive, connected": {"day": 5, "arrivals": 0, "focus_slot": 0, "connected_slot": 0,
			"jobs": [{"customer": "res://customers/nice_guy.tres", "problem": "broken_hard_drive", "slot": 0, "powered": true}]},
	"Attractive guy's computer, no screensaver, connected": {"day": 4, "arrivals": 1, "focus_slot": 0, "connected_slot": 0,
			"jobs": [{"customer": "res://customers/attractive_guy.tres", "problem": "screensaver", "slot": 0, "powered": true}]},
	"Nice lady's computer, hamster on the fan, in focus": {"day": 2, "arrivals": 1, "focus_slot": 0, "view": "Workview",
			"jobs": [{"errand": "0201_nice_lady", "slot": 0}]},
	"Day 1 over, two computers overnight": {"day": 1, "phase": "DAY_OVER", "arrivals": 4,
			"jobs": [{"errand": "0102_skater_bro", "slot": 0},
				{"errand": "0103_retired_accountant", "slot": 1, "order": 1}]},
	"Day 7, ready to close for the end": {"day": 7},
	"The end": {"day": 7, "phase": "ENDED"},
}

var _status: Label


func _ready() -> void:
	for preset_name: String in PRESETS:
		var button := Button.new()
		button.text = preset_name
		button.pressed.connect(_apply.bind(preset_name))
		add_child(button)
	var copy := Button.new()
	copy.text = "Copy state"
	copy.pressed.connect(_copy)
	add_child(copy)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)


func _apply(preset_name: String) -> void:
	var refused := Game.restore(PRESETS[preset_name])
	_status.text = "%s: %s" % [preset_name, refused] if refused != "" else "Set: " + preset_name


func _copy() -> void:
	var state := JSON.stringify(Game.snapshot(), "\t")
	print(state)
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		push_error("Debug presets: no clipboard here; the state is in the output log")
		_status.text = "No clipboard here. The state is in the output log."
		return
	DisplayServer.clipboard_set(state)
	_status.text = "Copied the state. Paste it into PRESETS in ui/debug_presets.gd."
