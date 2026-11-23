extends Control
## In debug builds on touch, a row of buttons for the debug tools that a keyboard reaches with
## keys: F2, F3, F4, F9 and Skip (Cmd+N). Each button sends the first key of its action, pressed
## and released, so the tools' own key handlers run. Shows while TouchControls.touch_mode is on.

## Each button: its text and the action whose first key it sends.
const BUTTONS: Array[Array] = [["F2 Debug", &"debug_menu"], ["F3 Dev", &"dev_menu"], ["F4 Story", &"story_lab"], ["F9 Report", &"feedback"], ["Skip", &"skip_ahead"]]
## The actions that only the Dev menu answers.
const DEV_ACTIONS: Array[StringName] = [&"dev_menu", &"story_lab"]
## The smallest button, in canvas pixels (1920 x 1080).
const MIN_BUTTON_SIZE: Vector2 = Vector2(96, 56)
const DEV_MENU: String = preload("res://main.gd").DEV_MENU

var _touch_mode: bool = false
var _hidden_for_shot: bool = false

@onready var _row: HBoxContainer = %Row


func _ready() -> void:
	var has_dev_menu := ResourceLoader.exists(DEV_MENU)
	for spec: Array in BUTTONS:
		var action: StringName = spec[1]
		if action in DEV_ACTIONS and not has_dev_menu:
			continue
		var button := Button.new()
		button.text = spec[0]
		button.name = String(action)
		button.custom_minimum_size = MIN_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE  # a tap must not take the keyboard from a text field
		button.pressed.connect(_on_pressed.bind(action))
		_row.add_child(button)
	var controls := get_parent() as TouchControls
	if controls != null:
		controls.touch_mode_changed.connect(show_for)
		show_for(controls.touch_mode)
	else:
		show_for(false)


## Shows the strip when [param touch_mode] is on in a debug build.
func show_for(touch_mode: bool) -> void:
	_touch_mode = touch_mode
	visible = OS.is_debug_build() and touch_mode and not _hidden_for_shot


## Sends the first key of [param action] in the InputMap, pressed and then released.
func press(action: StringName) -> void:
	var key := key_of(action)
	if key == null:
		push_error("Debug strip: the action %s has no key in the InputMap (project.godot)" % action)
		return
	key.pressed = true
	Input.parse_input_event(key)
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)


## A copy of the first InputEventKey of [param action], or null when it has none.
static func key_of(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.duplicate() as InputEventKey
	return null


func _on_pressed(action: StringName) -> void:
	if action != &"feedback":
		press(action)
		return
	# F9 screenshots the last drawn frame: draw one without the strip first.
	_hidden_for_shot = true
	show_for(_touch_mode)
	await get_tree().process_frame
	await get_tree().process_frame
	press(action)
	await get_tree().process_frame
	_hidden_for_shot = false
	show_for(_touch_mode)
