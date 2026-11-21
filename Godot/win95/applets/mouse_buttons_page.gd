extends PropertyPage
## Mouse > Buttons: left- or right-handed, and the double-click speed. The picture and the two
## button descriptions follow the choice at once; the desktop changes on Apply. The Test area's
## jack-in-the-box pops out and back on a double-click at the slider's speed, also before Apply.

## The slider runs from Slow (left) to Fast (right), so its value is this minus double_click_ms.
const _CLICK_SUM := 1000

## What the button that selects does, and what the other one does.
@export_multiline var select_text := ""
@export_multiline var menu_text := ""
@export var right_handed_picture: Texture2D
@export var left_handed_picture: Texture2D
## The jack-in-the-box, frames side by side: frame 0 closed, then the popped-out frames from
## lowest to highest.
@export var jack_frames: Texture2D
@export var jack_frame_size := Vector2(31, 45)
## Seconds per frame while the jack bobs.
@export var jack_frame_seconds := 0.12

var _jack_out := false
var _jack_time := 0.0
var _last_press_ms := -1
var _last_press_at := Vector2.ZERO
var _jack_atlas := AtlasTexture.new()


func _ready() -> void:
	%LeftHanded.toggled.connect(func(_on: bool) -> void:
		_sync()
		edited.emit())
	%DoubleClick.value_changed.connect(func(_value: float) -> void: edited.emit())
	%TestArea.gui_input.connect(_on_test_area_input)
	_jack_atlas.atlas = jack_frames
	%Jack.texture = _jack_atlas
	_show_jack_frame(0)
	_sync()


func load_from(computer: ComputerState) -> void:
	var setup := computer.setup
	(%LeftHanded as CheckBox).set_pressed_no_signal(setup.left_handed)
	(%RightHanded as CheckBox).set_pressed_no_signal(not setup.left_handed)
	(%DoubleClick as HSlider).set_value_no_signal(_CLICK_SUM - setup.double_click_ms)
	_sync()


func pending() -> Dictionary[StringName, Variant]:
	return {
		&"left_handed": (%LeftHanded as CheckBox).button_pressed,
		&"double_click_ms": _double_click_ms(),
	}


func _process(delta: float) -> void:
	if not _jack_out:
		return
	_jack_time += delta
	var popped := int(jack_frames.get_width() / jack_frame_size.x) - 1
	var step := int(_jack_time / jack_frame_seconds) % (2 * popped - 2)
	_show_jack_frame(1 + (step if step < popped else 2 * popped - 2 - step))


func _sync() -> void:
	var left_handed := (%LeftHanded as CheckBox).button_pressed
	%Picture.texture = left_handed_picture if left_handed else right_handed_picture
	%LeftButton.text = menu_text if left_handed else select_text
	%RightButton.text = select_text if left_handed else menu_text


func _double_click_ms() -> int:
	return _CLICK_SUM - int((%DoubleClick as HSlider).value)


# Win95 tests the slider's speed here, before Apply, so this judges the presses itself.
func _on_test_area_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var now := Time.get_ticks_msec()
	if _last_press_ms >= 0 and MouseInput.is_double_click(now - _last_press_ms, _last_press_at, button.position, _double_click_ms()):
		_jack_out = not _jack_out
		_jack_time = 0.0
		_show_jack_frame(1 if _jack_out else 0)
		_last_press_ms = -1
	else:
		_last_press_ms = now
		_last_press_at = button.position


func _show_jack_frame(index: int) -> void:
	_jack_atlas.region = Rect2(Vector2(index * jack_frame_size.x, 0), jack_frame_size)
