extends PropertyPage
## System > General: the Windows version, who it is registered to, and the processor and memory,
## from the running copy's setup. An empty registered_owner shows the customer's name.


func load_from(computer: ComputerState) -> void:
	var setup := computer.setup
	%Version.text = setup.version
	%Owner.text = setup.registered_owner if setup.registered_owner != "" or computer.job == null else computer.job.customer.display_name
	%Organization.text = setup.registered_organization
	%ProductId.text = setup.product_id
	%Processor.text = setup.processor
	%Memory.text = "%.1fMB RAM" % setup.memory_mb
