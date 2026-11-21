extends VBoxContainer
## The Presets tab of the debug menu: one button per preset, a Game state that is set at once.
## A preset is in the format of Game.snapshot(); "Copy state" copies the current one, so a new
## preset is a paste. Missing keys start the day fresh (see Game.restore()).

const PRESETS: Dictionary[String, Dictionary] = {
	"Day 1 starts": {"day": 1},
	"Pierre at the counter": {"day": 1, "arrivals": 1, "visitor": "res://customers/pierre.tres",
			"visit": "DROP_OFF", "visitor_state": "TALKING"},
	"Pierre's computer, not fixed": {"day": 1, "arrivals": 1, "focus_slot": 0,
			"jobs": [{"customer": "res://customers/pierre.tres", "slot": 0}]},
	"Pierre's computer, ready to call": {"day": 1, "arrivals": 1, "focus_slot": 0,
			"jobs": [{"customer": "res://customers/pierre.tres", "slot": 0, "hardware_fixed": true}]},
	"Javve at the counter, Pierre's computer waiting": {"day": 1, "arrivals": 2, "focus_slot": 0,
			"visitor": "res://customers/javve.tres", "visit": "DROP_OFF", "visitor_state": "TALKING",
			"jobs": [{"customer": "res://customers/pierre.tres", "slot": 0}]},
	"Javve's computer connected, not fixed": {"day": 1, "arrivals": 2, "focus_slot": 1, "connected_slot": 1,
			"jobs": [{"customer": "res://customers/pierre.tres", "slot": 0},
				{"customer": "res://customers/javve.tres", "slot": 1, "order": 1, "powered": true}]},
	"Day 1 over, both computers overnight": {"day": 1, "phase": "DAY_OVER", "arrivals": 2,
			"jobs": [{"customer": "res://customers/pierre.tres", "slot": 0},
				{"customer": "res://customers/javve.tres", "slot": 1, "order": 1}]},
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
