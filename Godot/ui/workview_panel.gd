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
		_state.text = "In your hand: %s. Click a part to take it, a place to put it." % _held()
	elif job.hardware_fixed:
		_state.text = "Hardware: done."
	elif job.powered:
		_state.text = "Switch it off to open it."
	else:
		_state.text = "Click the computer to open it."
	_fix.disabled = job == null or not job.case_open


func _held() -> String:
	if Game.hand == null:
		return "nothing"
	return Game.hand.part.display_name + (" (broken)" if Game.hand.broken else "")
