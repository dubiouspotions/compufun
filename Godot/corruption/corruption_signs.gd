class_name CorruptionSigns
extends Node
## Loads every corruption sign, corruption/<id>.tscn, as a child, so adding a sign is adding a file
## (wiki: Architecture, "Corruption signs").

const FOLDER: String = "res://corruption/"


func _ready() -> void:
	for file: String in ResourceLoader.list_directory(FOLDER):
		if file.get_extension() != "tscn":
			continue
		var scene := load(FOLDER + file) as PackedScene
		var sign_node := scene.instantiate() if scene != null else null
		if not sign_node is CorruptionSign:
			push_error("CorruptionSigns: %s%s is not a CorruptionSign scene" % [FOLDER, file])
			if sign_node != null:
				sign_node.free()
			continue
		add_child(sign_node)


## Every sign in the shop, in the order of their files.
func every() -> Array[CorruptionSign]:
	var signs: Array[CorruptionSign] = []
	for child: Node in get_children():
		signs.append(child as CorruptionSign)
	return signs
