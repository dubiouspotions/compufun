class_name PcTower
extends Node3D
## A PC tower. Without [method dress] it is a plain beige tower.

@onready var _case: MeshInstance3D = $Case
@onready var _sticker: Poster = $Sticker
@onready var _plain_case: Material = _case.material_override


## Shows the case material and the sticker of [param computer]; null shows the plain tower.
func dress(computer: Computer) -> void:
	var case_material: Material = computer.case_material if computer != null else null
	_case.material_override = case_material if case_material != null else _plain_case
	var sticker: Texture2D = computer.sticker if computer != null else null
	_sticker.visible = sticker != null
	_sticker.texture = sticker
