extends PropertyPage
## System > General: the Windows version, who it is registered to, and the processor and memory,
## from the running copy's setup.


func load_from(computer: ComputerState) -> void:
	var setup := computer.setup
	%Version.text = setup.version
	%Owner.text = setup.registered_owner
	%Organization.text = setup.registered_organization
	%ProductId.text = setup.product_id
	%Processor.text = setup.processor
	%Memory.text = "%.1fMB RAM" % setup.memory_mb
