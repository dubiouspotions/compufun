extends BackgroundTask
## BIZOPP.EXE, the virus of the email_virus problem (VirusCheck): while it runs on a computer that
## is on, it opens or closes the CD-ROM drive's tray (Game.toggle_cd_tray) every few seconds. It
## stops itself once its file is off the desktop and drive C.

## The shortest and the longest wait between two pushes of the tray, in seconds; each wait is
## random between them.
@export_range(0.1, 60.0) var min_seconds: float = 3.0
@export_range(0.1, 60.0) var max_seconds: float = 9.0

## Picks the waits; a test seeds it.
var rng := RandomNumberGenerator.new()

var _timer: Timer


func start(state: ComputerState) -> void:
	super(state)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_push_tray)
	add_child(_timer)  # a Timer, so a hung Windows stops it too
	state.changed.connect(_stop_when_gone)
	_wait()


func _wait() -> void:
	_timer.start(rng.randf_range(min_seconds, max_seconds))


func _push_tray() -> void:
	var job := computer.job
	if job != null and job.powered and job in Game.jobs:
		Game.toggle_cd_tray(job)
	_wait()


func _stop_when_gone() -> void:
	if is_running() and not computer.has_file(file):
		stop()
