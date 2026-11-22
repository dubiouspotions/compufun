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


## Sets [member fixed_value], or else the setting's default in a new Win95Setup.
func apply_fix(setup: Win95Setup) -> void:
	if not setting in setup:
		push_error("SettingCheck: Win95Setup has no setting %s" % setting)
		return
	var healthy: Variant = fixed_value if fixed_value != null else Win95Setup.new().get(setting)
	if healthy == broken_value:
		push_error("SettingCheck: the default of %s is its broken value %s, so set fixed_value to fix it" % [setting, broken_value])
		return
	setup.set(setting, healthy)


func is_fixed(setup: Win95Setup) -> bool:
	if fixed_value != null:
		return setup.get(setting) == fixed_value
	return setup.get(setting) != broken_value
