class_name Computer
extends Resource
## The computer that a customer brings to the counter.

const _CLASSIC_FRONT: PackedScene = preload("res://props/case_fronts/classic.tscn")

## What Win95 looks like and holds when this computer boots.
@export var win95_setup: Win95Setup
## True when the computer runs Win95 Cambion, the possessed build (wiki: Storyline). Some corruption
## signs show only in such a computer.
@export var cambion: bool = false
## What its BIOS finds as it boots; null is the defaults of Hardware, a Pentium 100 from 1995.
@export var hardware: Hardware
## The material of the case; null is beige plastic.
@export var case_material: Material
## The front of the case: its drive bays, floppy drives and badges, a scene from props/case_fronts/.
## Null is the classic front.
@export var case_front: PackedScene
## The stickers on the case, each with its face and place; empty is none. Where two overlap, the later
## one is on top.
@export var stickers: Array[Sticker] = []


## Puts the case front of [param computer] on [param mount], in place of the front that is there.
## Null [param computer], or one without a [member case_front], gets the classic front. [param mount]
## sits at the centre of the front face, its +Z out of the case and its +Y up the face (0.19 m wide,
## 0.42 m tall). A front keeps clear of the power button and the power light, on the vertical
## centre line below the middle, and of the post-it at the bottom right.
static func mount_front(computer: Computer, mount: Node3D) -> void:
	var scene: PackedScene = computer.case_front if computer != null and computer.case_front != null else _CLASSIC_FRONT
	var front := scene.instantiate() as Node3D
	if front == null:
		push_error("Computer.mount_front: the case front %s has no Node3D root" % scene.resource_path)
		return
	for old: Node in mount.get_children():
		mount.remove_child(old)
		old.queue_free()
	mount.add_child(front)
