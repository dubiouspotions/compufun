class_name JobSlots
extends Node3D
## The work mat on the counter with a place for each slot (Slot0 to Slot3, Marker3D nodes that a
## designer moves). It shows one JobComputer per job, at its job's slot.

## The player clicked the computer of [param job].
signal job_clicked(job: Job)
## The player clicked the power button on the computer of [param job].
signal power_clicked(job: Job)
## The player clicked the screwdriver beside the computer of [param job], or its outline.
signal screwdriver_clicked(job: Job)

## The scene of one job's computer.
@export var computer_scene: PackedScene
## Plays at a slot when a customer's computer is put down on it, and when it is picked up again.
@export var set_down_sound: SoundSet = preload("res://sounds/computer_set_down.tres")
@export var pick_up_sound: SoundSet = preload("res://sounds/computer_pick_up.tres")

var _computers: Dictionary[Job, JobComputer] = {}

@onready var _slots: Node3D = %Slots


## Converges on [param jobs]: a computer appears for each new job and leaves with each job that
## left. Each power light shows its job's power.
func show_jobs(jobs: Array[Job]) -> void:
	for job: Job in _computers.keys():
		if job not in jobs:
			pick_up_sound.play_at(_computers[job].get_parent())
			_computers[job].disable()
			_computers[job].queue_free()
			_computers.erase(job)
	for job: Job in jobs:
		if not _computers.has(job):
			var computer := _add_computer(job)
			if computer == null:
				continue
			set_down_sound.play_at(computer.get_parent())
			_computers[job] = computer
		_computers[job].powered = job.powered


## Where the Workview camera looks at the computer of [param job] from, in world space. Fails with
## an error and returns [param fallback] when the job has no computer on the counter.
func workview_transform(job: Job, fallback: Transform3D) -> Transform3D:
	var computer: JobComputer = _computers.get(job)
	if computer == null:
		push_error("JobSlots.workview_transform: the job in slot %d has no computer on the counter" % job.slot)
		return fallback
	return computer.workview_transform()


## The VGA socket of the computer of [param job] (see [method JobComputer.cable_socket]). Fails with
## an error and returns null when the job has no computer on the counter.
func cable_socket(job: Job) -> Node3D:
	var computer: JobComputer = _computers.get(job)
	if computer == null:
		push_error("JobSlots.cable_socket: the job in slot %d has no computer on the counter" % job.slot)
		return null
	return computer.cable_socket()


## The post-it that the player reads on the computer of [param job] in the Workview (see
## [method JobComputer.pinned_post_it]), or null when the job has no computer on the counter or the
## post-it isn't showing.
func pinned_post_it(job: Job) -> PostIt3D:
	var computer: JobComputer = _computers.get(job)
	return computer.pinned_post_it() if computer != null else null


## The job whose computer the mouse ray from [param from] along [param dir] (world space) meets
## first, or null when it meets none.
func job_at(from: Vector3, dir: Vector3) -> Job:
	var nearest: Job = null
	var nearest_distance := INF
	for job: Job in _computers:
		var distance := _computers[job].ray_distance(from, dir)
		if distance >= 0.0 and distance < nearest_distance:
			nearest = job
			nearest_distance = distance
	return nearest


## Outlines the computer of [param job] as the one that the dragged plug is over; null outlines none.
func target(job: Job) -> void:
	for computer: JobComputer in _computers.values():
		computer.targeted = computer.job == job


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
	computer.power_clicked.connect(func(c: JobComputer) -> void: power_clicked.emit(c.job))
	computer.screwdriver_clicked.connect(func(c: JobComputer) -> void: screwdriver_clicked.emit(c.job))
	slot.add_child(computer)
	return computer
