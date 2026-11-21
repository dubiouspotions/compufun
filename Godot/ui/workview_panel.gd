class_name WorkviewPanel
extends PanelContainer
## The Workview placeholder: until the hardware parts exist, the hardware fix is one button.

@onready var _state: Label = %StateLabel
@onready var _fix: Button = %FixButton


func _ready() -> void:
	_fix.pressed.connect(func() -> void: Game.fix(Problem.Location.HARDWARE))
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
