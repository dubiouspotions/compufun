class_name PcTower
extends Node3D
## A PC tower. Without [method dress] it is a plain beige tower.

## The PC speaker's tone, which [member beeps] gates, and its loudness.
@export var speaker_tone: AudioStream = preload("res://sounds/pc_speaker.wav")
@export var speaker_db: float = -20.0

## Whether the computer runs: its fans hum while it does.
var running: bool = false:
	set(value):
		running = value
		($Fan as Hum).on = value and fans_heard
## False silences the fans' hum, for a computer that sounds otherwise while it runs.
var fans_heard: bool = true:
	set(value):
		fans_heard = value
		($Fan as Hum).on = running and value
## What the PC speaker beeps: seconds on, then off, and so on, repeated; empty is silent. Setting the
## pattern that it beeps already changes nothing, so a caller may set it on every change.
var beeps: PackedFloat32Array = []:
	set(value):
		if value == beeps:
			return
		beeps = value
		if is_node_ready():
			_sync_beeps()

var _speaker: AudioStreamPlayer3D
var _beeping: Tween

@onready var _case: MeshInstance3D = $Case
@onready var _plain_case: Material = _case.material_override
@onready var _front: Node3D = $Front
@onready var _sticker_faces: Dictionary[Sticker.Face, Node3D] = {
	Sticker.Face.FRONT: $StickerFaces/Front,
	Sticker.Face.LEFT: $StickerFaces/Left,
	Sticker.Face.RIGHT: $StickerFaces/Right,
}


func _ready() -> void:
	var fan := $Fan as Node3D
	_speaker = AudioStreamPlayer3D.new()
	_speaker.stream = speaker_tone
	_speaker.volume_db = speaker_db
	_speaker.area_mask = SoundSet.SOUND_ZONES
	_speaker.position = fan.position
	add_child(_speaker)
	_sync_beeps()


## Shows the case material, the case front and the stickers of [param computer]; null shows the
## plain tower.
func dress(computer: Computer) -> void:
	var case_material: Material = computer.case_material if computer != null else null
	_case.material_override = case_material if case_material != null else _plain_case
	Computer.mount_front(computer, _front)
	Sticker.stick(computer.stickers if computer != null else ([] as Array[Sticker]), _sticker_faces)


## The 3.5" floppy drive on the case front, the front's FloppyDrive named Floppy; null for a front without one.
func floppy_drive() -> FloppyDrive:
	return _on_front(^"Floppy") as FloppyDrive


## The CD-ROM drive on the case front, the front's CdDrive named CdRom; null for a front without one.
func cd_drive() -> CdDrive:
	return _on_front(^"CdRom") as CdDrive


func _on_front(path: NodePath) -> Node:
	for front: Node in _front.get_children():
		var node := front.get_node_or_null(path)
		if node != null:
			return node
	return null


func _sync_beeps() -> void:
	if _beeping != null:
		_beeping.kill()
		_beeping = null
	_speaker.stop()
	if beeps.is_empty():
		return
	var total := 0.0
	for seconds: float in beeps:
		total += seconds
	if total <= 0.0:
		push_error("PcTower %s: the beep pattern %s takes no time" % [get_path(), beeps])
		return
	_beeping = create_tween().set_loops()
	for i: int in range(0, beeps.size(), 2):
		_beeping.tween_callback(_speaker.play)
		_beeping.tween_interval(beeps[i])
		_beeping.tween_callback(_speaker.stop)
		if i + 1 < beeps.size():
			_beeping.tween_interval(beeps[i + 1])
