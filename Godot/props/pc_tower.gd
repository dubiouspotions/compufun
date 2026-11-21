class_name PcTower
extends Node3D
## A PC tower. Without [method dress] it is a plain beige tower.

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
