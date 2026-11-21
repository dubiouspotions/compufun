class_name PostIt
extends PanelContainer
## The repair ticket on the computer: the perceived issue and the Done box.

## The player ticked the Done box.
signal ticked

@onready var _issue: Label = %IssueLabel
@onready var _done: CheckBox = %DoneBox
@onready var _hint: Label = %HintLabel


func _ready() -> void:
	_done.toggled.connect(_on_done_toggled)
	Game.changed.connect(_sync)
	_sync()


func _on_done_toggled(on: bool) -> void:
	if on:
		ticked.emit()


func _sync() -> void:
	var problem := Game.problem
	_issue.text = problem.perceived_issue if problem != null else ""
	_done.set_pressed_no_signal(Game.post_it_ticked)
	_done.disabled = not Game.problem_fixed or Game.post_it_ticked
	if Game.post_it_ticked:
		_hint.text = "Done. Call the customer."
	elif Game.problem_fixed:
		_hint.text = "Fixed. Tick Done."
	else:
		_hint.text = "Not fixed yet."
