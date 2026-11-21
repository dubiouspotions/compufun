extends "res://win95/window.gd"
## Volume Control: a slider and Mute all, bound to the systray's volume and mute, which own them.

var _systray: Node

@onready var _slider: VSlider = %Slider
@onready var _mute: CheckBox = %Mute


func _ready() -> void:
	super()
	_systray = get_tree().get_first_node_in_group(preload("res://win95/systray.gd").GROUP)
	if _systray == null:
		push_error("Volume Control: no systray in the tree, so the controls do nothing")
		_slider.editable = false
		_mute.disabled = true
		return
	_slider.value_changed.connect(func(value: float) -> void:
		_systray.volume = value
		_systray.volume_changed.emit(value))
	_mute.toggled.connect(func(on: bool) -> void:
		_systray.muted = on
		_systray.mute_toggled.emit(on))
	_systray.volume_changed.connect(func(_value: float) -> void: _sync())
	_systray.mute_toggled.connect(func(_on: bool) -> void: _sync())
	visibility_changed.connect(_sync)
	_sync()


func _sync() -> void:
	_slider.set_value_no_signal(_systray.volume)
	_mute.set_pressed_no_signal(_systray.muted)
