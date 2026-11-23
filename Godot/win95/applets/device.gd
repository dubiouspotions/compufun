class_name Device
extends Resource
## One line of Device Manager (System > Device Manager): a type of device, such as Disk drives, or a
## device under it.

## The name that the line shows.
@export var name: String = ""
@export var icon: Texture2D
## The id of the place in the computer that the device stands for (see Part.IDS), such as
## &"hard_drive"; while a stand-in (Part.poses_as) is in that place, the line shows the stand-in's
## name instead, with a problem mark. Empty for a device that is not a part.
@export var place: StringName = &""
## Marked with a yellow exclamation mark, as Win95 marks a device with a problem.
@export var problem: bool = false
## The devices under this one; a type of device starts collapsed unless one of them has a problem.
@export var devices: Array[Device] = []
