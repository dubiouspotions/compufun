class_name PostIt3D
extends Node3D
## The post-it stuck on a computer on the counter: the job's perceived issue and, once the player
## has ticked Done, a green check and the prompt to call the customer.

## The job whose post-it this is, or null for a blank post-it.
var job: Job:
	set(value):
		job = value
		if is_node_ready():
			_sync()

@onready var _issue: Label3D = %Issue
@onready var _done: Node3D = %Done


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	_issue.text = job.problem.perceived_issue if job != null else ""
	_done.visible = job != null and job.post_it_ticked
