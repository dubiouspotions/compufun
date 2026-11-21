@tool
class_name Part
extends Resource
## One kind of computer part, such as the CPU. Every computer has one of each part in [constant IDS],
## in the places that the wiki page Hardware Repair shows. A part file not in [constant IDS], such as
## the computer mouse, has no place in a computer. The file is parts/<id>.tres.

## The id of every part that a computer has a place for, in the order that they go in.
const IDS: Array[StringName] = [&"motherboard", &"cpu", &"fan", &"gpu", &"hard_drive"]

## The name that the player reads.
@export var display_name: String = ""
## The part that this one sits on; it must be in first, and this one must be out before it comes out.
## null: the part sits in the case itself.
@export var sits_on: Part
## The 3D model: in the computer, on the mat and on its storage box. Flat side down, origin at the
## bottom centre.
@export var model: PackedScene


## The part's id, from its file name, such as &"cpu".
func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())


## True when a computer has a place for this part (its id is in [constant IDS]).
func fits_computer() -> bool:
	return id() in IDS


## The part with the id [param part_id] (parts/<id>.tres), or null when there is no such Part file.
static func named(part_id: StringName) -> Part:
	var path := "res://parts/%s.tres" % part_id
	return load(path) as Part if ResourceLoader.exists(path) else null


## The box around the meshes of [param model], an instance of a part's [member model], in the
## model's own space.
static func bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var to_model := mesh.transform
		var above := mesh.get_parent() as Node3D
		while above != null and above != model:
			to_model = above.transform * to_model
			above = above.get_parent() as Node3D
		var mesh_box: AABB = to_model * mesh.get_aabb()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	return box


## Every part that a computer has a place for, in the order that they go in. A file that is missing fails loudly.
static func every() -> Array[Part]:
	var parts: Array[Part] = []
	for part_id: StringName in IDS:
		var path := "res://parts/%s.tres" % part_id
		var part := load(path) as Part
		if part == null:
			push_error("Part.every: %s is missing or not a Part" % path)
			continue
		parts.append(part)
	return parts
