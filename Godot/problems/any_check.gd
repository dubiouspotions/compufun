class_name AnyCheck
extends SoftwareCheck
## A problem with several ways out: the break applies every check, and it is fixed when any one is.
## Bootfloppy: eject the floppy, or set BIOS Setup's Boot Sequence to C,A.

## The first is the way that CompuFunDB teaches and that apply_fix takes.
@export var checks: Array[SoftwareCheck] = []


func apply_break(setup: Win95Setup) -> void:
	for check: SoftwareCheck in checks:
		if check == null:
			push_error("AnyCheck: %s has an empty check" % resource_path)
			continue
		check.apply_break(setup)


func apply_fix(setup: Win95Setup) -> void:
	if checks.is_empty() or checks[0] == null:
		push_error("AnyCheck: %s has no first check to fix" % resource_path)
		return
	checks[0].apply_fix(setup)


func is_fixed(setup: Win95Setup) -> bool:
	return checks.any(func(check: SoftwareCheck) -> bool: return check != null and check.is_fixed(setup))
