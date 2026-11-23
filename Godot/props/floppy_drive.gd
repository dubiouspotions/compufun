class_name FloppyDrive
extends MeshInstance3D
## A 3.5" floppy drive on a case front: the slot, and below its right end the eject button, which
## sticks out while a floppy is in and is flush with the slot while the drive is empty. The floppy
## sticks out of the slot while it is in, with its label; it slides in, and slides out when it is
## ejected. A case front names its drive Floppy (see PcTower.floppy_drive). JobComputer sets its
## state from Game.

## How far the eject button sticks out of the slot's face while a floppy is in, in metres.
@export var eject_travel: float = 0.005
## How long the eject button takes to pop out or go in, in seconds.
@export var eject_seconds: float = 0.08
## How far a floppy slides in from, or out to before it is gone, in metres, and how long that takes.
@export var slide_distance: float = 0.05
@export var slide_seconds: float = 0.25
## The colour of the eject button's pulsing outline while the player can press it, and its tint
## while the mouse is over it.
@export var usable_color: Color = Color(1.0, 0.84, 0.35)
@export var hover_color: Color = Color(0.8, 0.95, 1.0)
## How far the outline stands out from the eject button, in metres.
@export var outline_width: float = 0.002

## True while a floppy is in the drive: the disk sticks out and so does the eject button. Set it
## with [method set_floppy_in].
var floppy_in: bool = false
## The label printed on the disk that sticks out (FloppyDisk.label); null shows the plain label.
var disk_label: Texture2D:
	set(value):
		disk_label = value
		if is_node_ready():
			_disk.label = value
## True while a click on the drive ejects or inserts a floppy: the eject button pulses an outline.
var usable: bool = false:
	set(value):
		usable = value
		if is_node_ready():
			_sync_highlight()
## True while the mouse is over the eject button: it is tinted in [member hover_color].
var hovered: bool = false:
	set(value):
		hovered = value
		if is_node_ready():
			_sync_highlight()

var _outline: StandardMaterial3D
var _hover: StandardMaterial3D
var _moving: Tween

## The eject button. Its position is the pressed-in one only while [member floppy_in] is false.
@onready var eject_button: MeshInstance3D = $EjectButton
@onready var _flush: Vector3 = eject_button.position
@onready var _disk: FloppyDiskModel = $Disk
@onready var _disk_in: Vector3 = _disk.position
var _sliding: Tween


func _ready() -> void:
	_outline = Hotspot.outline_material(usable_color, outline_width)
	_hover = Hotspot.ghost_material(hover_color)
	_hover.albedo_color.a = 0.6
	_hover.next_pass = Hotspot.outline_material(hover_color, outline_width)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_method(_pulse, 0.0, 1.0, 0.7)
	pulse.tween_method(_pulse, 1.0, 0.0, 0.7)
	_disk.label = disk_label
	_move(false)
	_sync_highlight()


## Puts a floppy in the drive or takes it out. With [param animate], the disk slides in or out and
## the eject button pops out or goes in; without, they stand there at once, as for a new drive.
func set_floppy_in(value: bool, animate := true) -> void:
	if value == floppy_in:
		return
	floppy_in = value
	if is_node_ready():
		_move(animate)


func _move(animate: bool) -> void:
	for tween: Tween in [_sliding, _moving]:
		if tween != null:
			tween.kill()
	var out := _disk_in + Vector3(0, 0, slide_distance)
	var button := _flush + Vector3(0, 0, eject_travel if floppy_in else 0.0)
	if not animate:
		_disk.position = _disk_in
		_disk.visible = floppy_in
		eject_button.position = button
		return
	if floppy_in:
		_disk.position = out
		_disk.visible = true
		_sliding = create_tween()
		_sliding.tween_property(_disk, ^"position", _disk_in, slide_seconds)
	elif _disk.visible:
		_sliding = create_tween()
		_sliding.tween_property(_disk, ^"position", out, slide_seconds)
		_sliding.tween_callback(func() -> void: _disk.visible = floppy_in)
	_moving = create_tween()
	_moving.tween_property(eject_button, ^"position", button, eject_seconds)


func _pulse(t: float) -> void:
	_outline.albedo_color = usable_color.lerp(Color.WHITE, 0.35 * t)


func _sync_highlight() -> void:
	eject_button.material_overlay = _hover if hovered else _outline if usable else null
