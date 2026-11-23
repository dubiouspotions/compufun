extends PropertyPage
## System > Device Manager: the computer's devices by type. A device that stands for a part shows
## the stand-in in that place instead, such as Skater Bro's heart (see [member Device.place]).

## The computer at the top of the tree; its types of device under it.
@export var computer_name: String = "Computer"
@export var computer_icon: Texture2D
@export var devices: Array[Device] = []

@onready var _tree: FolderTree = %DeviceTree


func load_from(computer: ComputerState) -> void:
	var job := computer.job
	var items: Array[FolderTree.Item] = [FolderTree.Item.new(computer_name, computer_icon, 0)]
	for type: Device in devices:
		var under: Array[FolderTree.Item] = []
		for device: Device in type.devices:
			under.append(_item(device, job, 2))
		var heading := _item(type, job, 1)
		heading.expanded = under.any(func(each: FolderTree.Item) -> bool: return each.warning)
		items.append(heading)
		items.append_array(under)
	_tree.set_items(items)
	_tree.selected = 0


func _item(device: Device, job: Job, depth: int) -> FolderTree.Item:
	var item := FolderTree.Item.new(device.name, device.icon, depth)
	item.warning = device.problem
	if device.place != &"" and job != null:
		var place := Part.named(device.place)
		if place == null:
			push_error("System > Device Manager: %s names no place %s" % [device.name, device.place])
		var piece := job.piece(place) if place != null else null
		if piece != null and piece.part.poses_as != null:
			item.text = piece.part.display_name
			item.warning = true
	return item
