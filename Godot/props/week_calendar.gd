class_name WeekCalendar
extends Node3D
## The week calendar on the wall: one cell per day of the game with its weekday initial and date,
## weekend days in red, and a check mark on each day that has passed. The paper faces +Z; its
## origin is the centre.

## The game's days, one per Day file (days/day_1.tres to day_7.tres).
const DAYS: int = 7
const WEEKDAYS: PackedStringArray = ["S", "M", "T", "W", "T", "F", "S"]

## The colour of the grid and of the weekday dates.
@export var ink_color: Color = Color(0.12, 0.1, 0.16)
## The colour of Saturday and Sunday.
@export var weekend_color: Color = Color(0.8, 0.1, 0.08)
## The colour of the check marks on the days that have passed.
@export var check_color: Color = Color(0.1, 0.45, 0.15)
## The height of the weekday row, as a fraction of the paper's height.
@export_range(0.1, 0.5) var weekday_row: float = 0.3

var _checks: Array[Node3D] = []

@onready var _paper: MeshInstance3D = $Paper


func _ready() -> void:
	var size := (_paper.mesh as QuadMesh).size
	var cell := size.x / DAYS
	var row := size.y * weekday_row
	var stroke := size.y * 0.035
	var ink := _ink(ink_color)
	var check := _ink(check_color)
	_quad(self, ink, Vector2(size.x, stroke), Vector2(0.0, size.y * 0.5 - row))
	for number in range(1, DAYS + 1):
		var date: Dictionary = Game.date_of(number)
		var weekday: int = date.weekday
		var color := weekend_color if weekday == 0 or weekday == 6 else ink_color
		var x := -size.x * 0.5 + cell * (number - 0.5)
		if number > 1:
			_quad(self, ink, Vector2(stroke, size.y), Vector2(x - cell * 0.5, 0.0))
		_label(WEEKDAYS[weekday], row * 0.75, color, Vector3(x, size.y * 0.5 - row * 0.5, 0.003))
		_label(str(date.day), (size.y - row) * 0.42, color, Vector3(x, -row * 0.5, 0.003))
		_checks.append(_check_mark(check, cell * 0.9, stroke * 2.2, Vector3(x, -row * 0.5, 0.005)))
	Game.changed.connect(_sync)
	_sync()


# A day has passed once the next one starts, or once the shop closes for its night.
func _sync() -> void:
	var today := Game.day_number
	for i in _checks.size():
		var number := i + 1
		_checks[i].visible = number < today or (number == today and Game.phase == Game.Phase.DAY_OVER)


func _ink(color: Color) -> ShaderMaterial:
	var material := _paper.material_override.duplicate() as ShaderMaterial
	material.set_shader_parameter(&"albedo_color", color)
	return material


func _label(text: String, cap_height: float, color: Color, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = cap_height / (label.font_size * 0.72) # 0.72: cap height per em of the default font
	label.outline_size = 3 # thickens the strokes so the glyphs survive the low-resolution buffer
	label.outline_modulate = color
	label.modulate = color
	label.shaded = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = at
	add_child(label)
	return label


## A check mark [param width] wide drawn with two strokes, centred on [param at].
func _check_mark(material: Material, width: float, thickness: float, at: Vector3) -> Node3D:
	var mark := Node3D.new()
	mark.position = at
	add_child(mark)
	var corner := Vector2(-0.1, -0.5) * width
	_stroke(mark, material, Vector2(-0.45, 0.0) * width, corner, thickness)
	_stroke(mark, material, corner, Vector2(0.45, 0.7) * width, thickness)
	return mark


func _stroke(parent: Node3D, material: Material, from: Vector2, to: Vector2, thickness: float) -> void:
	var quad := _quad(parent, material, Vector2(from.distance_to(to) + thickness, thickness), (from + to) * 0.5)
	quad.rotation.z = (to - from).angle()


func _quad(parent: Node3D, material: Material, size: Vector2, at: Vector2) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var quad := MeshInstance3D.new()
	quad.mesh = mesh
	quad.material_override = material
	quad.position = Vector3(at.x, at.y, 0.0015)
	parent.add_child(quad)
	return quad
