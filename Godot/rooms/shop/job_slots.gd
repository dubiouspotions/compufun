class_name JobSlots
extends Node3D
## The work mat on the counter with a place for each slot (Slot0 to Slot3, Marker3D nodes that a
## designer moves). It shows one JobComputer per job, at its job's slot.

## The player clicked the computer of [param job].
signal job_clicked(job: Job)

## The scene of one job's computer.
@export var computer_scene: PackedScene

var _computers: Dictionary[Job, JobComputer] = {}

@onready var _slots: Node3D = %Slots


## Converges on [param jobs]: a computer appears for each new job and leaves with each job that
## left. The computer of [param outlined] (null for none) shows the focus outline.
func show_jobs(jobs: Array[Job], outlined: Job) -> void:
	for job: Job in _computers.keys():
		if job not in jobs:
			_computers[job].disable()
			_computers[job].queue_free()
			_computers.erase(job)
	for job: Job in jobs:
		if not _computers.has(job):
			var computer := _add_computer(job)
			if computer == null:
				continue
			_computers[job] = computer
		_computers[job].focused = job == outlined


func _add_computer(job: Job) -> JobComputer:
	var slot := _slots.get_node_or_null("Slot%d" % job.slot) as Marker3D
	if slot == null:
		push_error("JobSlots: no Marker3D named Slot%d under %s for the job of %s" % [job.slot, _slots.get_path(), job.customer.resource_path])
		return null
	if computer_scene == null:
		push_error("JobSlots: computer_scene is not set on %s" % get_path())
		return null
	var computer := computer_scene.instantiate() as JobComputer
	computer.job = job
	computer.clicked.connect(func(c: JobComputer) -> void: job_clicked.emit(c.job))
	slot.add_child(computer)
	return computer
