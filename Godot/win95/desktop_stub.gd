extends Control
## A placeholder for the Win95 interface, which another developer builds. It shows the problem of
## the customer and sends problem_fixed when the player presses Fix.

## The player fixed the software problem.
signal problem_fixed(problem: Problem)

@onready var _info: Label = %InfoLabel
@onready var _fix: Button = %FixButton


func _ready() -> void:
	_fix.pressed.connect(func() -> void: problem_fixed.emit(Game.problem))
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	if Game.phase != Game.Phase.REPAIR:
		_info.text = "No computer is connected."
	elif Game.software_fixed:
		_info.text = "Software: done."
	else:
		_info.text = "The customer's computer: %s" % Game.problem.perceived_issue
	_fix.disabled = Game.phase != Game.Phase.REPAIR or Game.software_fixed
