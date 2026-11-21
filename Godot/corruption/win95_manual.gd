extends CorruptionSign
## A computer manual lies on the work desk, at the marker in the group book_spot. Its cover becomes
## the Windows 95 manual.

## The cover of each stage: 0 the ordinary manual, 1 the Windows 95 manual.
@export var covers: Array[Material] = []
## The covers' edges and the spine of each stage.
@export var bindings: Array[Material] = []

@onready var _book: Node3D = $Book
@onready var _cover: GeometryInstance3D = $Book/Cover
@onready var _binding: Array[GeometryInstance3D] = [
	$Book/Back as GeometryInstance3D, $Book/Spine as GeometryInstance3D, $Book/Front as GeometryInstance3D]


func _ready() -> void:
	var spot := get_tree().get_first_node_in_group(&"book_spot") as Node3D
	if spot == null:
		push_error("win95_manual: no Node3D in the group book_spot, so the book is not on the desk")
	else:
		_book.global_transform = spot.global_transform * _book.transform
	super()


func _apply(shown_stage: int) -> void:
	var look := mini(shown_stage, 1)
	if look >= covers.size() or look >= bindings.size():
		push_error("win95_manual: %s has no cover or binding for stage %d" % [scene_file_path, look])
		return
	_cover.material_override = covers[look]
	for part: GeometryInstance3D in _binding:
		part.material_override = bindings[look]
