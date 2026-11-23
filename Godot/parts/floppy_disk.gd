@tool
class_name FloppyDisk
extends Part
## A 3.5" floppy disk: a part that no place takes. It goes into a computer's drive A:
## (Game.insert_floppy) and comes out of it into the hand (Game.eject_floppy). Its model is
## props/floppy_disk.tscn, which prints [member label] on it.

## The picture printed over the disk's paper label, 136 x 48 pixels or the same shape. null shows
## the plain label with the Windows logo.
@export var label: Texture2D
## The files on the disk, as drive A: lists them. Game.insert_floppy copies them into the computer's
## running copy, so what the computer does to them never touches this resource.
@export var files: Array[Win95File] = []


func instantiate_model() -> Node3D:
	var made := super()
	var disk := made as FloppyDiskModel
	if disk != null:
		disk.label = label
	elif made != null and label != null:
		push_error("FloppyDisk %s: its model is not a FloppyDiskModel, so it can't show its label" % resource_path)
	return made
