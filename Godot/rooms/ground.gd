class_name Ground
extends MeshInstance3D
## A floor that customers walk on, such as the shop floor or the alley. A customer's footsteps
## sound of the ground under them. Put this script on the floor's mesh: its bounds are the area.

const GROUP: StringName = &"ground"

## The footsteps on this ground; each step plays one take.
@export var steps: SoundSet


func _enter_tree() -> void:
	add_to_group(GROUP)


## The ground in [param tree] whose area covers [param point] across the floor plan (X and Z), or
## null where there is none. Where grounds overlap, such as a porch on the alley, the one with the
## highest top wins.
static func under(point: Vector3, tree: SceneTree) -> Ground:
	var found: Ground = null
	var found_top := -INF
	for node: Node in tree.get_nodes_in_group(GROUP):
		var ground := node as Ground
		var area := ground.global_transform * ground.get_aabb()
		var top := area.end.y
		if point.x >= area.position.x and point.x <= area.end.x and point.z >= area.position.z \
				and point.z <= area.end.z and top > found_top:
			found = ground
			found_top = top
	return found
