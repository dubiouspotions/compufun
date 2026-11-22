class_name FloppyDrive
extends MeshInstance3D
## A 3.5" floppy drive on a case front: the slot, and below its right end the eject button, which
## sticks out while a floppy is in and is flush with the slot while the drive is empty. A case front
## names its drive Floppy (see PcTower.floppy_drive). JobComputer sets its state from Game.

## How far the eject button sticks out of the slot's face while a floppy is in, in metres.
@export var eject_travel: float = 0.005
## How long the eject button takes to pop out or go in, in seconds.
@export var eject_seconds: float = 0.08
## The colour of the eject button's pulsing outline while the player can press it, and its tint
## while the mouse is over it.
@export var usable_color: Color = Color(1.0, 0.84, 0.35)
@export var hover_color: Color = Color(0.8, 0.95, 1.0)
## How far the outline stands out from the eject button, in metres.
@export var outline_width: float = 0.002

## True while a floppy is in the drive: the eject button sticks out.
var floppy_in: bool = false:
	set(value):
		if value != floppy_in:
			floppy_in = value
			if is_node_ready():
				_move_button()
## True while the player can press the eject button: it pulses an outline.
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


func _ready() -> void:
	_outline = Hotspot.outline_material(usable_color, outline_width)
	_hover = Hotspot.ghost_material(hover_color)
	_hover.albedo_color.a = 0.6
	_hover.next_pass = Hotspot.outline_material(hover_color, outline_width)
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_method(_pulse, 0.0, 1.0, 0.7)
	pulse.tween_method(_pulse, 1.0, 0.0, 0.7)
	_move_button()
	_sync_highlight()


func _move_button() -> void:
	var target := _flush + Vector3(0, 0, eject_travel if floppy_in else 0.0)
	if _moving != null:
		_moving.kill()
	_moving = create_tween()
	_moving.tween_property(eject_button, ^"position", target, eject_seconds)


func _pulse(t: float) -> void:
	_outline.albedo_color = usable_color.lerp(Color.WHITE, 0.35 * t)


func _sync_highlight() -> void:
	eject_button.material_overlay = _hover if hovered else _outline if usable else null
