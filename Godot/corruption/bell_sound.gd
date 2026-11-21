extends CorruptionSign
## The door bell plays a Windows sound once. Stage 1, armed: the bell's next ring plays [member sound]
## instead of the bell, and that ring moves the sign on to stage 2, done. Stage 2: the bell rings as
## a bell again, once [member sound] has played out.

## The Win95 sound that the bell plays once.
@export var sound: AudioStream = preload("res://win95/sounds/tada.ogg")

var _bell: AudioStreamPlayer3D
var _bell_sound: AudioStream
## Until this time (Time.get_ticks_msec) [member sound] plays, so the bell keeps it.
var _ring_ends_msec: int = 0


func _ready() -> void:
	_bell = get_tree().get_first_node_in_group(&"door_bell") as AudioStreamPlayer3D
	if _bell == null:
		push_error("BellSound: no AudioStreamPlayer3D in the group door_bell")
	else:
		_bell_sound = _bell.stream
	if sound == null:
		push_error("BellSound: %s has no sound" % scene_file_path)
	super()


# The shop rings the bell with play(), which has no signal: a ring is the bell starting to play.
func _process(_delta: float) -> void:
	if not _bell.playing:
		return
	var seconds := sound.get_length() / maxf(0.1, _bell.pitch_scale)
	_ring_ends_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	# A timer, not the bell's finished signal: with no audio device that never fires.
	get_tree().create_timer(seconds + 0.1).timeout.connect(_rang)
	set_stage(2)


func _rang() -> void:
	_apply(stage())


func _apply(shown_stage: int) -> void:
	set_process(_bell != null and sound != null and shown_stage == 1)
	if _bell == null or sound == null:
		return
	if shown_stage == 0:
		_ring_ends_msec = 0
	var ringing := Time.get_ticks_msec() < _ring_ends_msec
	var wanted: AudioStream = sound if shown_stage == 1 or ringing else _bell_sound
	# Setting the stream stops the player, so set it only when it changes.
	if _bell.stream != wanted:
		_bell.stream = wanted
