class_name PostIt
extends PanelContainer
## The repair ticket on a computer: the perceived issue and the Done box.

## The player ticked the Done box of [param ticked_job].
signal ticked(ticked_job: Job)

## The job whose post-it this is, or null for an empty post-it.
var job: Job:
	set(value):
		job = value
		if is_node_ready():
			_sync()

@onready var _issue: Label = %IssueLabel
@onready var _done: CheckBox = %DoneBox
@onready var _hint: Label = %HintLabel


func _ready() -> void:
	_done.toggled.connect(_on_done_toggled)
	Game.changed.connect(_sync)
	_sync()


func _on_done_toggled(on: bool) -> void:
	if on and job != null:
		ticked.emit(job)


func _sync() -> void:
	if job == null:
		_issue.text = ""
		_done.set_pressed_no_signal(false)
		_done.disabled = true
		_hint.text = ""
		return
	_issue.text = job.problem.perceived_issue
	_done.set_pressed_no_signal(job.post_it_ticked)
	_done.disabled = not job.fixed or job.post_it_ticked
	if job.post_it_ticked:
		_hint.text = "Done. Call the customer."
	elif job.fixed:
		_hint.text = "Fixed. Tick Done."
	else:
		_hint.text = "Not fixed yet."
