class_name WorkviewPanel
extends PanelContainer
## The Workview panel for the computer in focus: what to do next, and closing the case. The
## parts are clicked in 3D (wiki: Hardware Repair); the power is the red button on the case.

@onready var _state: Label = %StateLabel
@onready var _fix: Button = %FixButton


func _ready() -> void:
	_fix.pressed.connect(func() -> void: Game.open_case(Game.focus, false))
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var job := Game.focus
	if job == null:
		_state.text = "No computer in focus."
	elif job.case_open:
		_state.text = "Unscrew a part to take it out; screw it in when it is back. In your hand: %s." % _held()
	elif job.hardware_fixed:
		_state.text = "Hardware: done."
	elif job.powered:
		_state.text = "Switch it off with the red button."
	elif _inside_done(job):
		_state.text = "Screw the side panel back on."
	elif job.panel_screws.has(true):
		_state.text = "Unscrew the side panel."
	else:
		_state.text = "Click the side panel to lift it off."
	_fix.disabled = job == null or not job.case_open


func _held() -> String:
	if Game.hand == null:
		return "nothing"
	return Game.hand.part.display_name + (" (broken)" if Game.hand.broken else "")


# Every part is in, none is broken, and their screws are in: only the side panel is left to do.
func _inside_done(job: Job) -> bool:
	if job.places.size() != Part.every().size():
		return false
	for part: Part in job.places:
		if job.places[part].broken or job.screws[part].has(false):
			return false
	return true
