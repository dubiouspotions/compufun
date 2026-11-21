class_name ComputerState
extends Node
## The live Win95 state of the computer that the cable is connected to (Game.connected). When the
## cable moves to another job, it copies that computer's Win95Setup and applies the problem's
## break; the job's power switches it on and off. Each running desktop has its own ComputerState.

## The power came on. [member setup] is ready: rebuild everything from it.
signal booted
## The power went off, or the computer left the bench.
signal powered_off
## A setter changed [member setup]; re-read what you show.
signal changed

## The running copy; null when no computer with a Win95 setup is on the bench. A power cycle keeps
## it, so the player's changes survive a reboot.
var setup: Win95Setup
var is_on: bool = false

var _job: Job


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


## Starts a computer from [param from] and breaks it as [param problem] says. [param from], and
## the .tres that it came from, stay unchanged. No signal fires; power does that.
func boot(from: Win95Setup, problem: Problem) -> void:
	setup = from.duplicate_deep()  # loaded resources are shared, so mutating them would leak
	if problem != null and problem.software_check != null:
		problem.software_check.apply_break(setup)
	_report_fixed()


func set_sound(volume: float, muted: bool) -> void:
	if setup == null or (setup.volume == volume and setup.muted == muted):
		return
	setup.volume = volume
	setup.muted = muted
	_changed()


func rename_file(file: Win95File, new_name: String) -> void:
	if setup == null or file.name == new_name:
		return
	file.name = new_name
	_changed()


func _sync() -> void:
	var job: Job = Game.connected
	if job != _job:
		_job = job
		setup = null
		var computer := job.customer.computer if job != null else null
		if computer != null and computer.win95_setup != null:
			boot(computer.win95_setup, job.problem)
	var on := setup != null and job.powered
	if on == is_on:
		return
	is_on = on
	if on:
		booted.emit()
	else:
		powered_off.emit()


func _changed() -> void:
	changed.emit()
	_report_fixed()


func _report_fixed() -> void:
	if setup != null and _job != null and _job.problem.software_check != null:
		Game.set_software_fixed(_job, _job.problem.software_check.is_fixed(setup))
