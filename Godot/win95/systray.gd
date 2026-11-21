extends PanelContainer
## The notification area at the right end of the taskbar: the speaker and the clock. Clicking the
## speaker opens the volume popup, with a slider and a Mute checkbox, as in Win95.

## The player ticked or cleared Mute; `muted` is the new state.
signal mute_toggled(muted: bool)
## The player moved the volume slider; `volume` runs from 0 to 100.
signal volume_changed(volume: float)

## The group of the systray, for Volume Control to find the one volume and mute.
const GROUP: StringName = &"win95_systray"
const _SPEAKER := preload("res://win95/theme/icons/tray_speaker_16.png")
const _SPEAKER_MUTED := preload("res://win95/theme/icons/tray_speaker_muted_16.png")

## Crosses out the speaker and ticks Mute. Setting it doesn't emit mute_toggled.
@export var muted := false:
	set(value):
		muted = value
		if is_node_ready():
			_sync()
## 0 to 100. Setting it doesn't emit volume_changed.
@export_range(0, 100) var volume := 75.0:
	set(value):
		volume = value
		if is_node_ready():
			_sync()

@onready var _speaker: TextureButton = %Speaker
@onready var _clock: Label = %Clock
@onready var _popup: PopupPanel = %VolumePopup
@onready var _slider: VSlider = %VolumeSlider
@onready var _mute: CheckBox = %Mute


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_speaker.pressed.connect(_open_volume)
	_mute.toggled.connect(func(on: bool) -> void:
		muted = on
		mute_toggled.emit(on))
	_slider.value_changed.connect(func(value: float) -> void:
		volume = value
		volume_changed.emit(value))
	%ClockTimer.timeout.connect(_sync)
	_sync()


func _open_volume() -> void:
	var popup_size := Vector2i(_popup.get_contents_minimum_size())
	var tray := get_global_rect()
	var corner := Vector2i(int(tray.end.x) - popup_size.x, int(tray.position.y) - popup_size.y)
	_popup.popup(Rect2i(corner, popup_size))


func _sync() -> void:
	_speaker.texture_normal = _SPEAKER_MUTED if muted else _SPEAKER
	_mute.set_pressed_no_signal(muted)
	_slider.set_value_no_signal(volume)
	var now := Time.get_time_dict_from_system()
	var hour: int = now.hour
	_clock.text = "%d:%02d %s" % [(hour + 11) % 12 + 1, now.minute, "PM" if hour >= 12 else "AM"]
