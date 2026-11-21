class_name ComputerState
extends Node
## The live Win95 state of one customer's computer. Each running desktop has its own
## ComputerState, so nothing here is global.

## The copy that boot() made. The desktop reads it and changes it (read emails, renamed files).
var setup: Win95Setup


## Starts the computer from `from`. `from` stays unchanged, and so does the .tres it came from.
func boot(from: Win95Setup) -> void:
	setup = from.duplicate_deep()  # loaded resources are shared, so mutating them would leak
