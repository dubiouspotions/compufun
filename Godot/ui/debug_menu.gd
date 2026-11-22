class_name DebugMenu
extends CanvasLayer
## The debug menu, F2 or Cmd+2 (debug builds only). The World tab: the time of day, the day cycle and the rain of the
## Outside node in the scene (the group "outside"), and the finale (finale/finale.tscn), on this computer or as
## another one.

const TIME_BUTTONS: Dictionary = {"MorningButton": Game.Daypart.MORNING, "NoonButton": Game.Daypart.MIDDAY,
	"AfternoonButton": Game.Daypart.AFTERNOON, "EveningButton": Game.Daypart.EVENING, "NightButton": Game.Daypart.NIGHT}
const DEFAULT_DAY_MINUTES: float = 10.0
const FINALE: PackedScene = preload("res://finale/finale.tscn")
const FINALE_BUTTONS: Dictionary = {"FinaleAuto": Finale.HostChoice.AUTO, "FinaleWindows": Finale.HostChoice.WINDOWS,
	"FinaleMacOS": Finale.HostChoice.MACOS, "FinaleLinux": Finale.HostChoice.LINUX}

var _outside: Outside

@onready var _panel: Control = %Panel
@onready var _time: Label = %TimeLabel
@onready var _slider: HSlider = %TimeSlider
@onready var _cycle: CheckBox = %CycleBox
@onready var _minutes: SpinBox = %MinutesBox
@onready var _rain: CheckBox = %RainBox
@onready var _relief: CheckBox = %ReliefBox
@onready var _fps: Label = %FpsLabel


func _ready() -> void:
	_panel.visible = false
	_slider.value_changed.connect(_on_slider)
	for button_name: String in TIME_BUTTONS:
		(get_node("%" + button_name) as Button).pressed.connect(_on_time_button.bind(TIME_BUTTONS[button_name]))
	_cycle.toggled.connect(_on_cycle)
	_minutes.value_changed.connect(_on_minutes)
	_rain.toggled.connect(_on_rain)
	_relief.toggled.connect(_on_relief)
	for button_name: String in FINALE_BUTTONS:
		(get_node("%" + button_name) as Button).pressed.connect(_play_finale.bind(FINALE_BUTTONS[button_name]))


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and not key.echo and key.is_action_pressed(&"debug_menu") and OS.is_debug_build():
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


## Opens or closes the menu. Opening finds the Outside node and a customer body again and reads their state.
func toggle() -> void:
	_panel.visible = not _panel.visible
	if not _panel.visible:
		return
	var body := get_tree().get_first_node_in_group(CustomerBody.GROUP) as CustomerBody
	_relief.disabled = body == null
	if body != null:
		_relief.set_pressed_no_signal(body.photo_relief)
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


# Closes the menu and plays the finale in the running game, showing the restart of [param host].
func _play_finale(host: Finale.HostChoice) -> void:
	toggle()
	if get_tree().get_first_node_in_group(Finale.GROUP) != null:
		return  # one plays already
	var finale := FINALE.instantiate() as Finale
	finale.host = host
	get_tree().current_scene.add_child(finale)
	finale.play()


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


# Switches every customer between the photo relief and the modelled body, for a side by side look.
func _on_relief(on: bool) -> void:
	for node: Node in get_tree().get_nodes_in_group(CustomerBody.GROUP):
		(node as CustomerBody).photo_relief = on


func _on_rain(on: bool) -> void:
	if _outside != null:
		_outside.raining = on
