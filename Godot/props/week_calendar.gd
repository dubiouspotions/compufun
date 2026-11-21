class_name WeekCalendar
extends Node3D
## The week calendar on the wall: a paper wall calendar with the month and year on top, and below
## it one column per day of the game with its weekday initial and date, weekend days in red. Each
## day that has passed is crossed out. The paper faces +Z; its origin is the centre.

## The game's days, one per Day file (days/day_1.tres to day_7.tres).
const DAYS: int = 7
const WEEKDAYS: PackedStringArray = ["S", "M", "T", "W", "T", "F", "S"]
const MONTHS: PackedStringArray = [
	"JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
	"JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER",
]

## The colour of the binding, the grid, the heading and the weekday dates.
@export var ink_color: Color = Color(0.12, 0.1, 0.16)
## The colour of Saturday and Sunday.
@export var weekend_color: Color = Color(0.8, 0.1, 0.08)
## The colour of the pen that crosses out the days that have passed.
@export var cross_color: Color = Color(0.1, 0.18, 0.55)
## The colour of the ruled lines for notes under each date.
@export var rule_color: Color = Color(0.72, 0.74, 0.8)
## The height of the month and year heading, as a fraction of the paper's height.
@export_range(0.1, 0.5) var heading_height: float = 0.3
## The height of the weekday row, as a fraction of the paper's height.
@export_range(0.05, 0.3) var weekday_row: float = 0.12

var _crosses: Array[Node3D] = []

@onready var _paper: MeshInstance3D = $Paper


func _ready() -> void:
	var size := (_paper.mesh as QuadMesh).size
	var margin := size.x * 0.05
	var stroke := size.y * 0.018
	var cell := (size.x - margin * 2.0) / DAYS
	var top := size.y * 0.5
	var heading := size.y * heading_height
	var row := size.y * weekday_row
	var grid_top := top - heading
	var cells_top := grid_top - row
	var bottom := -top + margin
	var ink := _ink(ink_color)
	var pen := _ink(cross_color)
	var rule := _ink(rule_color)
	_quad(self, ink, Vector2(size.x, size.y * 0.035), Vector2(0.0, top - size.y * 0.0175))

	var first: Dictionary = Game.date_of(1)
	var last: Dictionary = Game.date_of(DAYS)
	var months: String = MONTHS[first.month - 1]
	if last.month != first.month:
		months += "/" + MONTHS[last.month - 1]
	var inner := size.x - margin * 2.0
	_label(months, heading * 0.36, inner, ink_color, Vector3(0.0, top - heading * 0.36, 0.003))
	_label(str(first.year), heading * 0.27, inner, ink_color, Vector3(0.0, top - heading * 0.76, 0.003))

	var rule_y := cells_top - cell
	while rule_y > bottom + cell * 0.25:
		_quad(self, rule, Vector2(inner, stroke), Vector2(0.0, rule_y))
		rule_y -= cell * 0.5
	for y: float in [grid_top, cells_top, bottom]:
		_quad(self, ink, Vector2(inner + stroke, stroke), Vector2(0.0, y))
	for i in range(DAYS + 1):
		_quad(self, ink, Vector2(stroke, grid_top - bottom), Vector2(-inner * 0.5 + cell * i, (grid_top + bottom) * 0.5))
	for number in range(1, DAYS + 1):
		var date: Dictionary = Game.date_of(number)
		var weekday: int = date.weekday
		var color := weekend_color if weekday == 0 or weekday == 6 else ink_color
		var x := -inner * 0.5 + cell * (number - 0.5)
		_label(WEEKDAYS[weekday], row * 0.7, cell * 0.8, color, Vector3(x, grid_top - row * 0.5, 0.003))
		_label(str(date.day), cell * 0.75, cell * 0.86, color, Vector3(x, cells_top - cell * 0.5, 0.003))
		var corner := Vector2.ONE * (cell * 0.5 - stroke * 1.5)
		_crosses.append(_cross(pen, corner, stroke * 1.1, Vector3(x, cells_top - cell * 0.5, 0.005)))
	Game.changed.connect(_sync)
	_sync()


# A day has passed once the next one starts, or once the shop closes for its night.
func _sync() -> void:
	var today := Game.day_number
	for i in _crosses.size():
		var number := i + 1
		_crosses[i].visible = number < today or (number == today and Game.phase == Game.Phase.DAY_OVER)


func _ink(color: Color) -> ShaderMaterial:
	var material := _paper.material_override.duplicate() as ShaderMaterial
	material.set_shader_parameter(&"albedo_color", color)
	return material


## A label with capitals [param cap_height] high, shrunk to fit [param max_width], centred on [param at].
func _label(text: String, cap_height: float, max_width: float, color: Color, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.outline_size = 3 # thickens the strokes so the glyphs survive the low-resolution buffer
	var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x + label.outline_size * 2
	label.pixel_size = minf(cap_height / (label.font_size * 0.72), max_width / width) # 0.72: cap height per em of the default font
	label.outline_modulate = color
	label.modulate = color
	label.shaded = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = at
	add_child(label)
	return label


## A pen cross from corner to corner of a box [param half_size] from its centre [param at].
func _cross(material: Material, half_size: Vector2, thickness: float, at: Vector3) -> Node3D:
	var mark := Node3D.new()
	mark.position = at
	add_child(mark)
	_stroke(mark, material, -half_size, half_size, thickness)
	_stroke(mark, material, Vector2(-half_size.x, half_size.y), Vector2(half_size.x, -half_size.y), thickness)
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
