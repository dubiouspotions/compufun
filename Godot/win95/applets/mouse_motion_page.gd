extends PropertyPage
## Mouse > Motion: the pointer speed (saved only) and the pointer trail. The trail slider, from
## Short to Long, is greyed while "Show pointer trails" is off; it then keeps its last length, Long
## when the setup has no trail.

static var _palette: Win95Palette = preload("res://win95/theme/palette.tres")


func _ready() -> void:
	%Speed.value_changed.connect(func(_value: float) -> void: edited.emit())
	%TrailLength.value_changed.connect(func(_value: float) -> void: edited.emit())
	%ShowTrails.toggled.connect(func(_on: bool) -> void:
		_sync()
		edited.emit())
	_sync()


func load_from(computer: ComputerState) -> void:
	var setup := computer.setup
	(%Speed as HSlider).set_value_no_signal(setup.pointer_speed)
	(%ShowTrails as CheckBox).set_pressed_no_signal(setup.pointer_trails > 0)
	var length := %TrailLength as HSlider
	length.set_value_no_signal(float(setup.pointer_trails) if setup.pointer_trails > 0 else length.max_value)
	_sync()


func pending() -> Dictionary[StringName, Variant]:
	var trails := int((%TrailLength as HSlider).value) if (%ShowTrails as CheckBox).button_pressed else 0
	return {
		&"pointer_speed": int((%Speed as HSlider).value),
		&"pointer_trails": trails,
	}


func _sync() -> void:
	var on := (%ShowTrails as CheckBox).button_pressed
	(%TrailLength as HSlider).editable = on
	for label: Label in [%Short, %Long]:
		if on:
			label.remove_theme_color_override(&"font_color")
		else:
			label.add_theme_color_override(&"font_color", _palette.shadow_color)
