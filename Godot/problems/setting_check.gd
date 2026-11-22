class_name SettingCheck
extends SoftwareCheck
## A problem that is one setting of the Win95 setup, for example muted = true for no_sound.

## The Win95Setup property, for example &"muted".
@export var setting: StringName = &""
## The value that the break sets. Any other value counts as fixed, unless [member fixed_value] is set.
@export var broken_value: Variant
## The one value that counts as fixed, such as "3D Pipes" for a screensaver; null: any value but
## [member broken_value].
@export var fixed_value: Variant


func apply_break(setup: Win95Setup) -> void:
	if not setting in setup:
		push_error("SettingCheck: Win95Setup has no setting %s" % setting)
		return
	setup.set(setting, broken_value)


func is_fixed(setup: Win95Setup) -> bool:
	if fixed_value != null:
		return setup.get(setting) == fixed_value
	return setup.get(setting) != broken_value
