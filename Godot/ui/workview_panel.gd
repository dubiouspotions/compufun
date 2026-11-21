class_name WorkviewPanel
extends PanelContainer
## The Workview placeholder for the computer in focus: until the hardware parts exist, the
## hardware fix is one button.

@onready var _state: Label = %StateLabel
@onready var _fix: Button = %FixButton


func _ready() -> void:
	_fix.pressed.connect(func() -> void: Game.fix(Problem.Location.HARDWARE))
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var job := Game.focus
	if job == null:
		_state.text = "No computer in focus."
	elif job.hardware_fixed:
		_state.text = "Hardware: done."
	else:
		_state.text = "Open the case and swap the part."
	_fix.disabled = job == null or job.hardware_fixed
