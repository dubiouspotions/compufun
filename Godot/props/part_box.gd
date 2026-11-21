@tool
class_name PartBox
extends Node3D
## A plastic sorting tray of new parts on a storage desk, with the part's name on a label at the
## front: a click takes one into the hand, and a click with an unused one in the hand puts it back.
## The supply never runs out (wiki: Hardware Repair).

## The part in this tray.
@export var part: Part:
	set(value):
		part = value
		if is_node_ready():
			_show()
## How many pieces lie in the tray: side by side where they fit, then in layers.
@export_range(1, 12) var shown_count: int = 4:
	set(value):
		shown_count = value
		if is_node_ready():
			_show()
## The floor inside the tray, in metres: width (x) and depth (z). A larger piece is scaled down to fit.
@export var inside: Vector2 = Vector2(0.24, 0.22)
## How far each piece is turned off straight, at most, in degrees, so that the pile looks untidy.
@export var jumble_degrees: float = 6.0
## The size of one font pixel of the name on the label, in metres; a long name gets smaller to fit.
@export var label_pixel_size: float = 0.0012

@onready var _hotspot: Hotspot = %Hotspot
@onready var _name: Label3D = %Name
@onready var _label: MeshInstance3D = %Label
@onready var _pieces: Node3D = %Pieces


func _ready() -> void:
	_show()


func _show() -> void:
	_hotspot.part = part
	_name.text = part.display_name if part != null else ""
	var font := _name.font if _name.font != null else ThemeDB.fallback_font
	var text_width := font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name.font_size).x
	_name.pixel_size = minf(label_pixel_size, (_label.mesh as BoxMesh).size.x * 0.92 / maxf(text_width, 1.0))
	for child: Node in _pieces.get_children():
		child.queue_free()
	if part == null:
		return
	if part.model == null:
		push_error("PartBox %s: %s has no model" % [get_path(), part.resource_path])
		return
	var probe := part.model.instantiate() as Node3D
	var box := Part.bounds(probe)
	probe.free()
	var fit := minf(1.0, minf(inside.x / maxf(box.size.x, 0.001), inside.y / maxf(box.size.z, 0.001)))
	var size := box.size * fit
	var columns := maxi(1, floori(inside.x / size.x))
	var rows := maxi(1, floori(inside.y / size.z))
	var per_layer := mini(columns * rows, shown_count)
	columns = mini(columns, ceili(sqrt(per_layer)))  # as square as the tray allows
	rows = ceili(float(per_layer) / columns)
	var random := RandomNumberGenerator.new()
	random.seed = hash(part.resource_path)  # the same untidy pile on every run
	for i: int in shown_count:
		var at := i % per_layer
		var cell := Vector2(at % columns + 0.5 - columns * 0.5, floorf(float(at) / columns) + 0.5 - rows * 0.5)
		var model := part.model.instantiate() as Node3D
		model.scale = Vector3.ONE * fit
		model.rotation.y = deg_to_rad(random.randf_range(-jumble_degrees, jumble_degrees))
		model.position = Vector3(cell.x * size.x, floorf(float(i) / per_layer) * size.y, cell.y * size.z)
		model.position -= model.basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
		_pieces.add_child(model)
