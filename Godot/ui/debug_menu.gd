class_name DebugMenu
extends CanvasLayer
## The debug menu, F2 (debug builds only). The World tab: the time of day, the day cycle and the rain of the
## Outside node in the scene (the group "outside").

const TIME_BUTTONS: Dictionary = {"MorningButton": Game.Daypart.MORNING, "NoonButton": Game.Daypart.MIDDAY,
	"EveningButton": Game.Daypart.EVENING, "NightButton": Game.Daypart.NIGHT}
const DEFAULT_DAY_MINUTES: float = 10.0

var _outside: Outside

@onready var _panel: Control = %Panel
@onready var _time: Label = %TimeLabel
@onready var _slider: HSlider = %TimeSlider
@onready var _cycle: CheckBox = %CycleBox
@onready var _minutes: SpinBox = %MinutesBox
@onready var _rain: CheckBox = %RainBox
@onready var _fps: Label = %FpsLabel


func _ready() -> void:
	_panel.visible = false
	_slider.value_changed.connect(_on_slider)
	for button_name: String in TIME_BUTTONS:
		(get_node("%" + button_name) as Button).pressed.connect(_on_time_button.bind(TIME_BUTTONS[button_name]))
	_cycle.toggled.connect(_on_cycle)
	_minutes.value_changed.connect(_on_minutes)
	_rain.toggled.connect(_on_rain)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2 and OS.is_debug_build():
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


## Opens or closes the menu. Opening finds the Outside node again and reads its state.
func toggle() -> void:
	_panel.visible = not _panel.visible
	if not _panel.visible:
		return
	_outside = get_tree().get_first_node_in_group(&"outside") as Outside
	var found := _outside != null
	_slider.editable = found
	_minutes.editable = found
	_cycle.disabled = not found
	_rain.disabled = not found
	if not found:
		_time.text = "No Outside node in this scene."
		return
	_slider.set_value_no_signal(_outside.hour)
	_cycle.set_pressed_no_signal(_outside.day_minutes > 0.0)
	_minutes.set_value_no_signal(_outside.day_minutes if _outside.day_minutes > 0.0 else DEFAULT_DAY_MINUTES)
	_rain.set_pressed_no_signal(_outside.raining)


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _outside == null:
		return
	var minutes := int(_outside.hour * 60.0)
	_time.text = "Time %02d:%02d" % [minutes / 60, minutes % 60]
	if _outside.day_minutes > 0.0:
		_slider.set_value_no_signal(_outside.hour)


func _on_slider(value: float) -> void:
	if _outside != null:
		_outside.hour = value
		_slider.set_value_no_signal(value)


func _on_time_button(daypart: int) -> void:
	if _outside != null:
		_on_slider(_outside.hour_of(daypart))


func _on_cycle(on: bool) -> void:
	if _outside != null:
		_outside.day_minutes = _minutes.value if on else 0.0


func _on_minutes(value: float) -> void:
	if _outside != null and _cycle.button_pressed:
		_outside.day_minutes = value


func _on_rain(on: bool) -> void:
	if _outside != null:
		_outside.raining = on
