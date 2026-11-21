class_name WorkviewPanel
extends PanelContainer
## The Workview placeholder for the computer in focus: until the hardware parts exist, the
## hardware fix is one button, and the power is one toggle.

@onready var _state: Label = %StateLabel
@onready var _fix: Button = %FixButton
@onready var _power: Button = %PowerButton


func _ready() -> void:
	_fix.pressed.connect(func() -> void: Game.fix(Problem.Location.HARDWARE))
	_power.toggled.connect(func(on: bool) -> void: Game.set_powered(Game.focus, on))
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
	_power.set_pressed_no_signal(job != null and job.powered)
	_power.disabled = job == null
	_power.text = "Power: on" if job != null and job.powered else "Power: off"
