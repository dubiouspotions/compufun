class_name BackgroundTask
extends Node
## A Win95 program without a window, such as a virus. A program file whose scene root is one runs
## as a task of the computer (ComputerState.run_task): Close Program lists it by [member task_name],
## and its [member file] is in use, so Win95 refuses to delete, rename or move it. It runs until
## End Task, until Windows shuts down or restarts, or until it stops itself.

## The task ended: [method stop] ran. The task leaves the computer's tasks now and is freed at the
## end of the frame.
signal stopped

## The name that Close Program lists, such as "Bizopp".
@export var task_name: String = ""

## The program file that the task runs from, on the desktop or drive C. ComputerState.run_task sets
## it before [method start].
var file: Win95File
## The computer that the task runs on; null until [method start].
var computer: ComputerState


## True when [param program]'s scene root is a BackgroundTask, so it runs without a window. Reads
## the scene without making it.
static func runs_in_background(program: PackedScene) -> bool:
	return Win95File.root_extends(program, BackgroundTask)


## Starts the task on [param state], once it is in the tree. A subclass that overrides it calls
## super first.
func start(state: ComputerState) -> void:
	computer = state


## True from [method start] until [method stop].
func is_running() -> bool:
	return computer != null and not is_queued_for_deletion()


## Ends the task and frees it, with [signal stopped]. Does nothing when it already ended.
func stop() -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	stopped.emit()
