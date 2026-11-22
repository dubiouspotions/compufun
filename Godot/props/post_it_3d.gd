class_name PostIt3D
extends Node3D
## The post-it stuck on a computer on the counter: the job's perceived issue; an orange exclamation
## mark and "Needs testing" while it is fixed but not tested; then a green check and the prompt to
## call the customer.

## False hides the 3D text, for a post-it that PostItLabel writes on in sharp UI text.
@export var text_3d: bool = true:
	set(value):
		text_3d = value
		if is_node_ready():
			_sync()

## The job whose post-it this is, or null for a blank post-it.
var job: Job:
	set(value):
		job = value
		if is_node_ready():
			_sync()

## The font of the text, or null for the default font. Every node in the group shop_text has one.
var font: Font:
	set(value):
		font = value
		if is_node_ready():
			_sync()

@onready var _issue: Label3D = %Issue
@onready var _done: Node3D = %Done
@onready var _pickup: Label3D = %Pickup
@onready var _testing: Node3D = %Testing
@onready var _testing_text: Label3D = %TestingText
@onready var _paper: MeshInstance3D = %Paper


# In the group before it enters the tree, so SceneTree.node_added sees it there.
func _init() -> void:
	add_to_group(&"shop_text")


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	_issue.text = job.perceived_issue() if job != null else ""
	_done.visible = job != null and job.done
	_issue.visible = text_3d
	_pickup.visible = text_3d
	_testing.visible = job != null and job.fixed and not job.tested
	_testing_text.visible = text_3d
	for label: Label3D in [_issue, _pickup, _testing_text]:
		label.font = font


## The four corners of the paper, in world space: top left, top right, bottom right and bottom left,
## as its text reads.
func paper_corners() -> Array[Vector3]:
	var half := (_paper.mesh as QuadMesh).size * 0.5
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		corners.append(_paper.global_transform * Vector3(corner.x * half.x, corner.y * half.y, 0.0))
	return corners
