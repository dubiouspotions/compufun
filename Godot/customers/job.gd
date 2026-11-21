class_name Job
extends RefCounted
## One computer on the counter: whose it is, where it stands and how far the repair is. Game
## creates, changes and removes jobs, and emits Game.changed after each change; other scripts read.

## The customer who brought the computer. Never null.
var customer: Customer
## The place on the counter, 0 to Game.MAX_JOBS - 1. No two jobs on the counter share a slot.
var slot: int = 0
## Counts up with each drop-off, across days: a lower order is an older job.
var order: int = 0
var hardware_fixed: bool = false
var software_fixed: bool = false
## The computer is switched on.
var powered: bool = false
## Game.setup_for has broken the computer's running copy as the problem says.
var broken: bool = false
## The player ticked Done on the post-it. Only true when [member fixed] is.
var post_it_ticked: bool = false

## The customer's problem.
var problem: Problem:
	get:
		return customer.problem

## True when every part that the problem needs (hardware, software or both) is fixed.
var fixed: bool:
	get:
		match problem.location:
			Problem.Location.HARDWARE:
				return hardware_fixed
			Problem.Location.SOFTWARE:
				return software_fixed
			_:
				return hardware_fixed and software_fixed


func _init(job_customer: Customer, job_slot: int, job_order: int) -> void:
	customer = job_customer
	slot = job_slot
	order = job_order


## The job as plain data, for the F9 report.
func snapshot() -> Dictionary:
	return {
		"slot": slot,
		"order": order,
		"customer": customer.resource_path,
		"problem": String(problem.short_name),
		"hardware_fixed": hardware_fixed,
		"software_fixed": software_fixed,
		"powered": powered,
		"post_it_ticked": post_it_ticked,
	}
