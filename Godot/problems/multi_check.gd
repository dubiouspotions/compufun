class_name MultiCheck
extends SoftwareCheck
## A problem made of several checks: the break applies them all, and it is fixed when every one is.
## Noimages: every program in C:\WINDOWS lost its .EXE, one FileCheck each.

@export var checks: Array[SoftwareCheck] = []


func apply_break(setup: Win95Setup) -> void:
	for check: SoftwareCheck in checks:
		if check == null:
			push_error("MultiCheck: %s has an empty check" % resource_path)
			continue
		check.apply_break(setup)


func is_fixed(setup: Win95Setup) -> bool:
	return checks.all(func(check: SoftwareCheck) -> bool: return check != null and check.is_fixed(setup))
