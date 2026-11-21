extends Control
## A placeholder for the Win95 interface, which another developer builds. It shows the problem of
## the customer and sends problem_fixed when the player presses Fix.

## The player fixed the software problem.
signal problem_fixed(problem: Problem)

@onready var _info: Label = %InfoLabel
@onready var _fix: Button = %FixButton


func _ready() -> void:
	_fix.pressed.connect(func() -> void: problem_fixed.emit(Game.connected.problem))
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var job := Game.connected
	if job == null:
		_info.text = "No computer is connected."
	elif job.software_fixed:
		_info.text = "Software: done."
	else:
		_info.text = "The customer's computer: %s" % job.problem.perceived_issue
	_fix.disabled = job == null or job.software_fixed
