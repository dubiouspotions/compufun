class_name SettingCheck
extends SoftwareCheck
## A problem that is one setting of the Win95 setup, for example muted = true for no_sound.

## The Win95Setup property, for example &"muted".
@export var setting: StringName = &""
## For a Dictionary setting, such as &"cmos": the entry that the check reads and sets; a missing
## entry is 0. Empty checks the setting itself.
@export var key: StringName = &""
## The value that the break sets. Any other value counts as fixed, unless [member fixed_value] is set.
@export var broken_value: Variant
## The one value that counts as fixed, such as "3D Pipes" for a screensaver; null: any value but
## [member broken_value].
@export var fixed_value: Variant


func apply_break(setup: Win95Setup) -> void:
	if not setting in setup:
		push_error("SettingCheck: Win95Setup has no setting %s" % setting)
		return
	_put(setup, broken_value)


func apply_fix(setup: Win95Setup) -> void:
	if not setting in setup:
		push_error("SettingCheck: Win95Setup has no setting %s" % setting)
		return
	var healthy: Variant = fix_value()
	if healthy != null:
		_put(setup, healthy)


## The value that fixes the setting: [member fixed_value], or else the setting's default in a new
## Win95Setup. null, with an error, when that default is the broken value.
func fix_value() -> Variant:
	var healthy: Variant = fixed_value if fixed_value != null else value_in(Win95Setup.new())
	if healthy == broken_value:
		push_error("SettingCheck: the default of %s is its broken value %s, so set fixed_value to fix it" % [setting, broken_value])
		return null
	return healthy


func is_fixed(setup: Win95Setup) -> bool:
	if fixed_value != null:
		return value_in(setup) == fixed_value
	return value_in(setup) != broken_value


## The checked value in [param setup]: the setting, or its [member key] entry.
func value_in(setup: Win95Setup) -> Variant:
	return setup.get(setting) if key == &"" else (setup.get(setting) as Dictionary).get(key, 0)


func _put(setup: Win95Setup, value: Variant) -> void:
	if key == &"":
		setup.set(setting, value)
	else:
		(setup.get(setting) as Dictionary)[key] = value
