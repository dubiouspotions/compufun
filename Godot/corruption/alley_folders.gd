extends CorruptionSign
## Some of the houses along the alley become giant Win95 folders.

## The names of the buildings in the group alley_buildings that become folders.
@export var buildings: Array[StringName] = [&"Back0", &"Back1", &"Back3"]
## The folder that stands in for a building: 1 m wide, high and deep, with its origin at the bottom
## centre of its front.
@export var folder_scene: PackedScene
## The size of a folder, in metres, but never wider or higher than its building. Low enough that
## the shop's windows show the tab.
@export var size: Vector3 = Vector3(6.0, 4.6, 1.0)

## Each building that becomes a folder, with its folder.
var _folders: Dictionary[GeometryInstance3D, Node3D] = {}
## Each building, with its visibility before the sign.
var _was_visible: Dictionary[GeometryInstance3D, bool] = {}


func _ready() -> void:
	var missing: Array[StringName] = buildings.duplicate()
	for node: Node in get_tree().get_nodes_in_group(&"alley_buildings"):
		if not StringName(node.name) in buildings:
			continue
		missing.erase(StringName(node.name))
		var building := node as GeometryInstance3D
		var folder: Node3D = _make_folder(building) if building != null else null
		if folder == null:
			push_error("alley_folders: no folder for %s: it must be a GeometryInstance3D, and folder_scene a Node3D scene" % node.get_path())
			continue
		_folders[building] = folder
		_was_visible[building] = building.visible
	if not missing.is_empty():
		push_error("alley_folders: no building named %s in the group alley_buildings" % [missing])
	super()


func _apply(shown_stage: int) -> void:
	for building: GeometryInstance3D in _folders:
		building.visible = _was_visible[building] and shown_stage < 1
		_folders[building].visible = shown_stage >= 1


func _make_folder(building: GeometryInstance3D) -> Node3D:
	var instance: Node = folder_scene.instantiate() if folder_scene != null else null
	var folder := instance as Node3D
	if folder == null:
		if instance != null:
			instance.free()
		return null
	add_child(folder)
	# The building's render layers, so the outside's lights (the skylight) light the folder too.
	for part: Node in folder.find_children("*", "GeometryInstance3D", true, false):
		(part as GeometryInstance3D).layers = building.layers
	var box := building.get_aabb()
	var fit_size := Vector3(minf(size.x, box.size.x), minf(size.y, box.size.y), size.z)
	var fit := Transform3D(Basis.from_scale(fit_size), Vector3(box.get_center().x, box.position.y, box.end.z))
	folder.global_transform = building.global_transform * fit
	return folder
