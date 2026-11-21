class_name SettingCheck
extends SoftwareCheck
## A problem that is one setting of the Win95 setup, for example muted = true for no_sound.

## The Win95Setup property, for example &"muted".
@export var setting: StringName = &""
## The value that the break sets. Any other value counts as fixed.
@export var broken_value: Variant


func apply_break(setup: Win95Setup) -> void:
	if not setting in setup:
		push_error("SettingCheck: Win95Setup has no setting %s" % setting)
		return
	setup.set(setting, broken_value)


func is_fixed(setup: Win95Setup) -> bool:
	return setup.get(setting) != broken_value
