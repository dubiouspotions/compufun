class_name JobSlots
extends Node3D
## The work mat on the counter with a place for each slot (Slot0 to Slot3, Marker3D nodes that a
## designer moves). It shows one JobComputer per job, at its job's slot.

## The player clicked the computer of [param job].
signal job_clicked(job: Job)
## The player clicked the power button on the computer of [param job].
signal power_clicked(job: Job)
## The player clicked the floppy drive of [param job]'s computer while a floppy is in it.
signal floppy_clicked(job: Job)
## The player clicked the screwdriver beside the computer of [param job], or its outline.
signal screwdriver_clicked(job: Job)
## The computer of [param job] moved toward its job's slot: on every frame of its slide, and once
## more where it stops. Everything on it (the mat, the post-it, the cable's socket, the Workview's
## eye) moved with it.
signal computer_moved(job: Job)

## The scene of one job's computer.
@export var computer_scene: PackedScene
## Plays at a slot when a customer's computer is put down on it, and when it is picked up again.
@export var set_down_sound: SoundSet = preload("res://sounds/computer_set_down.tres")
@export var pick_up_sound: SoundSet = preload("res://sounds/computer_pick_up.tres")
## How long a computer takes to slide to its new slot when one left of it leaves the counter, in
## seconds.
@export var slide_seconds: float = 0.6

var _computers: Dictionary[Job, JobComputer] = {}
var _slides: Dictionary[Job, Tween] = {}

@onready var _slots: Node3D = %Slots


## Converges on [param jobs]: a computer appears for each new job and leaves with each job that
## left, with the sound of it put down or picked up unless [param silent]. A computer whose job
## changed slot slides there, or stands there at once when [param silent]. Each power light shows
## its job's power.
func show_jobs(jobs: Array[Job], silent: bool = false) -> void:
	for job: Job in _computers.keys():
		if job not in jobs:
			if not silent:
				pick_up_sound.play_at(_computers[job].get_parent())
			_stop_slide(job)
			_computers[job].disable()
			_computers[job].queue_free()
			_computers.erase(job)
	for job: Job in jobs:
		if not _computers.has(job):
			var computer := _add_computer(job)
			if computer == null:
				continue
			if not silent:
				set_down_sound.play_at(computer.get_parent())
			_computers[job] = computer
		else:
			_move_to_slot(job, silent)
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
	var slot := _slot_of(job)
	if slot == null:
		return null
	if computer_scene == null:
		push_error("JobSlots: computer_scene is not set on %s" % get_path())
		return null
	var computer := computer_scene.instantiate() as JobComputer
	computer.job = job
	computer.clicked.connect(func(c: JobComputer) -> void: job_clicked.emit(c.job))
	computer.power_clicked.connect(func(c: JobComputer) -> void: power_clicked.emit(c.job))
	computer.floppy_clicked.connect(func(c: JobComputer) -> void: floppy_clicked.emit(c.job))
	computer.screwdriver_clicked.connect(func(c: JobComputer) -> void: screwdriver_clicked.emit(c.job))
	slot.add_child(computer)
	return computer


## The marker of counter slot [param index] (0 is leftmost), where a computer stands; null, with an
## error, when there is no such slot.
func slot_marker(index: int) -> Marker3D:
	var slot := get_node_or_null("Slots/Slot%d" % index) as Marker3D
	if slot == null:
		push_error("JobSlots: no Marker3D named Slots/Slot%d under %s" % [index, get_path()])
	return slot


func _slot_of(job: Job) -> Marker3D:
	return slot_marker(job.slot)


# Moves the computer of [param job] under its slot's marker, keeping it where it stands, and slides it
# onto the marker.
func _move_to_slot(job: Job, at_once: bool) -> void:
	var computer := _computers[job]
	var slot := _slot_of(job)
	if slot == null:
		return
	var moved := computer.get_parent() != slot
	if not moved and not (at_once and _slides.has(job)):
		return
	_stop_slide(job)
	if moved:
		computer.reparent(slot)
	if at_once or slide_seconds <= 0.0:
		computer.position = Vector3.ZERO
		computer_moved.emit(job)
		return
	var from := computer.position
	var slide := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_method(func(t: float) -> void:
		computer.position = from.lerp(Vector3.ZERO, t)
		computer_moved.emit(job), 0.0, 1.0, slide_seconds)
	slide.finished.connect(func() -> void: _slides.erase(job))
	_slides[job] = slide


func _stop_slide(job: Job) -> void:
	if _slides.has(job):
		_slides[job].kill()
		_slides.erase(job)
