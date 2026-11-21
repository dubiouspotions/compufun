@tool
class_name Part
extends Resource
## One kind of computer part, such as the CPU. Every computer has one of each, in the places that
## the wiki page Hardware Repair shows. The file is parts/<id>.tres.

## The id of every part, in the order that they go into a computer.
const IDS: Array[StringName] = [&"motherboard", &"cpu", &"fan", &"gpu", &"hard_drive"]

## The name that the player reads.
@export var display_name: String = ""
## The part that this one sits on; it must be in first, and this one must be out before it comes out.
## null: the part sits in the case itself.
@export var sits_on: Part
## Where the part's screws sit, on its model, in metres. Each must come out before the part does,
## and go back in for the repair to count. Empty: the part clips in.
@export var screw_points: PackedVector3Array = []
## The 3D model: in the computer, on the mat and on its storage box. Flat side down, origin at the
## bottom centre.
@export var model: PackedScene


## The part's id, from its file name, such as &"cpu".
func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())


## Every part, in the order that they go into a computer. A file that is missing fails loudly.
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
