extends PanelContainer
## The notification area at the right end of the taskbar: the speaker and the clock.

## The player clicked the speaker; `muted` is the new state.
signal mute_toggled(muted: bool)

const _SPEAKER := preload("res://win95/theme/icons/tray_speaker_16.png")
const _SPEAKER_MUTED := preload("res://win95/theme/icons/tray_speaker_muted_16.png")

## Draws the speaker crossed out. Setting it doesn't emit mute_toggled.
@export var muted := false:
	set(value):
		muted = value
		if is_node_ready():
			_sync()

@onready var _speaker: TextureButton = %Speaker
@onready var _clock: Label = %Clock


func _ready() -> void:
	_speaker.pressed.connect(func() -> void:
		muted = not muted
		mute_toggled.emit(muted))
	%ClockTimer.timeout.connect(_sync)
	_sync()


func _sync() -> void:
	_speaker.texture_normal = _SPEAKER_MUTED if muted else _SPEAKER
	var now := Time.get_time_dict_from_system()
	var hour: int = now.hour
	_clock.text = "%d:%02d %s" % [(hour + 11) % 12 + 1, now.minute, "PM" if hour >= 12 else "AM"]
