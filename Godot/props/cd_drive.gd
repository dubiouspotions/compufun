class_name CdDrive
extends Node3D
## A CD-ROM drive on a case front: the bay, its tray, the eject button and the busy light. A press
## on a powered drive opens or closes the tray: the button dips, the tray starts after a moment,
## travels to its stop and knocks against it, and a closed tray spins the disc up with the light
## blinking. A press while the tray moves stops it, and after [member reverse_pause] it goes back. The default timing follows the sounds that tools/make_cd_sounds.py cuts from a real
## drive. A case front names its drive CdRom (see PcTower.cd_drive).

## How far the open tray stands out of the bay, in metres.
@export var tray_travel: float = 0.12
## The seconds from a press until the tray starts to open, and the seconds that it takes to open.
@export var open_delay: float = 0.12
@export var open_seconds: float = 0.4
## The seconds from a press until the tray starts to close, and the seconds until it hits its stop.
@export var close_delay: float = 0.03
@export var close_seconds: float = 0.47
## The seconds that the light blinks after the tray closes, while the disc spins up.
@export var spin_up_seconds: float = 1.4
## The seconds that the tray stands still when a press turns it around halfway.
@export var reverse_pause: float = 0.12
## How far the eject button goes in when pressed, in metres.
@export var button_travel: float = 0.0015
## The colour of the busy light while the drive works.
@export var busy_color: Color = Color(1.0, 0.6, 0.15)
@export var button_sound: SoundSet = preload("res://sounds/cd_button.tres")
@export var open_sound: SoundSet = preload("res://sounds/cd_tray_open.tres")
@export var close_sound: SoundSet = preload("res://sounds/cd_tray_close.tres")

## True while the tray is out, or on its way out.
var is_open: bool = false

var _lit: StandardMaterial3D
var _tray_sound: AudioStreamPlayer3D
var _motion: Tween
var _blink: Tween

## The eject button, right of the tray.
@onready var eject_button: MeshInstance3D = $EjectButton
@onready var _tray: Node3D = $Tray
@onready var _tray_in: Vector3 = _tray.position
@onready var _button_out: Vector3 = eject_button.position
@onready var _light: MeshInstance3D = $BusyLight
@onready var _light_off: Material = _light.material_override


func _ready() -> void:
	_lit = StandardMaterial3D.new()
	_lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lit.albedo_color = busy_color
	_tray_sound = AudioStreamPlayer3D.new()
	_tray_sound.area_mask = SoundSet.SOUND_ZONES
	add_child(_tray_sound)


## Presses the eject button. With [param powered], the tray opens or closes, or turns around if
## it is moving; without, only the button clicks, as on a real drive.
func press(powered: bool) -> void:
	var dip := create_tween()
	dip.tween_property(eject_button, ^"position", _button_out - Vector3(0, 0, button_travel), 0.05)
	dip.tween_property(eject_button, ^"position", _button_out, 0.08)
	if not powered:
		button_sound.play_at(self)
		return
	_move(not is_open)


## Opens or closes the tray from where it stands, as a press does but without the button.
func set_open(open: bool) -> void:
	if open != is_open:
		_move(open)


func _move(open: bool) -> void:
	var turning := _motion != null and _motion.is_running()
	for tween: Tween in [_motion, _blink]:
		if tween != null:
			tween.kill()
	is_open = open
	var out := clampf((_tray.position.z - _tray_in.z) / tray_travel, 0.0, 1.0)
	var full := open_seconds if open else close_seconds
	var seconds := maxf(0.02, full * (1.0 - out if open else out))
	var delay := reverse_pause if turning else open_delay if open else close_delay
	# A turn plays the take from later on, so that its knock still lands as the tray stops.
	var knock_at := (open_delay if open else close_delay) + full
	(open_sound if open else close_sound).play_on(_tray_sound, maxf(0.0, knock_at - delay - seconds))
	var end := _tray_in + Vector3(0, 0, tray_travel if open else 0.0)
	var knock := 0.003 if open else -0.002
	_motion = create_tween()
	_motion.tween_callback(_set_light.bind(true)).set_delay(delay)
	_motion.tween_property(_tray, ^"position", end + Vector3(0, 0, knock), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(_tray, ^"position", end, 0.07)
	_motion.tween_callback(_set_light.bind(false))
	if not open:
		_motion.tween_callback(_spin_up)


func _spin_up() -> void:
	if _blink != null:
		_blink.kill()
	_blink = create_tween().set_loops(int(spin_up_seconds / 0.16))
	_blink.tween_callback(_set_light.bind(true))
	_blink.tween_interval(0.06)
	_blink.tween_callback(_set_light.bind(false))
	_blink.tween_interval(0.1)


func _set_light(on: bool) -> void:
	_light.material_override = _lit if on else _light_off
