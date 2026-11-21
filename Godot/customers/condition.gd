@tool
class_name Condition
extends Resource
## When something may happen: the days, the flags that must be set and the flags that must not be.
## A flag is set when its number is not 0.

@export_range(1, 7) var from_day: int = 1
@export_range(1, 7) var to_day: int = 7
@export var need_flags: Array[StringName] = []
@export var not_flags: Array[StringName] = []


## True on [param day] (1 to 7) with [param flags] (name to number).
func is_met(day: int, flags: Dictionary[StringName, int]) -> bool:
	if day < from_day or day > to_day:
		return false
	for flag: StringName in need_flags:
		if flags.get(flag, 0) == 0:
			return false
	for flag: StringName in not_flags:
		if flags.get(flag, 0) != 0:
			return false
	return true
