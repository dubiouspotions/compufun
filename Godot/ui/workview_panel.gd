class_name WorkviewPanel
extends PanelContainer
## The Workview placeholder: until the hardware parts exist, the hardware fix is one button, and
## the power and screen cable of the computer on the bench are one toggle.

@onready var _state: Label = %StateLabel
@onready var _fix: Button = %FixButton
@onready var _power: Button = %PowerButton


func _ready() -> void:
	_fix.pressed.connect(func() -> void: Game.fix(Problem.Location.HARDWARE))
	_power.toggled.connect(Game.set_bench_powered)
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	if Game.phase != Game.Phase.REPAIR:
		_state.text = "No computer on the counter."
	elif Game.hardware_fixed:
		_state.text = "Hardware: done."
	else:
		_state.text = "Open the case and swap the part."
	_fix.disabled = Game.phase != Game.Phase.REPAIR or Game.hardware_fixed
	_power.set_pressed_no_signal(Game.bench_powered)
	_power.disabled = Game.phase != Game.Phase.REPAIR
	_power.text = "Power: on" if Game.bench_powered else "Power: off"
