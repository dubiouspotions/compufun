extends PropertyPage
## System > Performance: the real layout, disabled; only the memory reads the setup.


func load_from(computer: ComputerState) -> void:
	%PerformanceMemory.text = "%.1f MB of RAM" % computer.setup.memory_mb
