extends "res://tests/test.gd"
## The corruption signs as the Story Lab shows them: each scene's description, and the Signs section.

const SIGNS := "res://corruption/"
## The signs that the old wiki table had no "In the game" text for.
const UNDESCRIBED: Array[String] = ["blood_puddle"]


func run() -> void:
	_every_described_sign_has_its_description()


func _every_described_sign_has_its_description() -> void:
	var missing := PackedStringArray()
	for file: String in ResourceLoader.list_directory(SIGNS):
		if file.get_extension() != "tscn" or file.get_basename() in UNDESCRIBED:
			continue
		var sign_node := (load(SIGNS + file) as PackedScene).instantiate()
		var description: Variant = sign_node.get(&"description")  # by name: CorruptionSign names Game
		if description == null or (description as String).strip_edges() == "":
			missing.append(file)
		sign_node.free()
	check("every sign scene but the undescribed ones says how it looks", missing, PackedStringArray())
