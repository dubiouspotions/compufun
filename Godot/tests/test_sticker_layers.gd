extends "res://tests/test.gd"
## Stickers on one face stack in order, the later on top; each face starts at its own surface.


func run() -> void:
	var front := Node3D.new()
	var left := Node3D.new()
	root.add_child(front)
	root.add_child(left)
	var faces: Dictionary[Sticker.Face, Node3D] = {Sticker.Face.FRONT: front, Sticker.Face.LEFT: left}
	var stickers: Array[Sticker] = []
	for face: Sticker.Face in [Sticker.Face.FRONT, Sticker.Face.LEFT, Sticker.Face.FRONT, Sticker.Face.RIGHT]:
		var sticker := Sticker.new()
		sticker.face = face
		stickers.append(sticker)

	Sticker.stick(stickers, faces)
	check("two on the front, one on the left, none on the hidden right", [front.get_child_count(), left.get_child_count()], [2, 1])
	var under := (front.get_child(0) as Node3D).position.z
	var over := (front.get_child(1) as Node3D).position.z
	check("the first on the front lies on the face", under, 0.0)
	check("the later on the front lies above the first", over > under, true)
	check("the first on the left lies on its face", (left.get_child(0) as Node3D).position.z, 0.0)

	Sticker.stick(stickers, faces)
	check("sticking again replaces the stickers and their layers", [front.get_child_count(), (front.get_child(0) as Node3D).position.z], [2, 0.0])
