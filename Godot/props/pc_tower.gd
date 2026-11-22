class_name PcTower
extends Node3D
## A PC tower. Without [method dress] it is a plain beige tower.

## Whether the computer runs: its fans hum while it does.
var running: bool = false:
	set(value):
		running = value
		($Fan as Hum).on = value

@onready var _case: MeshInstance3D = $Case
@onready var _plain_case: Material = _case.material_override
@onready var _front: Node3D = $Front
@onready var _sticker_faces: Dictionary[Sticker.Face, Node3D] = {
	Sticker.Face.FRONT: $StickerFaces/Front,
	Sticker.Face.LEFT: $StickerFaces/Left,
	Sticker.Face.RIGHT: $StickerFaces/Right,
}


## Shows the case material, the case front and the stickers of [param computer]; null shows the
## plain tower.
func dress(computer: Computer) -> void:
	var case_material: Material = computer.case_material if computer != null else null
	_case.material_override = case_material if case_material != null else _plain_case
	Computer.mount_front(computer, _front)
	Sticker.stick(computer.stickers if computer != null else ([] as Array[Sticker]), _sticker_faces)


## The 3.5" floppy drive on the case front, the front's node named Floppy; null for a front without one.
func floppy_drive() -> MeshInstance3D:
	for front: Node in _front.get_children():
		var drive := front.get_node_or_null(^"Floppy") as MeshInstance3D
		if drive != null:
			return drive
	return null
