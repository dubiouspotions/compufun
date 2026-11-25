extends CorruptionSign
## A jump scare, armed at stage 1: the next time the player enters the Storage view, the lights go
## out, a life-size Clippy flashes up in the dark for a blink or two, and the lights come back
## without him. Then stage 2, done. From the moment the player enters, they can't move, and the turn
## buttons hide, until the lights are back.

const STORAGE_VIEW: StringName = &"Storage"

## The seconds between entering the Storage view and the lights going out: the camera's turn.
@export var arrive_seconds: float = 0.6
## How the lights flicker out: seconds dark, then lit, then dark and so on, before they stay out.
@export var flicker_seconds: PackedFloat32Array = [0.05, 0.08, 0.04, 0.14, 0.06, 0.05]
## How the lights flicker back: seconds lit, then dark, then lit and so on, before they stay on.
@export var return_flicker_seconds: PackedFloat32Array = [0.03, 0.05, 0.02, 0.07, 0.03, 0.03]
## The seconds of dark before the whisper.
@export var whisper_after_seconds: float = 0.8
## The seconds of dark before the first flash, from the start of the whisper.
@export var dark_seconds: float = 1.8
## The times that Clippy flashes up.
@export var flashes: int = 2
## The seconds that each flash shows Clippy.
@export var flash_seconds: float = 0.1
## The seconds of dark between two flashes.
@export var between_seconds: float = 0.15
## The seconds of dark after the last flash, before the lights come back.
@export var after_seconds: float = 0.4
## Who speaks: Clippy's voice.
@export var voice: VoicePerson
## Said as the lights go out, with its own effect.
@export var whisper: DialogueLine
## Said as Clippy first flashes up, with its own effect.
@export var shout: DialogueLine

var _scare: Tween
var _dark: bool = false

@onready var _clippy: Node3D = %Clippy
@onready var _lights_out: CanvasItem = %LightsOut
@onready var _voice: VoicePlayer = %Voice


func _ready() -> void:
	var room := get_tree().get_first_node_in_group(&"storage_room") as Node3D
	if room == null:
		push_error("clippy_jumpscare: no Node3D in the group storage_room")
	else:
		_clippy.global_transform = room.global_transform * _clippy.transform  # his scene transform is in the room's space
	_voice.bus = &"Master"  # the Voice bus goes through the Shop bus, which pans the shop to the right while in storage
	super()


# No turns, clicks or swipes while the scare runs.
func _input(event: InputEvent) -> void:
	if _scare == null or not _scare.is_running():
		return
	var turn := event.is_action(&"turn_left") or event.is_action(&"turn_right") or event.is_action(&"look_up") or event.is_action(&"go_back")
	if turn or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()


func _apply(shown_stage: int) -> void:
	var running := _scare != null and _scare.is_running()
	if shown_stage != 1:
		_stop()
		return
	if running and Game.view != STORAGE_VIEW:
		var seen := _dark
		_stop()
		if seen:
			set_stage.call_deferred(2)
	elif not running and Game.view == STORAGE_VIEW:
		_start()


func _start() -> void:
	_hold(true)
	_scare = create_tween()
	_scare.tween_interval(arrive_seconds)
	for i: int in flicker_seconds.size():
		_scare.tween_callback(_show.bind(i % 2 == 0, false))
		_scare.tween_interval(flicker_seconds[i])
	_scare.tween_callback(_show.bind(true, false))
	_scare.tween_interval(whisper_after_seconds)
	_scare.tween_callback(_say.bind(whisper))
	_scare.tween_interval(dark_seconds)
	for flash: int in flashes:
		if flash > 0:
			_scare.tween_interval(between_seconds)
		_scare.tween_callback(_show.bind(false, true))
		if flash == 0:
			_scare.tween_callback(_say.bind(shout))
		_scare.tween_interval(flash_seconds)
		_scare.tween_callback(_show.bind(true, false))
	_scare.tween_interval(after_seconds)
	for i: int in return_flicker_seconds.size():
		_scare.tween_callback(_show.bind(i % 2 == 1, false))
		_scare.tween_interval(return_flicker_seconds[i])
	_scare.tween_callback(_finish)


func _finish() -> void:
	_scare = null  # done: the stage change below must not kill the tween that calls this
	_show(false, false)
	_hold(false)
	set_stage(2)


func _say(line: DialogueLine) -> void:
	_voice.say(line, voice, line.effect)


func _stop() -> void:
	if _scare != null:
		_scare.kill()
		_voice.hush()  # cut short; a finished scare lets the shout ring out
		_hold(false)
	_show(false, false)


# Hides the turn buttons while [param on].
func _hold(on: bool) -> void:
	var ui := get_tree().get_first_node_in_group(&"ui_layer")
	var nav := ui.get_node_or_null("%ViewNav") as Control if ui != null else null
	if nav == null:
		push_error("clippy_jumpscare: no %ViewNav under the group ui_layer")
		return
	nav.visible = not on


func _show(dark: bool, clippy: bool) -> void:
	_dark = dark or clippy
	_lights_out.visible = dark
	_clippy.visible = clippy
