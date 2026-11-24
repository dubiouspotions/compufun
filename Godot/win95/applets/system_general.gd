extends PropertyPage
## System > General: the Windows version, who it is registered to, and the processor and memory,
## from the running copy's setup. An empty registered_owner shows the customer's name.

## The version shown while the computer runs Cambion (Game.runs_cambion), in place of the setup's.
@export var cambion_version: String = "4.06.6612"


func load_from(computer: ComputerState) -> void:
	var setup := computer.setup
	%Version.text = cambion_version if computer.job != null and Game.runs_cambion(computer.job.customer) else setup.version
	%Owner.text = setup.registered_owner if setup.registered_owner != "" or computer.job == null else computer.job.customer.display_name
	%Organization.text = setup.registered_organization
	%ProductId.text = setup.product_id
	%Processor.text = setup.processor
	%Memory.text = "%.1fMB RAM" % setup.memory_mb
