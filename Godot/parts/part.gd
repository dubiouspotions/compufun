@tool
class_name Part
extends Resource
## One kind of computer part, such as the CPU. Every computer has a place for each part in
## [constant IDS], as the wiki page Hardware Repair shows; most places take a piece of their own part,
## but the two RAM slots both take RAM. A part that no place takes, such as the computer mouse, has
## no place in a computer. The file is parts/<id>.tres.

## The id of every place in a computer, in the order that they go in.
const IDS: Array[StringName] = [&"motherboard", &"cpu", &"fan", &"ram_1", &"ram_2", &"gpu", &"hard_drive"]

## The name that the player reads.
@export var display_name: String = ""
## The part that this one sits on; it must be in first, and this one must be out before it comes out.
## null: the part sits in the case itself.
@export var sits_on: Part
## The 3D model: in the computer, on the mat and on its storage box. Flat side down, origin at the
## bottom centre. An optional child named Broken, hidden in the scene, is how a broken piece looks,
## such as the fan's dust; [method Piece.make_model] shows it.
@export var model: PackedScene
## For a place: the part whose pieces go in it, when that is another part, as a RAM slot takes RAM.
## null: this part's own pieces.
@export var takes: Part
## For a stand-in (Problem.stand_ins), a part that no place takes but that sits in a computer instead
## of another part and works like it, as Skater Bro's heart does for the motherboard: that part. Its
## pieces go in the places that take that part. null for a real part.
@export var poses_as: Part
## Plays instead of the shop's usual sound as a piece of this part comes into or leaves the hand, such
## as a squelch; null for the usual sound.
@export var handle_sound: SoundSet
## Plays from the trash can as the player's click throws a piece of this part in, as the boot
## floppy's low error chord; null for none.
@export var trash_sound: SoundSet
## A loop that plays from a computer instead of its fans' hum while it runs with a piece of this part
## in it, as a wheezing lung. It must loop. null for the usual fans.
@export var running_sound: AudioStream
## A loop that plays from a computer while a piece of this part is in it, such as a heartbeat. It
## must loop (edit/loop_mode in its .import). null for none.
@export var sound: AudioStream


## A new instance of [member model], dressed as this part shows it, such as a FloppyDisk's label;
## null when the part has no model.
func instantiate_model() -> Node3D:
	return model.instantiate() as Node3D if model != null else null


## The part's id, from its file name, such as &"cpu".
func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())


## The part whose pieces go in this place (see [member takes]).
func piece_part() -> Part:
	return takes if takes != null else self


## True when a piece of this part goes in the place [param place]: the place takes this part, or this
## part poses as the part that the place takes (see [member poses_as]).
func fits(place: Part) -> bool:
	return place.piece_part() == self or (poses_as != null and place.piece_part() == poses_as)


## True when a computer has a place that takes this part.
func fits_computer() -> bool:
	return Part.every().any(func(place: Part) -> bool: return place.piece_part() == self)


## The part with the id [param part_id] (parts/<id>.tres), or null when there is no such Part file.
static func named(part_id: StringName) -> Part:
	var path := "res://parts/%s.tres" % part_id
	return load(path) as Part if ResourceLoader.exists(path) else null


## The box around the shown meshes of [param model], an instance of a part's [member model], in the
## model's own space.
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var to_model := mesh.transform
		var shown := mesh.visible
		var above := mesh.get_parent() as Node3D
		while above != null and above != root:
			to_model = above.transform * to_model
			shown = shown and above.visible
			above = above.get_parent() as Node3D
		if not shown:
			continue
		var mesh_box: AABB = to_model * mesh.get_aabb()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	return box


## Every place in a computer, in the order that they go in. A file that is missing fails loudly.
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
